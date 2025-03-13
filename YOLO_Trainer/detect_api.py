from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.middleware.gzip import GZipMiddleware
import logging
import ollama
import json
from pydantic import BaseModel
from functools import lru_cache
import os
from dotenv import load_dotenv
import time

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Environment configuration
ENV = os.getenv('ENV', 'local')  # Default to local if not set
OLLAMA_HOST = os.getenv('OLLAMA_HOST', 'http://localhost:11434')
API_TIMEOUT = int(os.getenv('API_TIMEOUT', '30'))
ENABLE_CACHE = os.getenv('ENABLE_CACHE', 'true').lower() == 'true'

app = FastAPI(
    title="Receipt Scanner API",
    description="API for analyzing receipt text using Ollama",
    version="1.0.0"
)

# Add GZip compression
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Configure CORS based on environment
if ENV == 'production':
    # Production CORS settings (more restrictive)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["https://your-production-domain.com"],  # Replace with your domain
        allow_credentials=True,
        allow_methods=["GET", "POST"],
        allow_headers=["Content-Type", "Authorization"],
    )
else:
    # Local development CORS settings (more permissive)
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

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Test Ollama connection with timeout
        response = ollama.chat(
            model='mistral',
            messages=[{'role': 'user', 'content': 'test'}],
            options={
                'num_thread': 1,
                'timeout': 5  # 5 second timeout
            }
        )
        return {
            "status": "healthy",
            "ollama": "connected",
            "environment": ENV,
            "ollama_host": OLLAMA_HOST,
            "timestamp": time.time()
        }
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        raise HTTPException(
            status_code=503,
            detail=f"Service unhealthy: {str(e)}"
        )

# Cache the model responses for similar receipts (only if enabled)
if ENABLE_CACHE:
    @lru_cache(maxsize=100)
    def analyze_receipt_text(text: str):
        return _analyze_receipt_text_internal(text)
else:
    def analyze_receipt_text(text: str):
        return _analyze_receipt_text_internal(text)

def _analyze_receipt_text_internal(text: str):
    try:
        # Configure options based on environment
        options = {
            'num_gpu': 0 if ENV == 'production' else 1,  # Disable GPU in production
            'num_thread': 4 if ENV == 'production' else 8,  # Reduce threads in production
            'temperature': 0.1,
            'top_p': 0.9,
            'repeat_penalty': 1.1,
            'timeout': API_TIMEOUT
        }
        
        # Add timeout to the request
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
            return JSONResponse(
                status_code=422,
                content={
                    "success": False,
                    "error": "No text provided to analyze"
                }
            )
            
        # Check if Ollama is available
        try:
            response = analyze_receipt_text(receipt_text)
            logger.debug(f"Ollama response: {response}")
            
            # Validate the response contains content
            if not response or 'message' not in response or 'content' not in response['message']:
                raise ValueError("Invalid response format from Ollama")
                
            content = response['message']['content'].strip()
            # Remove any non-JSON text before or after the JSON object
            content = content[content.find('{'):content.rfind('}')+1]
            
            # Try to parse the response as JSON
            try:
                result = json.loads(content)
                
                # Clean up the items list to ensure valid prices and quantities
                cleaned_items = []
                for item in result.get('items', []):
                    try:
                        # Validate all required fields are present and valid
                        if all(key in item for key in ['name', 'quantity', 'unit_price', 'total_price']):
                            quantity = int(item['quantity'])
                            unit_price = float(item['unit_price'])
                            total_price = float(item['total_price'])
                            
                            # Verify the total price matches quantity * unit_price
                            calculated_total = round(quantity * unit_price, 2)
                            if abs(calculated_total - total_price) > 0.01:  # Allow small rounding differences
                                total_price = calculated_total
                            
                            cleaned_items.append({
                                'name': item['name'],
                                'quantity': quantity,
                                'unit_price': round(unit_price, 2),
                                'total_price': round(total_price, 2)
                            })
                    except (ValueError, TypeError):
                        continue  # Skip items with invalid numbers
                
                # Update the items list with only valid items
                result['items'] = cleaned_items
                
                # Ensure total_amount is a valid number
                try:
                    result['total_amount'] = float(result.get('total_amount', 0.0))
                except (TypeError, ValueError):
                    # If total_amount is invalid, calculate it from items
                    result['total_amount'] = round(sum(item['total_price'] for item in cleaned_items), 2)
                
                # Ensure other required fields have valid values
                result['merchant_name'] = result.get('merchant_name', 'Unknown Merchant')
                result['date'] = result.get('date') or '2024-03-09'  # Default to today if missing
                
                return JSONResponse(content={"success": True, "data": result})
            except json.JSONDecodeError as e:
                logger.error(f"JSON decode error: {str(e)}")
                logger.error(f"Raw content: {content}")
                return JSONResponse(
                    status_code=422,
                    content={
                        "success": False,
                        "error": "Failed to parse receipt data",
                        "raw_text": receipt_text,
                        "model_response": content
                    }
                )
                
        except Exception as e:
            logger.error(f"Ollama error: {str(e)}")
            return JSONResponse(
                status_code=500,
                content={
                    "success": False,
                    "error": f"Error communicating with Ollama: {str(e)}"
                }
            )
            
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "error": f"Server error: {str(e)}"
            }
        )