from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import logging
import ollama
import json
from pydantic import BaseModel
from functools import lru_cache

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ReceiptRequest(BaseModel):
    text: str

# Cache the model responses for similar receipts
@lru_cache(maxsize=100)
def analyze_receipt_text(text: str):
    try:
        response = ollama.chat(
            model='mistral',  # Using a smaller, faster model
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
            options={
                'num_gpu': 1,
                'num_thread': 8,
                'temperature': 0.1,
                'top_p': 0.9,
                'repeat_penalty': 1.1
            }
        )
        return response
    except Exception as e:
        logger.error(f"Model error: {str(e)}")
        raise

@app.post("/analyze-receipt")
async def analyze_receipt(request: ReceiptRequest):
    try:
        receipt_text = request.text.strip()
        logger.info(f"Received text to analyze: {receipt_text[:100]}...")  # Log first 100 chars
        
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