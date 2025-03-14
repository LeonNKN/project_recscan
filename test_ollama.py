import ollama
import logging
import httpx

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def test_ollama_connection(host):
    logger.info(f"Testing Ollama connection to: {host}")
    try:
        ollama.host = host
        headers = {
            "Authorization": "Bearer 2uGmHMJkSI3ppiWBn11Qxg7FFEf_4Ek5GxPVVPNuAfq3f12W1",
            "ngrok-skip-browser-warning": "true"
        }
        # Create a new client with the headers
        ollama._client = httpx.Client(headers=headers)
        response = ollama.list()
        logger.info(f"Successfully connected to {host}")
        logger.info(f"Available models: {response}")
        return True
    except Exception as e:
        logger.error(f"Failed to connect to {host}: {str(e)}")
        return False

if __name__ == "__main__":
    # Test local connection
    logger.info("=== Testing Local Ollama ===")
    local_success = test_ollama_connection("http://localhost:11434")
    
    # Test remote connection
    logger.info("\n=== Testing Remote Ollama ===")
    remote_success = test_ollama_connection("https://5a08-161-142-237-109.ngrok-free.app")
    
    if local_success:
        logger.info("✅ Local Ollama is running correctly")
    else:
        logger.error("❌ Local Ollama is not accessible")
        
    if remote_success:
        logger.info("✅ Remote Ollama (ngrok) is accessible")
    else:
        logger.error("❌ Remote Ollama (ngrok) is not accessible") 