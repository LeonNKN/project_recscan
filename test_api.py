import requests
import json

# API endpoint
url = "https://project-recscan-2dwj.onrender.com/analyze-receipt"

# Sample receipt text
receipt_text = """RESTAURANT ABC
123 Main Street
Date: 2024-03-14

1x Chicken Rice $8.50
2x Ice Tea $2.50

Total: $13.50"""

# Prepare the request
headers = {
    "Content-Type": "application/json"
}
data = {
    "text": receipt_text
}

# Make the request
try:
    response = requests.post(url, headers=headers, json=data)
    print("\nStatus Code:", response.status_code)
    print("\nResponse:")
    print(json.dumps(response.json(), indent=2))
except Exception as e:
    print("Error:", str(e)) 