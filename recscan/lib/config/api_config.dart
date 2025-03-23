class ApiConfig {
  // Base URL for the API - Replace this with your ngrok URL
  // Note: When you start detect_api.py, it will print a public URL to use here
  static const String baseUrl = 'https://a29e-161-142-237-109.ngrok-free.app';

  // API endpoints
  static String get analyzeReceipt => '$baseUrl/analyze-receipt';
  static String get healthCheck => '$baseUrl/check';
  static String get ollamaStatus => '$baseUrl/ollama-status';

  // Simplified headers
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': '*/*',
      };
}
