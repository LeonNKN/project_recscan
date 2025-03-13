FROM ubuntu:22.04

# Install necessary dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    unzip \
    libgconf-2-4 \
    gdb \
    libstdc++6 \
    libglu1-mesa \
    fonts-droid-fallback \
    lib32stdc++6 \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter channel stable
RUN flutter upgrade
RUN flutter config --enable-web --no-analytics
RUN flutter doctor

# Set the working directory
WORKDIR /app

# Copy the project files
COPY . .

# Build the web app
RUN flutter build web

# Install and use serve to host the web app
RUN apt-get update && apt-get install -y nodejs npm
RUN npm install -g serve

# Set environment variable
ENV ENV=production

# Expose the port
EXPOSE 8080

# Start the server
CMD ["serve", "-s", "build/web", "-l", "8080"] 