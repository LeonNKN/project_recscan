import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:recscan/pages/editable_combined_result_card_view.dart';
import 'package:recscan/widgets/overview/overview_transaction_card.dart';
import '../models/models.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:recscan/config/api_config.dart';

class ScanPage extends StatefulWidget {
  final ImageSource? initialSource;

  const ScanPage({super.key, this.initialSource});

  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // Essential properties
  File? _image;
  final ImagePicker _picker = ImagePicker();
  late TextRecognizer _textRecognizer;
  List<OrderItem> _orderItems = [];
  String _total = '';
  String _merchantName = '';
  String _date = '';
  bool _isProcessing = false;
  double _progress = 0.0;
  String? _error;
  String _subtotal = '';
  String _discountInfo = '';
  String _taxInfo = '';
  String _serviceChargeInfo = '';

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    if (widget.initialSource != null) {
      _pickImage(widget.initialSource!);
    }
  }

  // Simple image picker
  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1800,
      imageQuality: 90,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _orderItems = [];
        _total = '';
        _merchantName = '';
        _date = '';
        _error = null;
        _progress = 0.0;
      });
      await _processReceipt();
    }
  }

  // Streamlined receipt processing
  Future<void> _processReceipt() async {
    setState(() {
      _isProcessing = true;
      _progress = 0.1;
    });

    try {
      // Basic OCR
      final inputImage = InputImage.fromFilePath(_image!.path);
      setState(() => _progress = 0.3);

      // Recognize text
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      final String text = recognizedText.text;
      setState(() => _progress = 0.5);

      // Send to API
      final result = await _sendToReceiptAPI(text);

      setState(() {
        if (result != null) {
          // Process successful API result
          _merchantName = result['data']['merchant_name'] ?? '';
          _date = result['data']['date'] ?? '';
          _total = result['data']['total_amount'].toString();

          debugPrint(
              'API returned data with ${(result['data']['items'] as List<dynamic>).length} items');

          // Process items
          _orderItems = (result['data']['items'] as List<dynamic>)
              .map((item) => OrderItem(
                    name: item['name']?.toString() ?? 'Receipt Item',
                    price: double.tryParse(
                            item['unit_price']?.toString() ?? '0') ??
                        0.0,
                    quantity:
                        int.tryParse(item['quantity']?.toString() ?? '1') ?? 1,
                  ))
              .toList();

          // Fix items with numeric names
          for (int i = 0; i < _orderItems.length; i++) {
            if (RegExp(r'^\d+$').hasMatch(_orderItems[i].name)) {
              _orderItems[i] = OrderItem(
                name: 'Item ${i + 1}',
                price: _orderItems[i].price,
                quantity: _orderItems[i].quantity,
              );
            }
          }

          // If no items, create a default item
          if (_orderItems.isEmpty) {
            double total = double.tryParse(_total) ?? 0.0;
            _orderItems = [
              OrderItem(
                name: _merchantName.isNotEmpty
                    ? 'Item from $_merchantName'
                    : 'Receipt Item',
                price: total,
                quantity: 1,
              )
            ];
          }
        } else {
          _error = 'Failed to analyze receipt. Please try again.';
        }
        _isProcessing = false;
        _progress = 1.0;
      });
    } catch (e) {
      setState(() {
        _error = 'Error processing image: $e';
        _isProcessing = false;
        _progress = 0.0;
      });
    }
  }

  // API communication
  Future<Map<String, dynamic>?> _sendToReceiptAPI(String text) async {
    try {
      final apiUrl = ApiConfig.analyzeReceipt;

      // Prepare image data if available
      String? base64Image;
      if (_image != null) {
        final imageBytes = await _image!.readAsBytes();
        base64Image = base64Encode(imageBytes);
      }

      // Create request payload
      final Map<String, dynamic> payload = {
        'text': text,
        'ollama_config': {
          'model': 'llava:latest',
          'temperature': 0.1,
        }
      };

      if (base64Image != null) {
        payload['image'] = base64Image;
      }

      // Send request
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: ApiConfig.headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception sending to API: $e');
      return null;
    }
  }

  // Simplified UI
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
            // Image Preview
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_image!, fit: BoxFit.contain),
                    ),
                    if (_isProcessing)
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                value: _progress > 0 ? _progress : null,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Analyzing receipt...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
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
                subtotal: _subtotal,
                total: _total,
                discountInfo: _discountInfo,
                taxInfo: _taxInfo,
                serviceChargeInfo: _serviceChargeInfo,
                onChanged: (updatedOrderItems, updatedSubtotal, updatedTotal) {
                  setState(() {
                    _orderItems = updatedOrderItems;
                    _total = updatedTotal;
                    _subtotal = updatedSubtotal;
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
}
