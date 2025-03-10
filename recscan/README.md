# RecScan - Receipt Scanning Application

A Flutter application that allows users to scan receipts and extract structured data using OCR and AI analysis.

## Prerequisites

Before running the application, make sure you have the following installed:

1. Flutter SDK (version >=3.0.0)
2. Python 3.8 or higher
3. Ollama (for AI processing)
4. Git

## Setup Instructions

### 1. Start the API Server

First, you need to start the API server that handles receipt analysis:

1. Navigate to the YOLO_Trainer directory:
   ```bash
   cd YOLO_Trainer
   ```

2. Install the required Python packages:
   ```bash
   pip install fastapi uvicorn ollama
   ```

3. Start the API server:
   ```bash
   uvicorn detect_api:app --host 0.0.0.0 --port 8000
   ```

The server will start running on `http://localhost:8000`

### 2. Run the Flutter Application

1. Navigate to the Flutter project directory:
   ```bash
   cd recscan
   ```

2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   flutter run
   ```

## Important Notes

### Network Requirements
- The Flutter app and API server must be on the same network
- If running on a physical device, make sure your device is connected to the same WiFi network as your computer
- The API server must be accessible from your device (check firewall settings if needed)

### API Configuration
- The default API endpoint is set to `http://localhost:8000`
- If you're running the server on a different machine, update the API URL in the Flutter app's configuration

### Device Permissions
- Camera permission is required for scanning receipts
- Storage permission is needed for saving scanned images
- Make sure to grant these permissions when prompted

### GPU Acceleration
- The application uses GPU acceleration for better performance
- Ensure your device has a compatible GPU and updated drivers
- For Windows users, make sure NVIDIA drivers are up to date

## Troubleshooting

### Common Issues

1. **API Connection Issues**
   - Verify both devices are on the same network
   - Check if the API server is running
   - Ensure no firewall is blocking the connection

2. **Camera Not Working**
   - Check camera permissions
   - Ensure no other app is using the camera
   - Try restarting the app

3. **Slow Processing**
   - Check your internet connection
   - Verify GPU acceleration is enabled
   - Close other resource-intensive applications

### Getting Help

If you encounter any issues:
1. Check the console logs for error messages
2. Ensure all prerequisites are properly installed
3. Verify network connectivity between devices
4. Check if the API server is running and accessible

## Features

- Receipt scanning using device camera
- OCR text extraction
- AI-powered receipt analysis
- Category-based organization
- Transaction history
- Search functionality
- Export capabilities

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
