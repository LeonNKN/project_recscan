from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.middleware.gzip import GZipMiddleware
import logging
import httpx
import ollama
import json
from pydantic import BaseModel
from functools import lru_cache
import os
from dotenv import load_dotenv
import time

# Load environment variables
load_dotenv()

# Configure logging with more detailed format
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s'
)
logger = logging.getLogger(__name__)

# Add httpx logger for detailed HTTP logging
httpx_logger = logging.getLogger("httpx")
httpx_logger.setLevel(logging.DEBUG)

def log_request_details(request):
    """Helper function to log request details"""
    logger.debug(f"Request URL: {request.url}")
    logger.debug(f"Request Method: {request.method}")
    logger.debug(f"Request Headers: {dict(request.headers)}")
    return request

def log_response_details(response):
    """Helper function to log response details"""
    try:
        logger.debug(f"Response Status: {response.status_code}")
        logger.debug(f"Response Headers: {dict(response.headers)}")
        if hasattr(response, 'request') and response.request:
            logger.debug(f"Response URL (after redirects): {response.url}")
            logger.debug(f"Request Method: {response.request.method}")
            logger.debug(f"Request Headers: {dict(response.request.headers)}")
        else:
            logger.debug("No request instance available on response")
        if response.status_code >= 400:
            logger.error(f"Error Response Body: {response.text}")
    except Exception as e:
        logger.error(f"Error logging response details: {str(e)}")
    return response

class DebugTransport(httpx.HTTPTransport):
    """Custom transport class for detailed request/response logging"""
    def handle_request(self, request):
        try:
            logger.debug(f"Sending request to: {request.url}")
            log_request_details(request)
            response = super().handle_request(request)
            logger.debug("Received response")
            log_response_details(response)
            return response
        except Exception as e:
            logger.error(f"Error in transport handler: {str(e)}")
            raise

# Environment configuration with detailed logging
logger.info("Loading environment configuration...")
ENV = os.getenv('ENV', 'production')
logger.info(f"Environment: {ENV}")

OLLAMA_BASE_URL = os.getenv('OLLAMA_HOST', 'http://localhost:11434').strip()
logger.info(f"Initial OLLAMA_BASE_URL: {OLLAMA_BASE_URL}")

ENABLE_CACHE = os.getenv('ENABLE_CACHE', 'true').lower() == 'true'
logger.info(f"Cache enabled: {ENABLE_CACHE}")

PORT = int(os.getenv('PORT', '8000'))
API_TIMEOUT = float(os.getenv('API_TIMEOUT', '60.0'))
logger.info(f"Port: {PORT}, API Timeout: {API_TIMEOUT}")

# Keep HTTPS as is (remove forced HTTP conversion)
OLLAMA_BASE_URL = OLLAMA_BASE_URL.rstrip('/')
logger.info(f"Final OLLAMA_BASE_URL: {OLLAMA_BASE_URL}")

# Set logging level from environment
log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
try:
    logging.getLogger().setLevel(log_level)
    logger.info(f"Log level set to: {log_level}")
except ValueError:
    logger.error(f"Invalid log level: {log_level}. Defaulting to INFO.")
    logging.getLogger().setLevel(logging.INFO)

# Configure Ollama client with minimal headers
try:
    logger.info("Configuring Ollama client...")
    transport = DebugTransport(retries=3)
    
    connect_timeout = float(os.getenv('CONNECT_TIMEOUT', '5.0'))
    read_timeout = float(os.getenv('READ_TIMEOUT', '30.0'))
    write_timeout = float(os.getenv('WRITE_TIMEOUT', '30.0'))
    pool_timeout = float(os.getenv('POOL_TIMEOUT', '30.0'))
    logger.info(f"Timeouts - Connect: {connect_timeout}s, Read: {read_timeout}s, Write: {write_timeout}s, Pool: {pool_timeout}s")
    
    client = httpx.Client(
        transport=transport,
        timeout=httpx.Timeout(
            connect=connect_timeout,
            read=read_timeout,
            write=write_timeout,
            pool=pool_timeout
        ),
        verify=True,
        follow_redirects=True,
        headers={
            'ngrok-skip-browser-warning': 'true'  # Only keep this header
        }
    )
    
    logger.info("Client configuration complete")
    logger.debug(f"Client headers: {dict(client.headers)}")
    
    # Test connection
    logger.info("Starting initial connection test...")
    test_url = f"{OLLAMA_BASE_URL}/api/tags"
    logger.info(f"Testing connection to: {test_url}")
    test_response = client.get(test_url)
    logger.info(f"Initial test response status: {test_response.status_code}")
    logger.debug(f"Initial test response headers: {dict(test_response.headers)}")
    if test_response.status_code >= 400:
        logger.error(f"Error response content: {test_response.text}")
    
    ollama.host = OLLAMA_BASE_URL
    ollama._client = client
    logger.info("Ollama client configuration complete")

except Exception as e:
    logger.error(f"Client setup failed with error: {str(e)}", exc_info=True)

app = FastAPI(
    title="Receipt Scanner API",
    description="API for analyzing receipt text using Ollama",
    version="1.0.0",
    root_path=os.getenv('ROOT_PATH', '')
)

# Add GZip compression
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Configure CORS
if ENV == 'production':
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["GET", "POST"],
        allow_headers=["*"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

class ReceiptRequest(BaseModel):
    text: str

@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    return response

@app.get("/check")
async def health_check():
    """Health check endpoint"""
    try:
        ollama_status_check = await ollama_status()
        if ollama_status_check["status"] != "connected":
            raise HTTPException(status_code=503, detail="Ollama service unavailable")
        return {
            "status": "healthy",
            "environment": ENV,
            "timestamp": time.time(),
            "ollama_status": ollama_status_check["status"],
            "ollama_version": ollama_status_check.get("ollama_version", "unknown")
        }
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        raise HTTPException(status_code=503, detail=f"Service unhealthy: {str(e)}")

@app.get("/ollama-status")
async def ollama_status():
    """Check Ollama connection status"""
    logger.info("Starting Ollama status check...")
    
    status_info = {
        "base_url": OLLAMA_BASE_URL,
        "checks": [],
        "final_status": "disconnected",
        "client_config": {
            "timeouts": {
                "connect": float(os.getenv('CONNECT_TIMEOUT', '5.0')),
                "read": float(os.getenv('READ_TIMEOUT', '30.0')),
                "write": float(os.getenv('WRITE_TIMEOUT', '30.0')),
                "pool": float(os.getenv('POOL_TIMEOUT', '30.0'))
            },
            "headers": dict(ollama._client.headers) if ollama._client else {},
            "verify_ssl": True,
            "follow_redirects": True
        }
    }
    
    try:
        if not ollama._client:
            raise RuntimeError("Ollama client not initialized")
            
        logger.info(f"Attempting to connect to Ollama at: {OLLAMA_BASE_URL}")
        
        # Try ollama.list()
        logger.info("Attempting Ollama list check...")
        models = ollama.list()
        logger.info(f"Ollama list response: {models}")
        
        status_info["final_status"] = "connected"
        status_info["models"] = models
        
        return {
            "status": "connected",
            "ollama_version": "available",
            "ollama_host": OLLAMA_BASE_URL,
            "models": models,
            "debug_info": status_info
        }
    except httpx.HTTPStatusError as e:
        error_msg = f"HTTP {e.response.status_code}: {e.response.text}"
        logger.error(f"Ollama connection failed: {error_msg}")
        status_info["checks"].append({
            "type": "ollama_list",
            "status_code": e.response.status_code,
            "error_content": e.response.text
        })
        return {
            "status": "disconnected",
            "error": error_msg,
            "ollama_host": OLLAMA_BASE_URL,
            "debug_info": status_info
        }
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Ollama connection failed: {error_msg}", exc_info=True)
        status_info["checks"].append({
            "type": "ollama_list",
            "error": error_msg
        })
        return {
            "status": "disconnected",
            "error": error_msg,
            "ollama_host": OLLAMA_BASE_URL,
            "debug_info": status_info
        }

# Cache the model responses
if ENABLE_CACHE:
    @lru_cache(maxsize=100)
    def analyze_receipt_text(text: str):
        return _analyze_receipt_text_internal(text)
else:
    def analyze_receipt_text(text: str):
        return _analyze_receipt_text_internal(text)

def _analyze_receipt_text_internal(text: str):
    try:
        options = {
            'num_gpu': 0 if ENV == 'production' else 1,
            'num_thread': 4 if ENV == 'production' else 8,
            'temperature': 0.1,
            'top_p': 0.9,
            'repeat_penalty': 1.1,
            'timeout': API_TIMEOUT
        }
        response = ollama.chat(
            model='mistral',
            messages=[
                {'role': 'system', 'content': '''You are a receipt analyzer that extracts structured data from receipt text. 
                    Always respond with valid JSON only. Focus on actual items purchased, not tax or subtotal entries.
                    All prices must be valid numbers, and quantities must be integers.'''},
                {'role': 'user', 'content': f'''
                    Analyze this receipt text and extract the following information:
                    - merchant_name (from the header/top of receipt)
                    - date (in YYYY-MM-DD format)
                    - items (list of purchased items with name, quantity, unit_price, and total_price)
                    - total_amount (the final total as a number)
                    IMPORTANT:
                    - Each item must have: name, quantity, unit_price, and total_price
                    - Ignore tax, subtotal, and service charge entries
                    - All prices must be numbers (not null or text)
                    - Quantities must be integers
                    - If you're unsure about a price or quantity, skip that item entirely
                    - Round prices to 2 decimal places
                    - total_price for each item should equal quantity * unit_price
                    Format your response as valid JSON like this example:
                    {{
                        "merchant_name": "Restaurant Name",
                        "date": "2024-03-15",
                        "items": [
                            {{
                                "name": "Chicken Rice",
                                "quantity": 2,
                                "unit_price": 8.50,
                                "total_price": 17.00
                            }},
                            {{
                                "name": "Ice Tea",
                                "quantity": 1,
                                "unit_price": 2.50,
                                "total_price": 2.50
                            }}
                        ],
                        "total_amount": 19.50
                    }}
                    Receipt text:
                    {text}
                '''}
            ],
            options=options
        )
        return response
    except Exception as e:
        logger.error(f"Model error: {str(e)}")
        raise

@app.post("/analyze-receipt")
async def analyze_receipt(request: ReceiptRequest):
    try:
        receipt_text = request.text.strip()
        logger.info(f"Received text to analyze: {receipt_text[:100]}...")
        
        if not receipt_text:
            return JSONResponse(status_code=422, content={"success": False, "error": "No text provided to analyze"})
        
        ollama_check = await ollama_status()
        if ollama_check["status"] != "connected":
            return JSONResponse(
                status_code=503,
                content={"success": False, "error": "Ollama service is not available", "details": ollama_check}
            )
        
        response = analyze_receipt_text(receipt_text)
        logger.debug(f"Ollama response: {response}")
        
        if not response or 'message' not in response or 'content' not in response['message']:
            raise ValueError("Invalid response format from Ollama")
        
        content = response['message']['content'].strip()
        content = content[content.find('{'):content.rfind('}')+1]
        
        try:
            result = json.loads(content)
            cleaned_items = []
            for item in result.get('items', []):
                try:
                    if all(key in item for key in ['name', 'quantity', 'unit_price', 'total_price']):
                        quantity = int(item['quantity'])
                        unit_price = float(item['unit_price'])
                        total_price = float(item['total_price'])
                        calculated_total = round(quantity * unit_price, 2)
                        if abs(calculated_total - total_price) > 0.01:
                            total_price = calculated_total
                        cleaned_items.append({
                            'name': item['name'],
                            'quantity': quantity,
                            'unit_price': round(unit_price, 2),
                            'total_price': round(total_price, 2)
                        })
                except (ValueError, TypeError):
                    continue
            
            result['items'] = cleaned_items
            try:
                result['total_amount'] = float(result.get('total_amount', 0.0))
            except (TypeError, ValueError):
                result['total_amount'] = round(sum(item['total_price'] for item in cleaned_items), 2)
            
            result['merchant_name'] = result.get('merchant_name', 'Unknown Merchant')
            result['date'] = result.get('date') or '2025-03-15'
            
            return JSONResponse(content={"success": True, "data": result})
        except json.JSONDecodeError as e:
            logger.error(f"JSON decode error: {str(e)}")
            logger.error(f"Raw content: {content}")
            return JSONResponse(
                status_code=422,
                content={"success": False, "error": "Failed to parse receipt data", "raw_text": receipt_text, "model_response": content}
            )
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return JSONResponse(status_code=500, content={"success": False, "error": f"Server error: {str(e)}"})

@app.get("/")
async def read_root():
    return {"message": "Welcome to the Receipt Scanner API"}

if __name__ == "__main__":
    import uvicorn
    logger.info(f"Starting application with ENV={ENV}, PORT={PORT}")
    logger.info(f"Ollama host configured as: {OLLAMA_BASE_URL}")
    uvicorn.run(app, host="0.0.0.0", port=PORT)