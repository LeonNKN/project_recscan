import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

class ScanPage extends StatefulWidget {
  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final List<File> _imageFiles = [];
  List<Map<String, dynamic>> _detections = [];
  Uint8List? _inputImageMemory;
  String _statusMessage = "Select an image to start processing.";
  final ImagePicker _picker = ImagePicker();
  late Interpreter _interpreter;

  final List<String> classNames = ["Item", "Price", "Quantity", "Sub Price"];

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  /// Load the YOLO model
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/best_float32.tflite');
      setState(() {
        _statusMessage = "Model loaded successfully.";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error loading model: $e";
      });
    }
  }

  /// Allow user to pick an image
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFiles.clear();
          _imageFiles.add(File(pickedFile.path));
          _statusMessage = "Image selected.";
        });
        _processImages();
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error picking image: $e";
      });
    }
  }

  /// Process images with the YOLO model
  Future<void> _processImages() async {
    if (_imageFiles.isEmpty) {
      setState(() {
        _statusMessage = "Please select an image first.";
      });
      return;
    }

    setState(() {
      _statusMessage = "Processing image...";
    });

    try {
      final detections = await _runYOLOModel(_imageFiles.first);
      setState(() {
        _detections = detections;
        _statusMessage = "Processing complete.";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error during processing: $e";
      });
    }
  }

  /// Run YOLO inference and draw bounding boxes
  Future<List<Map<String, dynamic>>> _runYOLOModel(File imageFile) async {
    final originalImage = img.decodeImage(imageFile.readAsBytesSync());
    if (originalImage == null) throw Exception("Failed to decode image.");

    // Resize the image to the YOLO model input size
    final resizedImage = img.copyResize(originalImage, width: 640, height: 640);

    // Prepare input tensor
    final Float32List input = Float32List(640 * 640 * 3);
    int pixelIndex = 0;

    // Extract normalized pixel values
    for (int y = 0; y < 640; y++) {
      for (int x = 0; x < 640; x++) {
        final pixel = resizedImage.getPixel(x, y);
        input[pixelIndex++] = img.getRed(pixel) / 255.0;
        input[pixelIndex++] = img.getGreen(pixel) / 255.0;
        input[pixelIndex++] = img.getBlue(pixel) / 255.0;
      }
    }

    // Prepare output tensor buffer
    final outputShape = _interpreter.getOutputTensor(0).shape;
    final outputBuffer = List.filled(
      outputShape.reduce((a, b) => a * b),
      0.0,
    ).reshape(outputShape);

    // Run inference
    _interpreter.run(input.reshape([1, 640, 640, 3]), outputBuffer);

    // Draw bounding boxes
    return _drawBoundingBoxes(outputBuffer, originalImage);
  }

  /// Draw bounding box manually by drawing multiple rectangles for thickness
  void _drawBoundingBox(
      img.Image image, int x1, int y1, int x2, int y2, int thickness) {
    for (int i = 0; i < thickness; i++) {
      img.drawRect(
        image,
        x1 - i,
        y1 - i,
        x2 + i,
        y2 + i,
        img.getColor(255, 0, 0), // Red color
      );
    }
  }

  /// Draw bounding boxes on the input image
  List<Map<String, dynamic>> _drawBoundingBoxes(
      List<dynamic> output, img.Image originalImage) {
    final List<Map<String, dynamic>> detectedRegions = [];

    for (final detection in output[0]) {
      final confidence = detection[4];
      if (confidence > 0.1) {
        // Adjust confidence threshold
        final classIndex = detection[5].toInt();
        final label = classNames[classIndex];

        // Calculate bounding box
        final xCenter = detection[0] * originalImage.width;
        final yCenter = detection[1] * originalImage.height;
        final width = detection[2] * originalImage.width;
        final height = detection[3] * originalImage.height;

        final x1 = (xCenter - width / 2).clamp(0, originalImage.width).toInt();
        final y1 =
            (yCenter - height / 2).clamp(0, originalImage.height).toInt();
        final x2 = (xCenter + width / 2).clamp(0, originalImage.width).toInt();
        final y2 =
            (yCenter + height / 2).clamp(0, originalImage.height).toInt();

        debugPrint("✅ $label : $x1, $y1, $x2, $y2");

        // Ensure valid bounding box
        if (x2 > x1 && y2 > y1) {
          _drawBoundingBox(originalImage, x1, y1, x2, y2, 100); // Thickness 4

          detectedRegions.add({
            "label": label,
            "confidence": confidence,
            "boundingBox": [x1, y1, x2, y2],
          });

          debugPrint(
              "✅ Detected: $label, Confidence: ${(confidence * 100).toStringAsFixed(2)}%");
        }
      }
    }

    setState(() {
      _inputImageMemory = Uint8List.fromList(img.encodeJpg(originalImage));
    });

    debugPrint("📊 Total Detections Found: ${detectedRegions.length}");
    return detectedRegions;
  }

  @override
  void dispose() {
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("YOLO Scan Page")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text("Select Image"),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_inputImageMemory != null)
              Image.memory(
                _inputImageMemory!,
                height: 400,
                fit: BoxFit.contain,
              ),
            const Divider(),
            if (_detections.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _detections.length,
                  itemBuilder: (context, index) {
                    final detection = _detections[index];
                    return Column(
                      children: [
                        Text(
                          "Detected: ${detection['label']}, Confidence: ${(detection['confidence'] * 100).toStringAsFixed(2)}%",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
