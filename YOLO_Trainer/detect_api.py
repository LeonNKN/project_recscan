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
from transformers import AutoModelForTokenClassification, AutoTokenizer, LayoutLMv2Processor, LayoutLMv2ForTokenClassification
import pytesseract
from PIL import Image
import io
import base64
import langdetect
from langdetect import detect
import sys

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

# Configure Tesseract
if sys.platform == 'win32':
    # Windows: Set Tesseract path
    tesseract_path = os.getenv('TESSERACT_PATH', r'C:\Program Files\Tesseract-OCR\tesseract.exe')
    if os.path.exists(tesseract_path):
        pytesseract.pytesseract.tesseract_cmd = tesseract_path
        logger.info(f"Using Tesseract from: {tesseract_path}")
    else:
        logger.warning(f"Tesseract not found at {tesseract_path}. Please install Tesseract and set TESSERACT_PATH.")

# Test Tesseract installation
try:
    available_langs = pytesseract.get_languages()
    logger.info(f"Available Tesseract languages: {available_langs}")
    if not all(lang in available_langs for lang in ['eng', 'jpn', 'kor']):
        logger.warning("Some required languages (eng, jpn, kor) are missing. Please install them.")
except Exception as e:
    logger.error(f"Error checking Tesseract languages: {e}")

# Configure Tesseract for multiple languages
TESSERACT_CONFIG = r'--oem 3 --psm 6 -l eng+jpn+kor'

# Initialize LayoutLM model - using LayoutLMv2 for better multilingual support
logger.info("Loading LayoutLMv2 model...")
model_name = "microsoft/layoutlmv2-base-uncased"  # Base multilingual model
processor = LayoutLMv2Processor.from_pretrained(model_name)
model = LayoutLMv2ForTokenClassification.from_pretrained(model_name)

# Move model to GPU if available
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
model = model.to(device)
model.eval()  # Set to evaluation mode

# Configure FastAPI
app = FastAPI(
    title="Receipt Scanner API",
    description="API for analyzing multilingual receipts using LayoutLMv2",
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
    text: str
    image: str = None  # Base64 encoded image (optional)

def detect_language(text: str) -> str:
    try:
        return detect(text)
    except:
        return 'en'  # Default to English if detection fails

def process_receipt_with_layoutlm(text: str, image_data: str = None):
    try:
        # Detect language
        detected_lang = detect_language(text)
        logger.info(f"Detected language: {detected_lang}")

        # If image is provided, perform OCR with language-specific settings
        if image_data:
            try:
                # Decode base64 image
                image_bytes = base64.b64decode(image_data)
                image = Image.open(io.BytesIO(image_bytes))
                
                # Perform OCR with language support
                ocr_result = pytesseract.image_to_data(
                    image, 
                    output_type=pytesseract.Output.DICT,
                    config=TESSERACT_CONFIG
                )
                words = ocr_result["text"]
                boxes = [[ocr_result["left"][i], ocr_result["top"][i],
                         ocr_result["left"][i] + ocr_result["width"][i],
                         ocr_result["top"][i] + ocr_result["height"][i]]
                        for i in range(len(words))]
                
                # Combine OCR text
                text = " ".join(words)
            except Exception as e:
                logger.error(f"OCR processing failed: {str(e)}")
                # Fall back to text-only processing
                pass

        # Prepare input for LayoutLMv2
        encoded_inputs = processor(
            image,
            text,
            return_tensors="pt",
            truncation=True,
            padding=True,
        ).to(device)

        # Process with model
        with torch.no_grad():
            outputs = model(**encoded_inputs)
            predictions = outputs.logits.argmax(dim=-1)

        # Extract structured data
        tokens = processor.tokenizer.convert_ids_to_tokens(encoded_inputs["input_ids"][0])
        pred_labels = [model.config.id2label[p.item()] for p in predictions[0]]

        # Process predictions into structured data
        result = {
            "merchant_name": "",
            "date": "",
            "items": [],
            "total_amount": 0.0,
            "detected_language": detected_lang
        }

        current_item = None
        for token, label in zip(tokens, pred_labels):
            if label == "COMPANY":
                result["merchant_name"] += token.replace("#", "")
            elif label == "DATE":
                result["date"] += token.replace("#", "")
            elif label == "TOTAL":
                try:
                    # Handle different currency formats
                    amount_str = token.replace("#", "").replace("$", "").replace("¥", "").replace("₩", "")
                    amount = float(amount_str)
                    result["total_amount"] = amount
                except ValueError:
                    pass
            elif label == "ITEM":
                if current_item is None:
                    current_item = {"name": "", "quantity": 1, "unit_price": 0.0, "total_price": 0.0}
                current_item["name"] += token.replace("#", "")
            elif label == "PRICE" and current_item:
                try:
                    price_str = token.replace("#", "").replace("$", "").replace("¥", "").replace("₩", "")
                    price = float(price_str)
                    current_item["unit_price"] = price
                    current_item["total_price"] = price * current_item["quantity"]
                    result["items"].append(current_item)
                    current_item = None
                except ValueError:
                    pass

        return {"success": True, "data": result}

    except Exception as e:
        logger.error(f"LayoutLM processing error: {str(e)}")
        raise

@app.post("/analyze-receipt")
async def analyze_receipt(request: ReceiptRequest):
    try:
        if not request.text.strip() and not request.image:
            return JSONResponse(
                status_code=422,
                content={"success": False, "error": "No text or image provided to analyze"}
            )

        result = process_receipt_with_layoutlm(request.text.strip(), request.image)
        return JSONResponse(content=result)

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": f"Server error: {str(e)}"}
        )

@app.get("/")
async def read_root():
    return {
        "message": "Welcome to the Receipt Scanner API",
        "model": "LayoutLMv2",
        "supported_languages": ["English", "Japanese", "Korean"],
        "gpu_available": torch.cuda.is_available(),
        "gpu_name": torch.cuda.get_device_name(0) if torch.cuda.is_available() else None
    }

if __name__ == "__main__":
    import uvicorn
    logger.info(f"Starting application with ENV={ENV}, PORT={PORT}")
    logger.info(f"GPU Available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        logger.info(f"GPU Device: {torch.cuda.get_device_name(0)}")
    config = uvicorn.Config(
        app,
        host="0.0.0.0",
        port=PORT,
        timeout_keep_alive=30,
        limit_concurrency=100,
        backlog=100
    )
    server = uvicorn.Server(config)
    server.run()