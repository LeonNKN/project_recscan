import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart'; // TensorFlow Lite package
import 'package:image/image.dart' as img; // For preprocessing
import 'dart:typed_data';

class ScanPage extends StatefulWidget {
  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final List<File> _imageFiles = [];
  List<Map<String, dynamic>> _detections = [];
  String _statusMessage = "Select images to start processing.";
  final ImagePicker _picker = ImagePicker();
  late Interpreter _interpreter;

  // Class labels based on your model's metadata
  final List<String> classNames = [
    "Item",
    "Price",
    "Quantity",
    "Sub Price",
  ];

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

  /// Allow user to pick multiple images
  Future<void> _pickImages() async {
    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles != null) {
        setState(() {
          _imageFiles.addAll(pickedFiles.map((file) => File(file.path)));
          _statusMessage = "${pickedFiles.length} images selected.";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error picking images: $e";
      });
    }
  }

  /// Process images with the YOLO model
  Future<void> _processImages() async {
    if (_imageFiles.isEmpty) {
      setState(() {
        _statusMessage = "Please select images first.";
      });
      return;
    }

    setState(() {
      _statusMessage = "Processing images...";
    });

    try {
      final List<Map<String, dynamic>> allDetections = [];
      for (final file in _imageFiles) {
        final detections = await _runYOLOModel(file);
        allDetections.addAll(detections);
      }

      setState(() {
        _detections = allDetections;
        _statusMessage = "Processing complete.";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error during processing: $e";
      });
    }
  }

  /// Run YOLO inference on an image
  Future<List<Map<String, dynamic>>> _runYOLOModel(File imageFile) async {
    // Load and preprocess the image
    final inputImage = img.decodeImage(imageFile.readAsBytesSync());
    if (inputImage == null) throw Exception("Failed to decode image.");

    // Convert to grayscale
    final grayscaleImage = img.grayscale(inputImage);

    // Enhance contrast
    final enhancedImage = img.adjustColor(grayscaleImage, contrast: 2.0);

    // Resize to model input size
    final resizedImage = img.copyResize(enhancedImage, width: 640, height: 640);

    // Normalize and convert to 3-channel RGB
    final Float32List input = Float32List(640 * 640 * 3);
    int pixelIndex = 0;

    for (int y = 0; y < 640; y++) {
      for (int x = 0; x < 640; x++) {
        final pixel = resizedImage.getPixel(x, y);
        final normValue = img.getRed(pixel) / 255.0; // Normalized grayscale
        input[pixelIndex++] = normValue; // Red channel
        input[pixelIndex++] = normValue; // Green channel
        input[pixelIndex++] = normValue; // Blue channel
      }
    }

    // Prepare output buffer
    final outputShape = _interpreter.getOutputTensor(0).shape;
    final outputBuffer = List.filled(outputShape.reduce((a, b) => a * b), 0.0)
        .reshape(outputShape);

    // Run inference
    _interpreter.run(input.reshape([1, 640, 640, 3]), outputBuffer);

    // Postprocess results
    return _parseYOLOOutput(outputBuffer);
  }

  /// Parse YOLO model output into bounding boxes and labels
  List<Map<String, dynamic>> _parseYOLOOutput(List<dynamic> output) {
    final List<Map<String, dynamic>> detections = [];

    for (final detection in output[0]) {
      final confidence = detection[4];
      _statusMessage = "Checking.";
      if (confidence > 0.05) {
        // Confidence threshold
        final classIndex = detection[5].toInt();
        final label = classNames[classIndex];

        detections.add({
          "x": detection[0] * 640, // Scale to original image size
          "y": detection[1] * 640,
          "width": detection[2] * 640,
          "height": detection[3] * 640,
          "confidence": confidence,
          "label": label,
        });
      }
    }

    return detections;
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
              onPressed: _pickImages,
              child: const Text("Select Images"),
            ),
            ElevatedButton(
              onPressed: _processImages,
              child: const Text("Run YOLO Model"),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_detections.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _detections.length,
                  itemBuilder: (context, index) {
                    final detection = _detections[index];
                    return ListTile(
                      title: Text("Detected: ${detection['label']}"),
                      subtitle: Text(
                          "Confidence: ${(detection['confidence'] * 100).toStringAsFixed(2)}%"),
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
