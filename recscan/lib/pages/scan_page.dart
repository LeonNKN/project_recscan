import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/yolo_model.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

class ScanPage extends StatefulWidget {
  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final List<File> _imageFiles = [];
  Uint8List? _inputImageMemory;
  String _statusMessage = "Select an image to start processing.";
  final ImagePicker _picker = ImagePicker();
  List<ClassificationResult?>? _detections;
  final List<String> classNames = ["Item", "Price", "Quantity", "Sub Price"];
  ImageClassifier? imageClassifier; // Declare at the class level

  @override
  void initState() {
    super.initState();
    // Load the model and handle it asynchronously
    _initializeModel();
  }

  void _initializeModel() async {
    try {
      final imageClassifier = await _loadModel();

      // Perform any additional setup with the objectDetector if necessary
      setState(() {
        _statusMessage = "Model initialized successfully.";
        // Store objectDetector if you need it elsewhere in the widget
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Failed to initialize model: $e";
      });
    }
  }

  Future<ImageClassifier> _loadModel() async {
    try {
      final model = LocalYoloModel(
        id: '',
        task: Task.classify,
        format: Format.tflite,
        modelPath: 'assets/best_float32.tflite',
        metadataPath: 'assets/best_float32.tflite',
      );

      final imageClassifier = ImageClassifier(model: model);

      setState(() {
        _statusMessage = "Model loaded successfully.";
      });

      return imageClassifier; // Return the ObjectDetector instance here
    } catch (e) {
      setState(() {
        _statusMessage = "Error loading model: $e";
      });

      // You might want to throw the error to propagate it if necessary
      throw Exception("Error loading model: $e");
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
      final results = await _runYOLOModel(_imageFiles.first);
      setState(() {
        _detections = results; // Store results directly
        _statusMessage = "Processing complete.";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error during processing: $e";
      });
    }
  }

  Future<List<ClassificationResult>> _runYOLOModel(File imageFile) async {
    if (imageClassifier == null) {
      print('Error: imageClassifier is not initialized.');
      return []; // Return an empty list as a fallback
    }

    try {
      final results =
          await imageClassifier!.classify(imagePath: imageFile.path);

      // Ensure the list is non-null and contains only non-null elements
      return results?.whereType<ClassificationResult>().toList() ?? [];
    } catch (e) {
      print('Error running YOLO model: $e');
      return []; // Return an empty list in case of an error
    }
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
            if (_detections != null && _detections!.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _detections!.length,
                  itemBuilder: (context, index) {
                    final detection = _detections![index];
                    if (detection == null) {
                      return const Text("No detection available.");
                    }
                    return Column(
                      children: [
                        Text(
                          "Detected: ${detection.label}, Confidence: ${(detection.confidence * 100).toStringAsFixed(2)}%",
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
