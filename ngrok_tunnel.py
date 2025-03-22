import ngrok
import os
from dotenv import load_dotenv
import time

# Load environment variables
load_dotenv()

# Get ngrok auth token from environment or input
auth_token = os.getenv('NGROK_AUTH_TOKEN', '')
if not auth_token:
    auth_token = input("Please enter your ngrok auth token: ")
    
# Connect to ngrok
print("Connecting to ngrok...")
print("This will expose your DeepSeek-VL2 receipt analysis API to the internet")
try:
    listener = ngrok.connect(8000, authtoken=auth_token)
    print(f"\nAPI is now available at: {listener.url()}/analyze-receipt")
    print("Use this URL in your Flutter app's _sendToReceiptAPI method")
    print("Make sure you have set a valid DEEPSEEK_API_KEY in your .env file")
    print("\nPress Ctrl+C to stop the tunnel")
    
    # Keep the tunnel open
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("Disconnecting ngrok tunnel...")
    ngrok.disconnect()
    print("Tunnel closed.")
except Exception as e:
    print(f"Error: {e}")
    print("If you see an auth error, make sure you have a valid ngrok auth token.")
    print("You can get one by signing up at https://ngrok.com/ (free tier available)") 