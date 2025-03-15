import ollama
import logging
import httpx
import os

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def test_ollama_connection(host):
    logger.info(f"Testing Ollama connection to: {host}")
    try:
        ollama.host = host
        headers = {
            "ngrok-skip-browser-warning": "true"  # Only needed for ngrok
        }
        # Create a new client with the headers
        ollama._client = httpx.Client(headers=headers)
        response = ollama.list()
        logger.info(f"Successfully connected to {host}")
        logger.info(f"Available models: {response}")
        return True
    except httpx.ConnectError as e:
        logger.error(f"Connection error to {host}: {str(e)}")
        return False
    except Exception as e:
        logger.error(f"Failed to connect to {host}: {str(e)}")
        return False

if __name__ == "__main__":
    # Test local connection
    logger.info("=== Testing Local Ollama ===")
    local_success = test_ollama_connection("http://localhost:11434")
    
    # Test remote connection
    logger.info("\n=== Testing Remote Ollama ===")
    remote_host = os.getenv("NGROK_URL", "https://fcca-161-142-237-109.ngrok-free.app")  # Update with current URL
    remote_success = test_ollama_connection(remote_host)
    
    # Summary
    if local_success:
        logger.info("✅ Local Ollama is running correctly")
    else:
        logger.error("❌ Local Ollama is not accessible")
        
    if remote_success:
        logger.info("✅ Remote Ollama (ngrok) is accessible")
    else:
        logger.error("❌ Remote Ollama (ngrok) is not accessible")