from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.middleware.gzip import GZipMiddleware
import logging
import json
from pydantic import BaseModel
import os
from dotenv import load_dotenv
import time
import torch
import re
from datetime import datetime
import ollama  # For Ollama reasoning

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

# Initialize receipt processing
logger.info("Loading receipt processing system...")

# Check if Ollama is available
OLLAMA_AVAILABLE = False
OLLAMA_MODEL = "mistral"  # Default model for receipt parsing

try:
    # Check if we can connect to Ollama
    ollama_response = ollama.list()
    logger.info(f"Successfully connected to Ollama: {ollama_response}")
    OLLAMA_AVAILABLE = True
except Exception as e:
    logger.warning(f"Ollama not available: {e}. Will use regex fallback.")

logger.info(f"Ollama available: {OLLAMA_AVAILABLE}")
if OLLAMA_AVAILABLE:
    logger.info(f"Using Ollama with model: {OLLAMA_MODEL}")

# Configure FastAPI
app = FastAPI(
    title="Receipt Scanner API",
    description="API for analyzing receipts using text processing",
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
    text: str  # OCR text from the client (now required)
    ollama_config: dict = None  # Optional Ollama model configuration

def process_with_ollama(text):
    """Process receipt text with Ollama for advanced parsing"""
    if not OLLAMA_AVAILABLE:
        logger.warning("Ollama not available, cannot process with Ollama")
        return None
    
    try:
        logger.info(f"Processing text with Ollama model: {OLLAMA_MODEL}")
        
        # Clean the text for prompt injection safety and to avoid string formatting issues
        # Replace % with the word 'percent' to avoid format string issues
        safe_text = text
        
        # Handle all potential format specifiers and special characters that could cause formatting issues
        replacements = {
            '%': ' percent ',
            '{': ' bracket_open ',
            '}': ' bracket_close ',
            '$': ' dollar ',
            '\\': ' backslash '
        }
        
        for char, replacement in replacements.items():
            safe_text = safe_text.replace(char, replacement)
        
        # Log the sanitized text for debugging
        logger.info(f"Sanitized text for Ollama: {safe_text[:100]}...")
        
        # Create prompt with the sanitized text - using triple quotes for robustness
        prompt = f'''You are an expert receipt analyzer with deep knowledge of food items, retail products, and OCR text processing. Your task is to extract structured information from potentially messy OCR text.

Receipt OCR text to analyze:

{safe_text}

DOMAIN EXPERTISE:
1. FOOD ITEMS: You know thousands of dishes, menu items, and ingredients.
   - Desserts: cheesecake (mango, strawberry, chocolate), cakes, pies, ice cream, etc.
   - Beverages: coffee (americano, latte, cappuccino), tea, smoothies, juice, etc.
   - Cuisines: Italian (pasta, pizza), Asian (sushi, noodles), etc.

2. RETAIL PRODUCTS: You recognize product categories and common item formats.
   - Groceries: produce, dairy, meat, packaged foods, etc.
   - Household: cleaning supplies, toiletries, tools, etc.
   - Electronics: devices, accessories, components, etc.

3. SERVICES: You understand common service charges.
   - Food delivery fees, service charges, tips
   - Taxes, discounts, membership benefits

OCR CORRECTION EXPERTISE:
1. Fix garbled characters and spacing issues:
   - "HANGOCHEESECAKE" → "MANGO CHEESECAKE"
   - "STRAWBERRYCAKE" → "STRAWBERRY CAKE"
   - "waterrnelon" → "watermelon"
   - "FriedRice" → "Fried Rice"
   - "0." → "o" (replace zero followed by period with letter o)
   - "l." → "i" (replace lowercase L followed by period with letter i)
   - "RF0.D" → "RFOOD" (common food-related OCR error)

2. Correct common OCR errors:
   - Character substitutions: 0/O, l/I/1, rn/m, cl/d
   - Missing spaces between items
   - Merged product names and descriptions
   - Numeric/letter confusion: 0 for O, 1 for I or l

REASONING APPROACH:
1. IDENTIFY RECEIPT TYPE:
   - Restaurant? Look for menu items, table numbers, server names
   - Cafe? Look for beverages, pastries, small food items
   - Retail? Look for product codes, quantities, department indicators

2. CLASSIFY ITEMS:
   - Food items: Look for dishes, ingredients, portion sizes
   - Drinks: Look for beverage types, sizes, modifications
   - Services: Look for fees, charges, gratuities

3. IDENTIFY PATTERNS:
   - Quantity patterns: numbers followed by "x", "@", or "ea"
   - Price patterns: look for consistent decimal formats
   - Subtotal/tax/total sections: often at the bottom of receipts

STRUCTURE YOUR RESPONSE AS JSON with these exact fields:
{{"merchant_name": "Store or Restaurant Name",
  "date": "YYYY-MM-DD", 
  "items": [
    {{"name": "Item description", "quantity": 1, "unit_price": 0.00, "item_type": "food/drink/retail/service"}}
  ],
  "total_amount": 0.00
}}

STRICT RULES:
1. ONLY include items that are clearly mentioned in the receipt text
2. Do NOT hallucinate or make up items not present in the text
3. If quantities are not specified, default to 1
4. Format the date as YYYY-MM-DD if present, otherwise leave blank
5. NEVER include generic items like "Item" or "Product" unless that's the literal name
6. Identify the merchant name from the receipt header when available
7. For ambiguous or partially readable text, use your expertise to infer the most likely item

APPLY YOUR EXPERTISE and extract the structured information from the OCR text.
'''

        # Use robust error handling for the Ollama API call
        try:
            # Send to Ollama for processing
            response = ollama.chat(
                model=OLLAMA_MODEL,
                messages=[{"role": "user", "content": prompt}]
            )
            
            if response and 'message' in response and 'content' in response['message']:
                ollama_response = response['message']['content']
                logger.info(f"Received response from Ollama: {ollama_response[:100]}...")
                
                # Extract JSON from the response - robust to different response formats
                json_match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', ollama_response, re.DOTALL)
                
                if not json_match:
                    # Try to find JSON without code blocks
                    json_match = re.search(r'(\{.*"total_amount".*?\})', ollama_response, re.DOTALL)
                
                if json_match:
                    json_str = json_match.group(1)
                    try:
                        parsed_data = json.loads(json_str)
                        logger.info(f"Successfully parsed JSON data: {list(parsed_data.keys())}")
                        
                        # Ensure we have all expected fields with proper types
                        if 'items' not in parsed_data:
                            parsed_data['items'] = []
                        
                        if not isinstance(parsed_data.get('total_amount'), (int, float)):
                            try:
                                parsed_data['total_amount'] = float(parsed_data.get('total_amount', '0').replace('$', '').strip())
                            except:
                                parsed_data['total_amount'] = 0.0
                        
                        # Add detected language
                        parsed_data['detected_language'] = 'en'
                        
                        return parsed_data
                    except json.JSONDecodeError as e:
                        logger.error(f"Failed to parse JSON from Ollama: {e}")
                        return None
                else:
                    logger.warning("No JSON found in Ollama response")
                    return None
                    
            else:
                logger.error("Invalid response format from Ollama")
                return None
        except Exception as e:
            logger.error(f"Error in Ollama API call: {str(e)}")
            return None
    except Exception as e:
        logger.error(f"Error processing with Ollama: {str(e)}")
        return None

def validate_ollama_result(result, original_text):
    """Validate that Ollama's result is not hallucinated"""
    logger.info("Validating Ollama result to prevent hallucination")
    
    # 1. Check if items are plausible based on the text - more lenient for noisy OCR
    if 'items' in result and result['items']:
        hallucinated_items = 0
        total_items = len(result['items'])
        
        for item in result['items']:
            # Check if item name appears in the original text (or close enough)
            item_name = item.get('name', '').lower()
            
            # Skip very generic item names that are likely hallucinated
            if item_name in ['item', 'product', 'food', 'drink', 'unknown item']:
                hallucinated_items += 1
                logger.warning(f"Potentially hallucinated generic item: {item_name}")
                continue
                
            # Special case for known OCR errors in common food items
            if "cheesecake" in item_name:
                # For cheesecake items, we're more lenient as we've instructed Ollama to correct common errors
                if any(flavor in original_text.lower() for flavor in ["mango", "hango", "straw", "blue", "choco"]):
                    logger.info(f"Found cheesecake item with valid flavor indicators: {item_name}")
                    continue
            
            # Be more lenient with noisy OCR - look for word parts
            item_words = item_name.split()
            words_found = 0
            
            # For each word in the item name, check if any word part (3+ chars) appears in the text
            for word in item_words:
                if len(word) > 2:  # Only check substantial words
                    # Look for this word or parts of this word in the original text
                    found = False
                    if word in original_text.lower():
                        found = True
                    else:
                        # Look for parts of the word (for OCR errors)
                        for i in range(len(word) - 2):
                            if word[i:i+3] in original_text.lower():
                                found = True
                                break
                    
                    if found:
                        words_found += 1
            
            # If less than 1/3 of the words in the item name are found, it's suspicious
            min_words_needed = max(1, len(item_words) / 3)
            if words_found < min_words_needed:
                hallucinated_items += 1
                logger.warning(f"Potentially hallucinated item: {item_name} - not found in text")
        
        # If most items appear hallucinated, reject the result
        # More lenient threshold of 75% (instead of 50%)
        if hallucinated_items / max(1, total_items) > 0.75:
            logger.warning(f"Rejecting Ollama result: {hallucinated_items}/{total_items} items appear hallucinated")
            return False
    
    # 2. Check for realistic total amount - be more lenient with noisy OCR
    if result.get('total_amount', 0) > 0:
        # Check if any price-like patterns exist in the text - include more patterns for noisy OCR
        price_patterns = [
            r'\$?\d+\.\d{2}', 
            r'\d+,\d{2}', 
            r'tot[a-z]*\D+\d+\.\d{2}',  # total followed by number with decimals
            r'\d+\.\d{2}\D+tot',  # number with decimals followed by total
            r'[\d\.]{3,7}'  # just number sequences that might be prices
        ]
        has_price_pattern = False
        
        for pattern in price_patterns:
            if re.search(pattern, original_text.lower()):
                has_price_pattern = True
                break
        
        # If we have a total but no price patterns in the text, it's suspicious
        if not has_price_pattern:
            logger.warning(f"Suspicious total amount: {result.get('total_amount')} - no price patterns in text")
            # Don't reject just on this basis alone, as OCR might have missed the prices
    
    # Accept the result if it passes the checks
    logger.info("Ollama result appears valid")
    return True

def fallback_regex_parsing(text, result=None):
    """Fallback regex parsing for when Ollama is not available or fails"""
    if result is None:
        result = {
            "merchant_name": "",
            "date": "",
            "items": [],
            "total_amount": 0.0,
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
                result["total_amount"] = total
                break
            except:
                continue
    
    # Extract items - this is a simplified approach
    # Look for patterns like "Item $XX.XX" or "X Item $XX.XX"
    item_patterns = [
        r'(\d+)\s+([A-Za-z0-9\s&\'.,-]{3,30})\s+(\d+\.\d{2})',  # Qty Item Price
        r'([A-Za-z0-9\s&\'.,-]{3,30})\s+(\d+)\s+(\d+\.\d{2})',  # Item Qty Price
        r'([A-Za-z0-9\s&\'.,-]{3,30})\s+(\d+\.\d{2})',          # Item Price
    ]
    
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
                                "quantity": int(match[0]),
                                "unit_price": float(match[2]),
                                "item_type": "unknown"
                            }
                        else:
                            # Item Qty Price format
                            item = {
                                "name": match[0].strip(),
                                "quantity": int(match[1]),
                                "unit_price": float(match[2]),
                                "item_type": "unknown"
                            }
                    elif len(match) == 2:  # Item Price
                        item = {
                            "name": match[0].strip(),
                            "quantity": 1,
                            "unit_price": float(match[1]),
                            "item_type": "unknown"
                        }
                    
                    # Skip items with generic or unlikely names
                    if re.match(r'(?:sub)?total|tax|tip|item|price|qty', item["name"].lower()):
                        continue
                        
                    result["items"].append(item)
                except:
                    continue
    
    return result

@app.post("/analyze-receipt")
async def analyze_receipt(request: ReceiptRequest):
    try:
        # Debug: Log received request details
        logger.info(f"Received request with text length: {len(request.text.strip()) if request.text else 0}")
        
        # Log the first part of the text for debugging
        if request.text:
            # Check for potentially problematic characters in the text
            problematic_chars = ['%', '{', '}', '\\', '$']
            contains_problematic = any(char in request.text for char in problematic_chars)
            if contains_problematic:
                logger.warning("Text contains potentially problematic characters for string formatting")
            
            # Clean the text of any control characters
            cleaned_text = ''.join(char for char in request.text if ord(char) >= 32 or char in '\n\r\t')
            if cleaned_text != request.text:
                logger.warning("Text contained control characters that were removed")
                request = ReceiptRequest(text=cleaned_text, ollama_config=request.ollama_config)
            
            sample_text = cleaned_text[:200] + "..." if len(cleaned_text) > 200 else cleaned_text
            logger.info(f"Sample text content: {sample_text}")
        else:
            logger.warning("Received empty text in request")
            
        # Check for custom model config
        model_config = request.ollama_config or {}
        global OLLAMA_MODEL
        
        if model_config.get("model") and OLLAMA_AVAILABLE:
            # Check if the requested model is available
            try:
                models = ollama.list().get('models', [])
                available_models = [m.get('model').split(':')[0] for m in models]
                requested_model = model_config.get("model")
                
                if requested_model in available_models:
                    OLLAMA_MODEL = requested_model
                    logger.info(f"Using custom model: {OLLAMA_MODEL}")
                else:
                    logger.warning(f"Requested model {requested_model} not available, using default: {OLLAMA_MODEL}")
            except Exception as e:
                logger.error(f"Error checking available models: {e}")
        
        # Ensure we have text to process
        if not request.text or len(request.text.strip()) == 0:
            logger.error("Required field 'text' is empty or missing")
            return JSONResponse(
                status_code=422,
                content={"success": False, "error": "Text is required for receipt analysis and cannot be empty"}
            )
        
        # Process with Ollama for intelligent reasoning if available
        result = None
        if OLLAMA_AVAILABLE:
            try:
                logger.info("Processing text with Ollama reasoning")
                ollama_result = process_with_ollama(request.text)
                
                if ollama_result and validate_ollama_result(ollama_result, request.text):
                    logger.info("Successfully processed with Ollama reasoning")
                    result = ollama_result
                else:
                    logger.warning("Ollama reasoning failed, falling back to regex parsing")
            except Exception as e:
                logger.error(f"Exception during Ollama processing: {str(e)}")
                logger.warning("Exception in Ollama processing, falling back to regex parsing")
        
        # Fallback to regex parsing if Ollama failed or is not available
        if result is None:
            logger.info("Using regex fallback parsing")
            result = fallback_regex_parsing(request.text)
        
        # Return the result with appropriate processing info
        return {
            "success": True, 
            "data": result, 
            "processing_info": {
                "model_used": OLLAMA_MODEL if result == ollama_result else "regex_fallback",
                "timestamp": datetime.now().isoformat()
            }
        }

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": f"Server error: {str(e)}"}
        )

@app.get("/")
async def read_root():
    return {
        "message": "Welcome to the Receipt Scanner API",
        "model": "Text Processing with Ollama Reasoning",
        "supported_languages": ["English"],
        "gpu_available": torch.cuda.is_available(),
        "gpu_name": torch.cuda.get_device_name(0) if torch.cuda.is_available() else None
    }

if __name__ == "__main__":
    import uvicorn
    logger.info(f"Starting application with ENV={ENV}, PORT={PORT}")
    logger.info(f"GPU Available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        logger.info(f"GPU Device: {torch.cuda.get_device_name(0)}")
    
    uvicorn.run(app, host="0.0.0.0", port=PORT)