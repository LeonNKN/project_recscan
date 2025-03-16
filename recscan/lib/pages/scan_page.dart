import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math' show min;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:recscan/pages/editable_combined_result_card_view.dart';
import 'package:recscan/widgets/overview/overview_transaction_card.dart';
import '../models/models.dart';
import '../config/api_config.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

class ScanPage extends StatefulWidget {
  final ImageSource? initialSource;

  const ScanPage({super.key, this.initialSource});

  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  late TextRecognizer _textRecognizer;
  List<OrderItem> _orderItems = [];
  String _total = '';
  String _merchantName = '';
  String _date = '';
  bool _isProcessing = false;
  bool _isOcrRunning = false;
  double _progress = 0.0;
  String? _error;
  String _detectedLanguage = '';
  String _extractedText = '';
  List<Directory> _tempDirs = [];

  @override
  void dispose() {
    _textRecognizer.close();
    // Clean up temporary directories
    _cleanupTempDirs();
    super.dispose();
  }

  // Clean up temporary directories
  Future<void> _cleanupTempDirs() async {
    for (var dir in _tempDirs) {
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          debugPrint('Cleaned up temp directory: ${dir.path}');
        }
      } catch (e) {
        debugPrint('Error cleaning up directory: $e');
      }
    }
    _tempDirs = [];
  }

  @override
  void initState() {
    super.initState();
    // Initialize text recognizer in init
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    // Try to initialize the text recognizer more explicitly
    _initializeTextRecognizer();
    if (widget.initialSource != null) {
      _pickImage(widget.initialSource!);
    }
  }

  // Initialize the text recognizer with better defaults
  Future<void> _initializeTextRecognizer() async {
    try {
      // Close any existing recognizer to prevent memory leaks
      try {
        _textRecognizer.close();
      } catch (e) {
        // Ignore if not initialized
      }
      // Re-initialize with explicit script
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      debugPrint('Text recognizer initialized successfully');
    } catch (e) {
      debugPrint('Error initializing text recognizer: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    // Set options to get smaller images from the start
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1200, // Limit width to reduce memory usage
      maxHeight: 1800, // Limit height to reduce memory usage
      imageQuality: 90, // Slightly compress the image
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _orderItems = [];
        _total = '';
        _merchantName = '';
        _date = '';
        _error = null;
        _extractedText = '';
        _progress = 0.0;
      });
      await _processReceipt();
    }
  }

  // Improved preprocessing with multiple strategies for better OCR results
  Future<List<File>> _preprocessImage(File imageFile) async {
    setState(() {
      _progress = 0.1;
    });

    try {
      // Read the image - use compute to move to a background thread
      final List<int> imageBytes = await imageFile.readAsBytes();

      // Create a temp directory for processing
      final tempDir = await Directory.systemTemp.createTemp('receipt_ocr');
      _tempDirs.add(tempDir); // Track for cleanup later

      setState(() {
        _progress = 0.2;
      });

      // Decode the image - move to background thread
      final img.Image? originalImage = await compute(
          (Uint8List bytes) => img.decodeImage(bytes),
          Uint8List.fromList(imageBytes));

      if (originalImage == null) {
        debugPrint('Failed to decode original image');
        // Return original as the only variant
        final File originalCopy = File('${tempDir.path}/original.jpg');
        await originalCopy.writeAsBytes(imageBytes);
        return [originalCopy];
      }

      debugPrint(
          'Original image dimensions: ${originalImage.width}x${originalImage.height}');
      setState(() {
        _progress = 0.3;
      });

      // First add the original image as a fallback option
      List<File> processedFiles = [];
      final File originalCopy = File('${tempDir.path}/original.jpg');
      await originalCopy.writeAsBytes(imageBytes);
      processedFiles.add(originalCopy);

      // Check if we need to resize for better OCR (ML Kit works better with certain resolutions)
      img.Image resizedImage = originalImage;
      if (originalImage.width > 1200 || originalImage.height > 1800) {
        // Resize while maintaining aspect ratio
        double aspectRatio = originalImage.width / originalImage.height;
        int newWidth = 1200;
        int newHeight = (newWidth / aspectRatio).round();

        if (newHeight > 1800) {
          newHeight = 1800;
          newWidth = (newHeight * aspectRatio).round();
        }

        resizedImage = await compute(
            (img.Image image) => img.copyResize(
                  image,
                  width: newWidth,
                  height: newHeight,
                  interpolation: img.Interpolation.linear,
                ),
            originalImage);
        debugPrint(
            'Resized image to: ${resizedImage.width}x${resizedImage.height}');
      }

      setState(() {
        _progress = 0.4;
      });

      // Check if we need to rotate to portrait (OCR works better on portrait receipts)
      img.Image orientedImage = resizedImage;
      if (resizedImage.width > resizedImage.height) {
        debugPrint('Rotating image to portrait orientation');
        orientedImage = await compute(
            (img.Image image) => img.copyRotate(image, angle: 90),
            resizedImage);
      }

      // Create multiple processed versions with different settings to maximize OCR success chance
      List<img.Image> processedVariants = [];

      // Variant 1: Pure grayscale (no other modifications)
      processedVariants.add(await compute(
          (img.Image image) => img.grayscale(image), orientedImage));

      // Variant 2: Grayscale + moderate contrast enhancement (most reliable)
      processedVariants.add(await compute((img.Image image) {
        final img.Image gray = img.grayscale(image);
        return img.adjustColor(
          gray,
          contrast: 1.5, // Moderate contrast
          brightness: 0.05,
          exposure: 0.1,
        );
      }, orientedImage));

      // Variant 3: Higher contrast for receipts with faded text
      processedVariants.add(await compute((img.Image image) {
        final img.Image gray = img.grayscale(image);
        return img.adjustColor(
          gray,
          contrast: 2.0, // Higher contrast
          brightness: 0.1,
          exposure: 0.2,
        );
      }, orientedImage));

      // Variant 4: Binarization/threshold approach for old-style receipts
      processedVariants.add(await compute((img.Image image) {
        // Convert to grayscale first
        final img.Image gray = img.grayscale(image);
        // Apply extreme contrast for a thresholding effect
        return img.adjustColor(
          gray,
          contrast: 5.0, // Very high contrast creates a near-binary effect
          brightness: 0.0,
          exposure: 0.0,
        );
      }, orientedImage));

      setState(() {
        _progress = 0.5;
      });

      // Save all processed variants for OCR
      for (int i = 0; i < processedVariants.length; i++) {
        final File variantFile =
            File('${tempDir.path}/processed_receipt_v${i + 1}.jpg');
        await variantFile.writeAsBytes(await compute(
            (img.Image image) =>
                Uint8List.fromList(img.encodeJpg(image, quality: 95)),
            processedVariants[i]));
        processedFiles.add(variantFile);
      }

      debugPrint(
          'Created ${processedFiles.length} optimized image variants for OCR');

      return processedFiles;
    } catch (e) {
      debugPrint('Image preprocessing error: $e');
      return [imageFile]; // Return original if processing fails
    }
  }

  // Enhanced preprocessing with a last resort approach for difficult images
  Future<List<File>> _createLastResortImages(File imageFile) async {
    debugPrint('Creating last resort images for OCR');

    try {
      final List<int> imageBytes = await imageFile.readAsBytes();
      final tempDir =
          await Directory.systemTemp.createTemp('receipt_ocr_last_resort');
      _tempDirs.add(tempDir);

      // First, add the original image as a fallback
      final List<File> resultFiles = [];
      final File originalCopy =
          File('${tempDir.path}/last_resort_original.jpg');
      await originalCopy.writeAsBytes(imageBytes);
      resultFiles.add(originalCopy);

      // Try to decode the image
      final img.Image? originalImage = await compute(
          (Uint8List bytes) => img.decodeImage(bytes),
          Uint8List.fromList(imageBytes));

      if (originalImage == null) {
        return resultFiles;
      }

      // Create extreme variants with very different processing techniques

      // 1. Very high contrast
      final img.Image highContrast = await compute((img.Image image) {
        return img.adjustColor(
          image,
          contrast: 3.0,
          brightness: 0.2,
          saturation: 0.0, // Remove color
          exposure: 0.3,
        );
      }, originalImage);

      final File highContrastFile =
          File('${tempDir.path}/last_resort_high_contrast.jpg');
      await highContrastFile.writeAsBytes(await compute(
          (img.Image image) =>
              Uint8List.fromList(img.encodeJpg(image, quality: 100)),
          highContrast));
      resultFiles.add(highContrastFile);

      // 2. Inverted colors (negative)
      final img.Image inverted = await compute((img.Image image) {
        return img.invert(image);
      }, originalImage);

      final File invertedFile =
          File('${tempDir.path}/last_resort_inverted.jpg');
      await invertedFile.writeAsBytes(await compute(
          (img.Image image) =>
              Uint8List.fromList(img.encodeJpg(image, quality: 100)),
          inverted));
      resultFiles.add(invertedFile);

      debugPrint('Created ${resultFiles.length} last resort image variants');
      return resultFiles;
    } catch (e) {
      debugPrint('Error creating last resort images: $e');
      return [imageFile];
    }
  }

  // Improved OCR function that tries multiple image variants if needed
  Future<String> _performOCR(List<File> imageFiles) async {
    setState(() {
      _isOcrRunning = true;
      _progress = 0.6;
    });

    try {
      String bestText = '';
      int bestScore = 0;

      // Try OCR on each variant until we get good results
      for (int i = 0; i < imageFiles.length; i++) {
        final File variantFile = imageFiles[i];
        debugPrint(
            'Attempting OCR on variant ${i}/${imageFiles.length - 1}: ${variantFile.path}');

        // For debugging only
        final img.Image? debugImage = await compute(
            (Uint8List bytes) => img.decodeImage(bytes),
            await variantFile.readAsBytes());

        if (debugImage != null) {
          debugPrint(
              'Processing image variant ${i}: ${debugImage.width}x${debugImage.height} pixels');
        }

        // Update progress based on which variant we're processing
        setState(() {
          _progress = 0.6 + (0.3 * (i / imageFiles.length));
        });

        try {
          // Run OCR on this variant - use try/catch for each variant
          final InputImage input = InputImage.fromFile(variantFile);
          final RecognizedText? recognizedText =
              await _textRecognizer.processImage(input);

          if (recognizedText != null && recognizedText.text.trim().isNotEmpty) {
            // Score this OCR result based on:
            // - Number of blocks and lines (more is usually better for receipts)
            // - Presence of key receipt words like "total", "subtotal", etc.
            // - Length of text
            final String text = recognizedText.text;

            // Simple scoring based on length and key terms
            int score = text.length;
            score += recognizedText.blocks.length * 10;

            final List<String> keyTerms = [
              'total',
              'subtotal',
              'tax',
              'cash',
              'change',
              'item',
              'price',
              'qty',
              'quantity',
              'amount',
              'payment',
              'receipt',
              'card',
              'date',
              'time',
              'thank',
              'purchase'
            ];

            for (final term in keyTerms) {
              if (text.toLowerCase().contains(term)) {
                score += 20;
              }
            }

            debugPrint(
                'Variant ${i} extracted ${text.length} chars with score: $score');

            // Keep track of best result
            if (score > bestScore) {
              bestScore = score;
              bestText = text;
              // If we found a good result, we can stop
              if (score > 100) {
                debugPrint('Found good OCR result, stopping search');
                break;
              }
            }
          } else {
            debugPrint('Variant ${i} returned no text');
          }
        } catch (variantError) {
          // Just log the error and continue with the next variant
          debugPrint('Error processing variant ${i}: $variantError');
        }
      }

      // If all ML Kit attempts failed, try the fallback approach
      if (bestText.isEmpty) {
        debugPrint(
            'All ML Kit OCR variants failed, attempting last-resort OCR method');

        try {
          // Try to reinitialize the recognizer
          await _initializeTextRecognizer();

          // Create special last resort image variants
          final List<File> lastResortImages =
              await _createLastResortImages(_image!);

          // Try OCR on each of these last resort images
          for (final File lastResortFile in lastResortImages) {
            debugPrint(
                'Trying OCR on last resort image: ${lastResortFile.path}');

            try {
              final InputImage input = InputImage.fromFile(lastResortFile);
              final RecognizedText? recognizedText =
                  await _textRecognizer.processImage(input);

              if (recognizedText != null && recognizedText.text.isNotEmpty) {
                bestText = recognizedText.text;
                bestScore = 1; // Just to indicate we got something
                debugPrint(
                    'Last resort OCR extracted ${bestText.length} chars');
                break; // Stop after first success
              }
            } catch (e) {
              debugPrint('Error processing last resort image: $e');
            }
          }
        } catch (lastResortError) {
          debugPrint('Last resort OCR also failed: $lastResortError');
        }
      }

      // Debug log the result
      if (bestText.isEmpty) {
        debugPrint('All OCR variants returned no usable text');
      } else {
        debugPrint(
            'Best OCR result (score $bestScore): ${_truncateText(bestText)}');
      }

      setState(() {
        _progress = 0.9;
        _isOcrRunning = false;
      });

      // Clean up the best text
      final String cleanedText =
          bestText.isEmpty ? '' : _cleanOcrText(bestText);
      debugPrint(
          'Original OCR text (score $bestScore): ${_truncateText(bestText)}');
      debugPrint('Cleaned OCR text: ${_truncateText(cleanedText)}');

      return cleanedText;
    } catch (e) {
      setState(() {
        _isOcrRunning = false;
      });
      debugPrint('OCR Error: $e');
      return '';
    }
  }

  // Enhanced version of the text cleaning method
  String _cleanOcrText(String text) {
    if (text.isEmpty) return text;

    // Remove excessive whitespace
    String cleaned = text.replaceAll(RegExp(r'\s+'), ' ');

    // Preserve line breaks which are important for receipt structure
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n'), '\n');

    // Remove non-useful characters that confuse the model
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s.,:()\-$%@#&+=*\/\n]'), '');

    // Fix common OCR errors - expanded list
    Map<String, String> commonErrors = {
      'HANGOCHEESECAKE': 'MANGO CHEESECAKE',
      'MANGOCHEESECAKE': 'MANGO CHEESECAKE',
      'MANGDCHEESECAKE': 'MANGO CHEESECAKE',
      'HANGOCHEESE': 'MANGO CHEESE',
      'HANGOCAKE': 'MANGO CAKE',
      'SERVICFCHARGE': 'SERVICE CHARGE',
      'SERVCECHARGE': 'SERVICE CHARGE',
      'DISCOUN': 'DISCOUNT',
      'SUBTOTAI': 'SUBTOTAL',
      'TDTAL': 'TOTAL',
      'TOTAI': 'TOTAL',
      'l0%': '10%', // Common number OCR errors
      'l.': '1.',
      'O.': '0.',
    };

    commonErrors.forEach((error, correction) {
      cleaned =
          cleaned.replaceAll(RegExp(error, caseSensitive: false), correction);
    });

    return cleaned;
  }

  // Helper to truncate text for logging
  String _truncateText(String text, {int maxLength = 100}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  Future<void> _processReceipt() async {
    if (_image == null) return;

    // Clean up any existing temp directories
    await _cleanupTempDirs();

    setState(() {
      _isProcessing = true;
      _detectedLanguage = '';
      _error = null;
      _extractedText = '';
      _progress = 0.0;
    });

    try {
      // Show user we're processing
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing image...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Preprocess the image - now returns a list of processed image files
      final List<File> processedImages = await _preprocessImage(_image!);

      // Perform OCR on device with improved algorithm
      final String recognizedText = await _performOCR(processedImages);

      if (recognizedText.isEmpty) {
        debugPrint('OCR returned empty text, stopping processing');
        setState(() {
          _extractedText = 'OCR failed to extract text';
          _error =
              'Could not extract any text from the image. Please try taking a clearer photo with better lighting.';
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No text could be extracted from the image. Please try again with a clearer photo.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        return; // Stop processing if no text was extracted
      } else {
        setState(() {
          _extractedText = recognizedText;
          _progress = 0.95;
        });

        // Show success message for OCR
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Text extracted (${recognizedText.length} chars), now processing with AI...'),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Debug logging
      debugPrint('Sending request to: ${ApiConfig.analyzeReceipt}');
      debugPrint('Text length: ${recognizedText.length} characters');

      // Only proceed if we have text to send
      if (recognizedText.trim().isEmpty) {
        setState(() {
          _error = 'No text was extracted to analyze. Please try again.';
          _isProcessing = false;
        });
        return;
      }

      // Send ONLY the text to API, no longer sending image
      final response = await http
          .post(
        Uri.parse(ApiConfig.analyzeReceipt),
        headers: ApiConfig.headers,
        body: json.encode({
          'text': recognizedText, // Send the OCR text as main data
          'ollama_config': {
            'model': 'mistral' // Use mistral as default model
          }
        }),
      )
          .timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException(
              'The server took too long to respond. This might happen if the receipt image is very complex.');
        },
      );

      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        debugPrint('Received response from API');

        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final data = jsonResponse['data'];

          final items = (data['items'] as List?)
                  ?.map((item) => OrderItem(
                        name: item['name'] as String? ?? 'Unknown Item',
                        quantity: item['quantity'] as int? ?? 1,
                        price: (item['unit_price'] as num?)?.toDouble() ?? 0.0,
                      ))
                  ?.toList() ??
              [];

          debugPrint('Parsed ${items.length} items');

          // Check if we got meaningful data - consider total amount as meaningful even without items
          bool hasValidData = items.isNotEmpty ||
              (data['merchant_name'] != null &&
                  data['merchant_name'].toString().isNotEmpty) ||
              (data['total_amount'] != null &&
                  (data['total_amount'] as num) > 0);

          // Show warning if we got total but no items
          if (items.isEmpty &&
              data['total_amount'] != null &&
              (data['total_amount'] as num) > 0) {
            // Create a default item when we have total but no items
            items.add(OrderItem(
              name: 'Unspecified Item',
              quantity: 1,
              price: (data['total_amount'] as num).toDouble(),
            ));

            // Show a warning message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Only detected total amount (${data['total_amount']}). Created a generic item.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }

          if (!hasValidData) {
            setState(() {
              _error =
                  'Receipt processing returned no meaningful data. Please try taking a clearer photo or adjust the receipt position and lighting.';
            });
            debugPrint('No meaningful data extracted from receipt');
            return;
          }

          setState(() {
            _orderItems = items;
            _total = (data['total_amount'] as num?)?.toString() ?? '0.0';
            _merchantName =
                data['merchant_name'] as String? ?? 'Unknown Merchant';
            _date = data['date'] as String? ??
                DateTime.now().toString().split(' ')[0];
            _detectedLanguage = data['detected_language'] as String? ?? '';
            _error = null;
            _progress = 1.0;
          });

          // Show success message if we found items
          if (_orderItems.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Successfully extracted ${_orderItems.length} items from receipt'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else if (jsonResponse['note'] != null) {
          // Handle note from server about processing
          setState(() => _error = jsonResponse['note']);
          debugPrint('Note from response: ${jsonResponse['note']}');
        } else {
          setState(() =>
              _error = jsonResponse['error'] ?? 'Failed to parse receipt');
          debugPrint('Error from response: ${jsonResponse['error']}');
        }
      } else {
        String errorMessage = 'Server error: ${response.statusCode}';
        if (response.statusCode == 503) {
          errorMessage =
              'Service unavailable: The API server is not responding';
        } else if (response.statusCode == 404) {
          errorMessage = 'API endpoint not found: Please check the URL';
        } else if (response.statusCode == 422) {
          errorMessage = 'Invalid request format: The API requires text data';
          debugPrint('422 Error details: ${response.body}');
        }
        setState(() => _error = errorMessage);
        debugPrint('HTTP Error: $errorMessage');
      }
    } on TimeoutException catch (_) {
      final error =
          'The request timed out. Try a clearer photo or check server status.';
      setState(() => _error = error);
      debugPrint('Timeout: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } catch (e) {
      final error = 'Error processing receipt: $e';
      setState(() => _error = error);
      debugPrint('Exception: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_image!, fit: BoxFit.contain),
                    ),
                    if (_isOcrRunning)
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

            // Processing Progress Bar
            if (_isProcessing && !_isOcrRunning)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.grey[200],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Processing... ${(_progress * 100).toInt()}%',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Extracted Text (Debugging purposes)
            if (_extractedText.isNotEmpty && _error != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extracted Text (first 200 chars):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _extractedText.length > 200
                          ? '${_extractedText.substring(0, 200)}...'
                          : _extractedText,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Language Detection Info
            if (_detectedLanguage.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.language, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Detected Language: ${_getLanguageName(_detectedLanguage)}',
                      style: const TextStyle(color: Colors.blue),
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

            // Loading Indicator
            if (_isProcessing && !_isOcrRunning)
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

  String _getLanguageName(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'ko':
        return 'Korean';
      case 'ja':
        return 'Japanese';
      case 'en':
        return 'English';
      default:
        return langCode;
    }
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
