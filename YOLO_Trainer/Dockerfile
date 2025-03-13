FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first to leverage Docker cache
COPY YOLO_Trainer/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application files
COPY YOLO_Trainer/ .

# Expose the port
EXPOSE 8000

# Set environment variables
ENV ENV=production
ENV API_TIMEOUT=30
ENV ENABLE_CACHE=true

# Start the application with optimized settings
CMD ["uvicorn", "detect_api:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--timeout-keep-alive", "75"] 