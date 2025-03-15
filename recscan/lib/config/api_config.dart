class ApiConfig {
  // Base URL for the API
  static const String baseUrl = 'https://7d36-161-142-237-109.ngrok-free.app';

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
