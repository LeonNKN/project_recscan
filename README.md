# Receipt Scanner with DeepSeek-VL2 Integration

A Flutter-based mobile application for scanning and analyzing receipts using the DeepSeek-VL2 multimodal model.

## System Requirements

For processing receipts with DeepSeek-VL2:
- Minimum of 16GB RAM
- For local execution: NVIDIA GPU with at least 16GB VRAM
- Alternatively: Use the DeepSeek API (recommended approach, no GPU required)

## Project Structure

This project consists of two main components:
1. **Flutter App** - Mobile application for capturing receipt images
2. **API Server** - Backend for processing receipts with DeepSeek-VL2

## Setup

### API Server Setup
1. Navigate to the API server directory:
```
cd YOLO_Trainer
```

2. Install required Python packages:
```
pip install fastapi uvicorn pydantic python-dotenv psutil torch requests ngrok
```

3. Create a `.env` file with your DeepSeek API key:
```
# DeepSeek API Configuration
DEEPSEEK_API_KEY=your_deepseek_api_key_here
DEEPSEEK_API_URL=https://api.deepseek.com/v1/chat/completions
DEEPSEEK_MODEL=deepseek-vl2

# Ngrok Configuration (for exposing API to the internet)
NGROK_AUTHTOKEN=your_ngrok_authtoken_here

# API Settings
PORT=8000
API_TIMEOUT=60.0
ENV=production
```

4. Start the API server:
```
python detect_api.py
```

### Flutter App Setup
1. Navigate to the Flutter app directory:
```
cd recscan
```

2. Install Flutter dependencies:
```
flutter pub get
```

3. Update the API URL in `lib/config/api_config.dart` with the ngrok URL printed when running the API server.

4. Run the Flutter app:
```
flutter run
```

## How It Works

1. **Image Capture**: The app captures receipt images through the device camera or gallery.
2. **Text Extraction**: Google ML Kit extracts text from the receipt image.
3. **API Processing**: The extracted text and image are sent to the DeepSeek-VL2 model via the API.
4. **Result Display**: Structured data (merchant, date, items, total) is displayed and can be edited.

## Getting DeepSeek API Key

1. Visit the [DeepSeek website](https://www.deepseek.com/) and create an account.
2. Navigate to the API section and generate a new API key.
3. Add this key to your `.env` file as `DEEPSEEK_API_KEY`.

## Customization

- Modify the DeepSeek model by changing `DEEPSEEK_MODEL` in the `.env` file.
- Adjust the system prompt in `detect_api.py` to customize extraction behavior.

## Troubleshooting

- **API Connection Issues**: Ensure your ngrok authtoken is valid and added to the `.env` file.
- **GPU Memory Errors**: If you see GPU memory errors, the DeepSeek-VL2 model is too large for your GPU. Use the DeepSeek API instead.
- **Flutter Build Issues**: Run `flutter clean` followed by `flutter pub get` to resolve package issues.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

-----------------------------

How To Start Train Model
1) python -m venv flutter_env
    - Creating Virtual ENV with the name "flutter_env"
2) cd YOLO_Trainer
3) pip install -r requirements.txt
4) DONE


----------------------
Model Training
1. Dataset Preparation
- Download the Data Package before training Model. 
[LINK_HERE](https://universe.roboflow.com/mahb-test/mahb-receipt)

---------------------