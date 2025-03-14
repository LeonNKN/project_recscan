import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:recscan/pages/editable_combined_result_card_view.dart';
import 'package:recscan/widgets/overview/overview_transaction_card.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/models.dart';

class ScanPage extends StatefulWidget {
  final ImageSource? initialSource;

  const ScanPage({super.key, this.initialSource});

  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  final _textRecognizer = TextRecognizer();
  List<OrderItem> _orderItems = [];
  String _total = '';
  String _merchantName = '';
  String _date = '';
  bool _isProcessing = false;
  String? _error;
  String? _extractedText;

  @override
  void initState() {
    super.initState();
    if (widget.initialSource != null) {
      _pickImage(widget.initialSource!);
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<String?> _extractTextFromImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Clean up the text
      String cleanText = recognizedText.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .join('\n');

      return cleanText;
    } catch (e) {
      setState(() => _error = 'Error extracting text: $e');
      return null;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _orderItems = [];
        _total = '';
        _merchantName = '';
        _date = '';
        _error = null;
        _extractedText = null;
      });
      await _processReceipt();
    }
  }

  Future<void> _processReceipt() async {
    if (_image == null) return;

    setState(() => _isProcessing = true);

    try {
      // First extract text from image
      final extractedText = await _extractTextFromImage(_image!);
      if (extractedText == null || extractedText.isEmpty) {
        setState(() => _error = 'Could not extract text from image');
        return;
      }

      setState(() => _extractedText = extractedText);

      // Send extracted text to API
      final uri = Uri.parse(
          'https://ollama:ollama123456@5a08-161-142-237-109.ngrok-free.app/analyze-receipt');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': extractedText}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final data = jsonResponse['data'];
          final items = (data['items'] as List)
              .map((item) => OrderItem(
                    name: item['name'] as String,
                    quantity: item['quantity'] as int,
                    price: item['unit_price'] as double,
                  ))
              .toList();

          setState(() {
            _orderItems = items;
            _total = data['total_amount'].toString();
            _merchantName = data['merchant_name'] ?? 'Unknown Merchant';
            _date = data['date'] ?? DateTime.now().toString().split(' ')[0];
            _error = null;
          });
        } else {
          setState(() =>
              _error = jsonResponse['error'] ?? 'Failed to parse receipt');
        }
      } else {
        String errorMessage = 'Server error: ${response.statusCode}';
        if (response.statusCode == 403) {
          errorMessage =
              'Authentication failed: Please check the API credentials (403 Forbidden)';
        } else if (response.statusCode == 401) {
          errorMessage =
              'Unauthorized: Invalid authentication credentials (401)';
        }
        setState(() => _error = errorMessage);
      }
    } catch (e) {
      setState(() => _error = 'Error processing receipt: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing receipt: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Image Preview Section
            if (_image != null)
              Container(
                height: 200,
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_image!, fit: BoxFit.contain),
                ),
              ),

            // Camera and Gallery Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Loading Indicator
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Processing receipt...'),
                  ],
                ),
              ),

            // Error Message
            if (_error != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _processReceipt,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),

            // Receipt Details
            if (_orderItems.isNotEmpty)
              EditableCombinedResultCardView(
                orderItems: _orderItems,
                subtotal: _calculateSubtotal(),
                total: _total,
                onChanged: (updatedOrderItems, updatedSubtotal, updatedTotal) {
                  setState(() {
                    _orderItems = updatedOrderItems;
                    _total = updatedTotal;
                  });
                },
                onDone: (finalOrderItems, finalSubtotal, finalTotal,
                    selectedCategory) async {
                  final parsedDate = DateTime.tryParse(_date) ?? DateTime.now();
                  final subtotalValue = double.tryParse(finalSubtotal) ?? 0.0;
                  final totalValue = double.tryParse(finalTotal) ?? 0.0;

                  RestaurantCardModel exportedResult = RestaurantCardModel(
                    id: DateTime.now().millisecondsSinceEpoch,
                    restaurantName: _merchantName,
                    dateTime: parsedDate,
                    subtotal: subtotalValue,
                    total: totalValue,
                    category: selectedCategory,
                    categoryColor: Colors.blue.shade100,
                    iconColor: Colors.blue,
                    items: finalOrderItems,
                  );

                  debugPrint(
                      'Exporting result: ${exportedResult.restaurantName}, ${exportedResult.total}');

                  // Pop with the result
                  if (mounted) {
                    Navigator.pop(context, exportedResult);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  String _calculateSubtotal() {
    double subtotal = _orderItems.fold(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );
    return subtotal.toStringAsFixed(2);
  }
}

class ReceiptParseResult {
  final List<OrderItem> items;
  final double subtotal;
  final double total;

  ReceiptParseResult({
    required this.items,
    required this.subtotal,
    required this.total,
  });
}
