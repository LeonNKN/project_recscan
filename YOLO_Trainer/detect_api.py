from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.middleware.gzip import GZipMiddleware
import logging
import json
from pydantic import BaseModel
import os
import sys
import platform
import psutil
from dotenv import load_dotenv
import time
import torch
import re
from datetime import datetime
import requests  # For API calls
import base64  # For image encoding
import ngrok
import ollama  # For local model integration

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s'
)
logger = logging.getLogger(__name__)

# Environment configuration
logger.info("Loading environment configuration...")
ENV = os.getenv('ENV', 'production')
logger.info(f"Environment: {ENV}")

PORT = int(os.getenv('PORT', '8000'))
API_TIMEOUT = float(os.getenv('API_TIMEOUT', '60.0'))
logger.info(f"Port: {PORT}, API Timeout: {API_TIMEOUT}")

# Ollama configuration for vision model
OLLAMA_MODEL = os.getenv('OLLAMA_MODEL', 'llava')
OLLAMA_AVAILABLE = False
ENABLE_GPU = os.getenv('ENABLE_GPU', 'true').lower() == 'true'

def check_ollama_availability():
    """Check if Ollama is available and properly configured"""
    global OLLAMA_AVAILABLE, OLLAMA_MODEL
    
    try:
        # First check if Ollama service is running
        logger.info("🔍 Checking if Ollama service is running...")
        
        # Check if models endpoint is accessible
        try:
            models = ollama.list()
            logger.info("✅ Ollama service is running")
            logger.debug(f"Ollama models response: {models}")
            
            # Check if our specific model is available
            logger.info(f"🔍 Checking if model '{OLLAMA_MODEL}' is available...")
            model_available = False
            
            # Try to directly parse the models format that's returned by your Ollama version
            try:
                # The model list from the output of 'ollama list' command shows:
                # NAME, ID, SIZE, MODIFIED
                # So we'll try to match based on "name" which is the first column
                if isinstance(models, dict) and 'models' in models:
                    model_list = models['models']
                    # Log the structure to understand what we're dealing with
                    logger.debug(f"Model list structure: {model_list[:1] if model_list else 'empty'}")
                    
                    # Find the model by name
                    for model in model_list:
                        model_name = model.get('name', '')
                        if model_name == OLLAMA_MODEL:
                            model_available = True
                            logger.info(f"✅ Found Ollama model: {OLLAMA_MODEL}")
                            break
                elif isinstance(models, list):
                    # Try an alternative format where it might be a simple list
                    for model in models:
                        if isinstance(model, dict):
                            model_name = model.get('name', '')
                            if model_name == OLLAMA_MODEL:
                                model_available = True
                                logger.info(f"✅ Found Ollama model: {OLLAMA_MODEL}")
                                break
                
                # Log all available models to help with debugging
                if isinstance(models, dict) and 'models' in models:
                    available_models = [m.get('name', '') for m in models['models'] if isinstance(m, dict)]
                elif isinstance(models, list):
                    available_models = [m.get('name', '') for m in models if isinstance(m, dict)]
                else:
                    available_models = []
                
                logger.info(f"Available models: {available_models}")
                
                # Simple string match with model names
                model_name_simple = OLLAMA_MODEL.split(':')[0] if ':' in OLLAMA_MODEL else OLLAMA_MODEL
                matching_models = [m for m in available_models if model_name_simple in m]
                
                if not model_available and matching_models:
                    logger.info(f"Found partial match with: {matching_models[0]}")
                    OLLAMA_MODEL = matching_models[0]  # Use the first matching model
                    model_available = True
                
            except Exception as e:
                logger.error(f"Error parsing model list: {e}")
                logger.debug(f"Model parse error details: {traceback.format_exc()}")
            
            if not model_available:
                # Try simply checking if the model is listed
                try:
                    from subprocess import run, PIPE
                    result = run(["ollama", "list"], stdout=PIPE, text=True)
                    output = result.stdout
                    logger.debug(f"Ollama list output: {output}")
                    
                    # Check if our model is in the output
                    if OLLAMA_MODEL in output:
                        logger.info(f"✅ Found model '{OLLAMA_MODEL}' in command output")
                        model_available = True
                    # Check for partial match (e.g., 'llava' in 'llava:latest')
                    elif model_name_simple in output:
                        logger.info(f"✅ Found partial match for '{model_name_simple}' in command output")
                        # Extract the full model name from output
                        lines = output.strip().split('\n')
                        for line in lines[1:]:  # Skip header
                            if model_name_simple in line:
                                parts = line.split()
                                if parts:
                                    OLLAMA_MODEL = parts[0]  # First column is NAME
                                    logger.info(f"Using model: {OLLAMA_MODEL}")
                                    model_available = True
                                    break
                except Exception as cmd_e:
                    logger.error(f"Error running ollama list command: {cmd_e}")
            
            # If model still not found, try pulling it
            if not model_available:
                logger.warning(f"Model '{OLLAMA_MODEL}' not found, attempting to pull it...")
                try:
                    ollama.pull(OLLAMA_MODEL)
                    logger.info(f"✅ Successfully pulled model: {OLLAMA_MODEL}")
                    model_available = True
                except Exception as e:
                    logger.error(f"Failed to pull model: {e}")
                    # Fallback to a simpler model name without tags
                    if ':' in OLLAMA_MODEL:
                        base_model = OLLAMA_MODEL.split(':')[0]
                        logger.info(f"Trying with base model: {base_model}")
                        try:
                            ollama.pull(base_model)
                            logger.info(f"✅ Successfully pulled base model: {base_model}")
                            OLLAMA_MODEL = base_model
                            model_available = True
                        except Exception as e2:
                            logger.error(f"Failed to pull base model: {e2}")
                    
                    # Last resort: try llava
                    if not model_available and OLLAMA_MODEL != 'llava':
                        logger.warning("Trying to fall back to 'llava' model...")
                        try:
                            ollama.pull('llava')
                            logger.info("✅ Successfully pulled 'llava' model")
                            OLLAMA_MODEL = 'llava'
                            model_available = True
                        except Exception as e3:
                            logger.error(f"Failed to pull 'llava' model: {e3}")
            
            # All attempts failed
            if not model_available:
                logger.error("❌ No compatible models available")
                logger.error("Please install Ollama and pull a vision model manually:")
                logger.error("1. Install Ollama from https://ollama.com")
                logger.error("2. Run 'ollama serve' in a terminal")
                logger.error("3. Run 'ollama pull llava' in another terminal")
                return False
            
            return model_available
            
        except Exception as e:
            logger.error(f"Error checking Ollama models: {e}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Ollama check failed: {e}")
        logger.error("Possible causes:")
        logger.error("1. Ollama is not installed - download from https://ollama.com")
        logger.error("2. Ollama service is not running - run 'ollama serve' in a terminal")
        logger.error("3. Your system doesn't meet the requirements to run Ollama")
        
        # Add detailed error information for debugging
        import traceback
        logger.debug(f"Detailed error: {traceback.format_exc()}")
        return False

# Check Ollama availability at startup
logger.info("Checking Ollama availability...")
OLLAMA_AVAILABLE = check_ollama_availability()
logger.info(f"Ollama available: {OLLAMA_AVAILABLE}, using model: {OLLAMA_MODEL}")

if not OLLAMA_AVAILABLE:
    logger.warning("⚠️ Ollama is not available - receipt scanning will use fallback mode with limited accuracy")
    logger.warning("Running in fallback mode (regex parsing only)")
    logger.warning("For full accuracy, please install Ollama from https://ollama.com and run 'ollama pull llava'")
else:
    logger.info("✅ Ollama is properly configured and ready to use!")
    
# Force setting OLLAMA_AVAILABLE if environment variable is set - for testing/debugging
if os.getenv('FORCE_OLLAMA_AVAILABLE', '').lower() == 'true':
    logger.warning("⚠️ Forcing OLLAMA_AVAILABLE = True from environment setting")
    OLLAMA_AVAILABLE = True
elif os.getenv('FORCE_OLLAMA_AVAILABLE', '').lower() == 'false':
    logger.warning("⚠️ Forcing OLLAMA_AVAILABLE = False from environment setting")
    OLLAMA_AVAILABLE = False

# Check system requirements
def check_system_requirements():
    """Check if the system meets the requirements for running vision models"""
    system_info = {
        "os": platform.system(),
        "os_version": platform.version(),
        "python_version": platform.python_version(),
        "cpu_count": os.cpu_count(),
        "ram_gb": round(psutil.virtual_memory().total / (1024 ** 3), 2),
        "gpu_available": torch.cuda.is_available(),
        "gpu_count": torch.cuda.device_count() if torch.cuda.is_available() else 0,
        "can_run_local_model": False,
        "reason": ""
    }
    
    if system_info["gpu_available"]:
        system_info["gpu_names"] = [torch.cuda.get_device_name(i) for i in range(system_info["gpu_count"])]
        system_info["gpu_memory_gb"] = [round(torch.cuda.get_device_properties(i).total_memory / (1024 ** 3), 2) for i in range(system_info["gpu_count"])]
    
    # Get requirements from env settings
    min_ram_gb = float(os.getenv('MIN_RAM_GB', '8'))
    min_gpu_memory_gb = float(os.getenv('MIN_GPU_MEMORY_GB', '4'))
    
    logger.info(f"🖥️ System requirements: RAM: {min_ram_gb}GB, GPU Memory: {min_gpu_memory_gb}GB")
    logger.info(f"🖥️ Available resources: RAM: {system_info['ram_gb']}GB, GPU: {system_info['gpu_available']}")
    
    # Check if system meets requirements
    if system_info["ram_gb"] < min_ram_gb:
        system_info["reason"] = f"⚠️ Insufficient RAM: {system_info['ram_gb']}GB (minimum: {min_ram_gb}GB)"
    elif ENABLE_GPU and not system_info["gpu_available"]:
        system_info["reason"] = "⚠️ GPU acceleration requested but no GPU available"
    elif ENABLE_GPU and system_info["gpu_count"] > 0 and all(mem < min_gpu_memory_gb for mem in system_info["gpu_memory_gb"]):
        system_info["reason"] = f"⚠️ Insufficient GPU memory: {max(system_info['gpu_memory_gb'])}GB (minimum: {min_gpu_memory_gb}GB)"
    else:
        system_info["can_run_local_model"] = True
        if system_info["gpu_available"] and ENABLE_GPU:
            logger.info(f"✅ System can run model with GPU acceleration")
        else:
            logger.info(f"✅ System can run model on CPU")
    
    if system_info["reason"]:
        logger.warning(system_info["reason"])
    
    return system_info

# Initialize receipt processing
logger.info("Loading receipt processing system...")
system_info = check_system_requirements()

# Configure FastAPI
app = FastAPI(
    title="Receipt Scanner API",
    description="API for analyzing receipts using AI vision models",
    version="1.0.0",
    root_path=os.getenv('ROOT_PATH', '')
)

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(GZipMiddleware, minimum_size=1000)

class ReceiptRequest(BaseModel):
    text: str = None  # Optional OCR text from the client
    image: str = None  # Optional base64-encoded image
    ollama_config: dict = None  # Optional Ollama model configuration

def process_with_ollama(text=None, image_base64=None, max_retries=2):
    """Process receipt text and image with Ollama"""
    if not OLLAMA_AVAILABLE:
        logger.warning("Ollama is not available. Cannot process with Ollama.")
        return None
    
    if not text and not image_base64:
        logger.warning("No text or image provided for Ollama processing")
        return None
    
    # Prepare the prompt for receipt extraction
    prompt = """Analyze this receipt image and extract the following information in JSON format:
- merchant_name: The business name
- date: The date of purchase (YYYY-MM-DD format if possible)
- items: An array of items purchased, each with:
  - name: Clear product name (not just numbers)
  - quantity: Numeric quantity (as an integer)
  - unit_price: Individual price (as a float)
- total_amount: The total amount paid

Format your response as valid JSON with EXACTLY the field names shown above. The Flutter app requires 'unit_price' NOT 'price' for items. The app expects:
{
  "merchant_name": "Store Name",
  "date": "2023-10-15",
  "items": [
    {
      "name": "Product name",
      "quantity": 1,
      "unit_price": 10.99
    }
  ],
  "total_amount": 10.99
}

Return ONLY valid JSON without any explanation text. Ensure all item names are descriptive, not just numbers."""

    # Use image if provided, otherwise just use text
    data = {
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False
    }
    
    # Add the image if provided
    if image_base64:
        try:
            # Convert base64 string to image for Ollama
            image_data = base64.b64decode(image_base64)
            data["images"] = [image_base64]
            logger.info(f"Including image in Ollama request (size: {len(image_data)} bytes)")
        except Exception as e:
            logger.error(f"Error processing image for Ollama: {str(e)}")
    
    # Add the text if provided
    if text:
        if "prompt" in data:
            data["prompt"] += f"\n\nOCR Text from receipt:\n{text[:1000]}"
        else:
            data["prompt"] = f"OCR Text from receipt:\n{text[:1000]}"
    
    # Configure GPU usage if available
    options = {}
    if os.environ.get("ENABLE_GPU", "false").lower() == "true" and system_info.get("gpu_available"):
        options = {"num_gpu": 1}
        logger.info("Using GPU for Ollama processing")
    
    # Retry logic for Ollama API calls
    result = None
    retry_count = 0
    
    while retry_count <= max_retries:
        try:
            # Make the API call
            logger.info(f"Calling Ollama API with model {OLLAMA_MODEL} (attempt {retry_count+1}/{max_retries+1})")
            start_time = time.time()
            
            try:
                response = ollama.generate(**data, options=options)
                # Log the time taken
                elapsed = time.time() - start_time
                logger.info(f"Ollama response received in {elapsed:.2f}s")
            except Exception as e:
                if "model not found" in str(e).lower():
                    # If model not found in expected format, try simpler model name
                    model_name_simple = OLLAMA_MODEL.split(':')[0] if ':' in OLLAMA_MODEL else OLLAMA_MODEL
                    logger.warning(f"Model '{OLLAMA_MODEL}' not found, trying with '{model_name_simple}'")
                    data["model"] = model_name_simple
                    response = ollama.generate(**data, options=options)
                    elapsed = time.time() - start_time
                    logger.info(f"Ollama response with '{model_name_simple}' received in {elapsed:.2f}s")
                else:
                    raise
            
            if not response or "response" not in response:
                logger.warning("Empty or invalid response from Ollama")
                retry_count += 1
                time.sleep(1)  # Small delay before retry
                continue
            
            # Extract the text response
            response_text = response.get("response", "")
            if not response_text.strip():
                logger.warning("Empty text response from Ollama")
                retry_count += 1
                time.sleep(1)  # Small delay before retry
                continue
            
            # Try to extract JSON from the response
            try:
                # First, try to find JSON within the response (in case the model added extra text)
                json_match = re.search(r'```json\s*(.*?)\s*```', response_text, re.DOTALL)
                if json_match:
                    json_text = json_match.group(1)
                    logger.info("Found JSON in code block format")
                else:
                    # Look for opening and closing braces to find JSON
                    start_idx = response_text.find('{')
                    end_idx = response_text.rfind('}')
                    if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
                        json_text = response_text[start_idx:end_idx+1]
                        logger.info("Extracted JSON using brace detection")
                    else:
                        # Just use the whole text as JSON
                        json_text = response_text
                        logger.info("Using full response as JSON")
                
                # Parse the extracted JSON
                logger.debug(f"Attempting to parse JSON: {json_text[:200]}...")
                parsed = json.loads(json_text)
                
                # Normalize field names (handle potential inconsistencies)
                normalized = {}
                
                # Handle merchant name
                if "merchant_name" in parsed:
                    normalized["merchant_name"] = parsed["merchant_name"]
                elif "merchantName" in parsed:
                    normalized["merchant_name"] = parsed["merchantName"]
                elif "merchant" in parsed:
                    normalized["merchant_name"] = parsed["merchant"]
                else:
                    normalized["merchant_name"] = "Unknown Merchant"
                
                # Handle date
                if "date" in parsed:
                    normalized["date"] = parsed["date"]
                elif "purchase_date" in parsed:
                    normalized["date"] = parsed["purchase_date"]
                else:
                    normalized["date"] = ""
                
                # Handle total amount
                if "total_amount" in parsed:
                    normalized["total_amount"] = parsed["total_amount"]
                elif "totalAmount" in parsed:
                    normalized["total_amount"] = parsed["totalAmount"]
                elif "total" in parsed:
                    normalized["total_amount"] = parsed["total"]
                else:
                    normalized["total_amount"] = "0.00"
                
                # Ensure total is a string
                if not isinstance(normalized["total_amount"], str):
                    normalized["total_amount"] = str(normalized["total_amount"])
                
                # Handle items array
                normalized["items"] = []
                items_key = next((k for k in ["items", "orderItems"] if k in parsed), None)
                
                if items_key and isinstance(parsed[items_key], list):
                    for item in parsed[items_key]:
                        # Skip items without a name or with numeric-only names
                        item_name = item.get("name", "")
                        if not item_name or (item_name.replace(".", "").isdigit()):
                            continue
                        
                        # Process the item
                        processed_item = {
                            "name": item_name,
                            "quantity": "1",
                            "unit_price": "0.00"
                        }
                        
                        # Get quantity
                        if "quantity" in item:
                            try:
                                qty = item["quantity"]
                                # Convert to string if numeric
                                if isinstance(qty, (int, float)):
                                    processed_item["quantity"] = str(qty)
                                else:
                                    processed_item["quantity"] = str(qty)
                            except:
                                processed_item["quantity"] = "1"
                        
                        # Get price - handle both price and unit_price fields
                        price_key = next((k for k in ["unit_price", "price", "amount"] if k in item), None)
                        if price_key:
                            try:
                                price = item[price_key]
                                # Convert to string if numeric
                                if isinstance(price, (int, float)):
                                    processed_item["unit_price"] = str(price)
                                else:
                                    processed_item["unit_price"] = str(price)
                            except:
                                processed_item["unit_price"] = "0.00"
                        
                        normalized["items"].append(processed_item)
                
                # Add at least one item if none were found
                if not normalized["items"]:
                    logger.warning("No valid items found in Ollama response, adding a generic item")
                    total = normalized["total_amount"]
                    try:
                        total_float = float(total.replace("$", "").replace(",", ""))
                        if total_float > 0:
                            normalized["items"].append({
                                "name": "Purchase Item",
                                "quantity": "1",
                                "unit_price": normalized["total_amount"]
                            })
                    except:
                        normalized["items"].append({
                            "name": "Unknown Item",
                            "quantity": "1",
                            "unit_price": "0.00"
                        })
                
                # Set language (defaulting to English if not provided)
                if "detected_language" in parsed:
                    normalized["detected_language"] = parsed["detected_language"]
                else:
                    normalized["detected_language"] = "en"
                
                # Log the extracted data
                logger.info(f"Successfully extracted receipt data with {len(normalized['items'])} items")
                result = normalized
                break  # Success, exit the retry loop
                
            except Exception as json_err:
                logger.error(f"Error parsing JSON from Ollama response: {str(json_err)}")
                logger.debug(f"Raw response: {response_text[:200]}...")
                retry_count += 1
                time.sleep(1)  # Small delay before retry
        
        except Exception as e:
            logger.error(f"Error calling Ollama API: {str(e)}")
            if "no such file" in str(e).lower() or "not found" in str(e).lower():
                logger.error("The Ollama model may not be installed correctly.")
                logger.error(f"Please run: ollama pull {OLLAMA_MODEL}")
            elif "connection refused" in str(e).lower():
                logger.error("Cannot connect to Ollama service. Make sure it's running.")
                logger.error("Run 'ollama serve' in a terminal")
            retry_count += 1
            time.sleep(1)  # Small delay before retry
    
    return result

def fallback_regex_parsing(text, result=None):
    """Fallback regex parsing for when Ollama fails"""
    if result is None:
        result = {
            "merchant_name": "",
            "date": "",
            "items": [],
            "total_amount": "0.00",
            "detected_language": "en"
        }
    
    logger.info("Performing fallback regex parsing")
    
    # Extract merchant name (usually at the top of the receipt)
    merchant_pattern = r'(?:^|\n)([A-Z][A-Za-z0-9\s&\'.-]{2,25})(?:\n|\s{2,})'
    merchant_matches = re.findall(merchant_pattern, text)
    if merchant_matches:
        # Use the first substantial match that's not generic
        for match in merchant_matches[:3]:  # Only consider first few matches
            if match.strip() and not re.match(r'TOTAL|SUBTOTAL|TAX|RECEIPT|ORDER|ITEM|PRICE|QTY|DATE', match.strip()):
                result["merchant_name"] = match.strip()
                logger.info(f"Extracted merchant name: {result['merchant_name']}")
                break
    
    # Extract date
    date_patterns = [
        r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',  # MM/DD/YYYY, MM-DD-YYYY
        r'(\d{4}[/-]\d{1,2}[/-]\d{1,2})',    # YYYY/MM/DD, YYYY-MM-DD
        r'((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{1,2},? \d{2,4})'  # Month DD, YYYY
    ]
    
    for pattern in date_patterns:
        date_matches = re.findall(pattern, text)
        if date_matches:
            result["date"] = date_matches[0]
            logger.info(f"Extracted date: {result['date']}")
            break
    
    # Extract total amount
    total_patterns = [
        r'(?:total|tot).*?[$]?(\d+\.\d{2})',
        r'(?:total|tot).*?(\d+\.\d{2})',
        r'[$]?(\d+\.\d{2}).*?(?:total|tot)',
        r'(\d+\.\d{2}).*?(?:total|tot)'
    ]
    
    for pattern in total_patterns:
        total_matches = re.findall(pattern, text.lower())
        if total_matches:
            try:
                total = float(total_matches[-1])  # Use the last match as it's likely the final total
                result["total_amount"] = str(total)  # Convert to string to match format
                logger.info(f"Extracted total amount: {result['total_amount']}")
                break
            except:
                continue
    
    # Extract items using multiple strategies
    all_items = []
    
    # Strategy 1: Look for common item patterns with names
    item_patterns = [
        r'(\d+)\s+([A-Za-z][A-Za-z0-9\s&\'.,-]{2,30})\s+(\d+\.\d{2})',  # Qty Item Price
        r'([A-Za-z][A-Za-z0-9\s&\'.,-]{2,30})\s+(\d+)\s+(\d+\.\d{2})',  # Item Qty Price
        r'([A-Za-z][A-Za-z0-9\s&\'.,-]{2,30})\s+(\d+\.\d{2})',          # Item Price
    ]
    
    logger.info("Attempting to extract items with name patterns")
    
    for pattern in item_patterns:
        item_matches = re.findall(pattern, text)
        if item_matches:
            for match in item_matches:
                try:
                    if len(match) == 3:  # Qty Item Price or Item Qty Price
                        if re.match(r'\d+', match[0]) and not re.match(r'\d+\.\d{2}', match[0]):
                            # Qty Item Price format
                            item = {
                                "name": match[1].strip(),
                                "quantity": match[0],
                                "unit_price": match[2],
                                "item_type": "retail"
                            }
                        else:
                            # Item Qty Price format
                            item = {
                                "name": match[0].strip(),
                                "quantity": match[1],
                                "unit_price": match[2],
                                "item_type": "retail"
                            }
                    elif len(match) == 2:  # Item Price
                        item = {
                            "name": match[0].strip(),
                            "quantity": "1",
                            "unit_price": match[1],
                            "item_type": "retail"
                        }
                    
                    # Skip items with generic or unlikely names
                    if re.match(r'(?:sub)?total|tax|tip|item|price|qty|amount', item["name"].lower()):
                        continue
                        
                    # Skip if item name is just a number
                    if re.match(r'^\d+$', item["name"]):
                        continue
                        
                    all_items.append(item)
                    logger.info(f"Extracted item: {item['name']} - {item['quantity']} x {item['unit_price']}")
                except Exception as e:
                    logger.error(f"Error processing item match: {e}")
                    continue
    
    # Strategy 2: Look for lines with just prices and try to associate them with nearby text
    if not all_items:
        logger.info("No items found with standard patterns, trying price-based extraction")
        lines = text.split('\n')
        
        # First pass: identify prices
        price_lines = []
        for i, line in enumerate(lines):
            price_match = re.search(r'(\d+\.\d{2})', line)
            if price_match and not re.search(r'(?:total|subtotal|tax|discount|amount)', line.lower()):
                price_lines.append((i, price_match.group(1)))
        
        # Second pass: find potential item names near prices
        for price_index, price in price_lines:
            # Look at the line above the price for an item name
            potential_name = ""
            if price_index > 0:
                potential_name = lines[price_index - 1].strip()
            
            # If no name found or name is too short/contains unwanted text, try the same line
            if not potential_name or len(potential_name) < 3 or re.search(r'(?:total|subtotal|tax|discount|amount)', potential_name.lower()):
                # Try to extract name from the price line itself
                name_part = re.sub(r'\s*\d+\.\d{2}\s*', '', lines[price_index]).strip()
                if name_part and len(name_part) >= 3 and not re.search(r'(?:total|subtotal|tax|discount|amount)', name_part.lower()):
                    potential_name = name_part
            
            # If we found a valid name, add the item
            if potential_name and len(potential_name) >= 3 and not re.match(r'^\d+$', potential_name):
                all_items.append({
                    "name": potential_name,
                    "quantity": "1",
                    "unit_price": price,
                    "item_type": "retail"
                })
                logger.info(f"Extracted item from price association: {potential_name} - {price}")
    
    # If we still don't have items, create generic ones based on total
    if not all_items and result["total_amount"] != "0.00":
        logger.info("No specific items found, creating a generic item")
        all_items.append({
            "name": f"Item from {result['merchant_name']}" if result["merchant_name"] else "Receipt Item",
            "quantity": "1",
            "unit_price": result["total_amount"],
            "item_type": "retail"
        })
    
    # Add all found items to the result
    result["items"] = all_items
    logger.info(f"Extracted {len(all_items)} items in total")
    
    return result

@app.post("/analyze-receipt")
async def analyze_receipt(request: ReceiptRequest):
    try:
        # First check if we have any data to work with
        if not request.text and not request.image:
            logger.error("Both text and image are empty")
            return JSONResponse(
                status_code=422,
                content={"success": False, "error": "Either text or image is required for receipt analysis"}
            )
            
        # Log what we received
        if request.text:
            logger.info(f"Received request with text length: {len(request.text.strip())}")
        if request.image:
            logger.info(f"Received request with image (base64 length: {len(request.image)})")
            
        # Process with Ollama if available
        result = None
        model_used = "regex_fallback"
        processing_notes = []
        
        # First check if Ollama was initially not available but might be now
        if not OLLAMA_AVAILABLE:
            # Try to check if Ollama is available now (might have been started after API startup)
            if check_ollama_availability():
                logger.info("✅ Ollama is now available, will use it for processing")
                processing_notes.append("Ollama became available during runtime")
            else:
                processing_notes.append("Ollama is not available, using fallback parsing only")
        
        # Declare global variable before any usage in the function
        global OLLAMA_MODEL
        
        # Try to use Ollama if available
        if OLLAMA_AVAILABLE:
            try:
                logger.info("🧠 Processing with Ollama vision model")
                processing_notes.append(f"Using Ollama model: {OLLAMA_MODEL}")
                
                # Update OLLAMA_MODEL if specified in request
                if request.ollama_config and "model" in request.ollama_config:
                    temp_model = request.ollama_config["model"]
                    logger.info(f"Custom model requested: {temp_model}")
                    
                    # Verify if requested model is available, otherwise keep current model
                    try:
                        models = ollama.list()
                        if models and 'models' in models:
                            model_available = False
                            for model in models['models']:
                                if model['name'] == temp_model:
                                    model_available = True
                                    break
                                    
                            if model_available:
                                OLLAMA_MODEL = temp_model
                                logger.info(f"Using custom model: {OLLAMA_MODEL}")
                                processing_notes.append(f"Switched to requested model: {OLLAMA_MODEL}")
                            else:
                                logger.warning(f"Requested model {temp_model} not available, using {OLLAMA_MODEL}")
                                processing_notes.append(f"Requested model {temp_model} not available")
                    except Exception as e:
                        logger.error(f"Error checking for model {temp_model}: {e}")
                        processing_notes.append(f"Error checking for model {temp_model}")
                
                # Process with Ollama
                ollama_result = process_with_ollama(request.text, request.image)
                
                if ollama_result:
                    logger.info("✅ Successfully processed with Ollama")
                    result = ollama_result
                    model_used = f"ollama-{OLLAMA_MODEL}"
                    processing_notes.append("Ollama processing successful")
                else:
                    logger.warning("⚠️ Ollama processing failed, falling back to regex parsing")
                    processing_notes.append("Ollama processing failed, using fallback parsing")
            except Exception as e:
                logger.error(f"❌ Exception during Ollama processing: {str(e)}")
                logger.warning("⚠️ Exception in Ollama processing, falling back to regex parsing")
                processing_notes.append(f"Ollama error: {str(e)}")
        else:
            logger.warning("⚠️ Ollama is not available, using regex fallback parsing")
            processing_notes.append("Ollama not available")
        
        # Fallback to regex parsing if Ollama failed or is not available
        if result is None and request.text:
            logger.info("Using regex fallback parsing")
            result = fallback_regex_parsing(request.text)
            model_used = "regex_fallback"
            processing_notes.append("Used regex fallback parsing")
        elif result is None:
            logger.error("❌ All processing methods failed and no text for regex fallback")
            return JSONResponse(
                status_code=422,
                content={
                    "success": False, 
                    "error": "Failed to process receipt. Please take a clearer image or ensure Ollama is running properly.",
                    "details": {
                        "ollama_available": OLLAMA_AVAILABLE,
                        "processing_notes": processing_notes
                    }
                }
            )
        
        # Return the result with appropriate processing info
        return {
            "success": True, 
            "data": result, 
            "processing_info": {
                "model_used": model_used,
                "timestamp": datetime.now().isoformat(),
                "system_info": {
                    "ollama_available": OLLAMA_AVAILABLE,
                    "ollama_model": OLLAMA_MODEL,
                    "gpu_available": system_info["gpu_available"]
                },
                "processing_notes": processing_notes
            }
        }

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        return JSONResponse(
            status_code=500,
            content={
                "success": False, 
                "error": f"Server error: {str(e)}",
                "details": {
                    "ollama_available": OLLAMA_AVAILABLE,
                    "gpu_available": system_info.get("gpu_available", False)
                }
            }
        )

@app.get("/")
async def read_root():
    return {
        "message": "Welcome to the Receipt Scanner API",
        "model": f"Ollama {OLLAMA_MODEL} Vision Model",
        "supported_languages": ["English"],
        "system_info": system_info
    }

if __name__ == "__main__":
    import nest_asyncio
    nest_asyncio.apply()
    
    try:
        # Start Ollama service if not already running
        import subprocess
        import platform
        import time
        
        logger.info("🚀 Starting Receipt Analysis API...")
        
        # Try to start Ollama service if it's not already running
        try:
            logger.info("Checking if Ollama service is running...")
            ollama_process = None
            
            if platform.system() == "Windows":
                # Check if Ollama is already running
                try:
                    subprocess.run(["tasklist", "/FI", "IMAGENAME eq ollama.exe"], 
                                  check=True, 
                                  stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE)
                    
                    if "ollama.exe" not in subprocess.run(["tasklist", "/FI", "IMAGENAME eq ollama.exe"], 
                                                        check=True, 
                                                        stdout=subprocess.PIPE,
                                                        stderr=subprocess.PIPE,
                                                        text=True).stdout:
                        logger.info("Ollama is not running, attempting to start it...")
                        # Start Ollama in the background
                        ollama_process = subprocess.Popen(["ollama", "serve"], 
                                                       creationflags=subprocess.CREATE_NEW_CONSOLE)
                        logger.info("Waiting for Ollama service to start...")
                        time.sleep(5)  # Give it some time to start
                except Exception as e:
                    logger.warning(f"Could not check or start Ollama service: {e}")
                    logger.warning("Please start Ollama manually by running 'ollama serve' in a separate terminal")
            elif platform.system() == "Darwin" or platform.system() == "Linux":
                # Check if Ollama is already running on Unix-like systems
                try:
                    ps_output = subprocess.run(["ps", "aux"], check=True, stdout=subprocess.PIPE, text=True).stdout
                    if "ollama serve" not in ps_output:
                        logger.info("Ollama is not running, attempting to start it...")
                        # Start Ollama in the background
                        ollama_process = subprocess.Popen(["ollama", "serve"], 
                                                      stdout=subprocess.DEVNULL,
                                                      stderr=subprocess.DEVNULL)
                        logger.info("Waiting for Ollama service to start...")
                        time.sleep(5)  # Give it some time to start
                except Exception as e:
                    logger.warning(f"Could not check or start Ollama service: {e}")
                    logger.warning("Please start Ollama manually by running 'ollama serve' in a separate terminal")
        except Exception as e:
            logger.warning(f"Error checking Ollama service: {e}")
        
        # Run initial Ollama check
        check_ollama_availability()
        
        # Setup Ngrok for exposing the API
        from pyngrok import ngrok, conf
        import os
        
        # Get Ngrok authtoken from environment or .env file
        ngrok_token = os.environ.get("NGROK_AUTHTOKEN")
        if not ngrok_token:
            logger.warning("⚠️ NGROK_AUTHTOKEN not found in environment variables")
            logger.warning("The API will only be available locally")
        else:
            logger.info("🔑 Setting up ngrok with provided auth token")
            conf.get_default().auth_token = ngrok_token
        
        # Start the API server
        port = int(os.environ.get("PORT", 8000))
        
        # Start ngrok tunnel
        if ngrok_token:
            # Close any existing tunnels
            try:
                for tunnel in ngrok.get_tunnels():
                    ngrok.disconnect(tunnel.public_url)
            except:
                pass
                
            # Create new tunnel
            try:
                public_url = ngrok.connect(port, "http")
                logger.info(f"🌎 Public URL: {public_url}")
                logger.info("Share this URL to access your API from anywhere")
            except Exception as e:
                logger.error(f"❌ Failed to create ngrok tunnel: {e}")
                logger.info(f"⚓ API will be available locally at http://127.0.0.1:{port}")
        else:
            logger.info(f"⚓ API available locally at http://127.0.0.1:{port}")
        
        # Start the API server
        import uvicorn
        uvicorn.run(app, host="0.0.0.0", port=port)
        
    except KeyboardInterrupt:
        logger.info("👋 Shutting down gracefully...")
        # Disconnect any ngrok tunnels
        try:
            for tunnel in ngrok.get_tunnels():
                ngrok.disconnect(tunnel.public_url)
        except:
            pass
        # Close the Ollama process if we started it
        if ollama_process:
            ollama_process.terminate()
    except Exception as e:
        logger.error(f"❌ Error starting API: {e}")
        import traceback
        logger.error(traceback.format_exc())