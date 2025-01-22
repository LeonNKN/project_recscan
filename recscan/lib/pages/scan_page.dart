import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_v2/tflite_v2.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

class ScanPage extends StatefulWidget {
  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _inputImageMemory;
  String _statusMessage = "Select an image to start processing.";
  List<Map<String, dynamic>>? _detections;

  @override
  void initState() {
    super.initState();
    _checkPermissions().then((permissionsGranted) {
      if (permissionsGranted) {
        _loadModel();
      } else {
        setState(() {
          _statusMessage = "Permission denied. Cannot proceed.";
        });
      }
    });
  }

  Future<void> _loadModel() async {
    try {
      await Tflite.loadModel(
        model: "assets/best_float32.tflite",
        labels: "assets/labels.txt",
      );
      setState(() {
        _statusMessage = "Model loaded successfully.";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Failed to load model: $e";
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final file = io.File(pickedFile.path);
        setState(() {
          _statusMessage = "Image selected.";
        });
        await _processImage(file);
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error picking image: $e";
      });
    }
  }

  Uint8List imageToByteListFloat32(
      img.Image image, int inputSize, double mean, double std) {
    final convertedBytes = Float32List(inputSize * inputSize * 3);
    final buffer = Float32List.view(convertedBytes.buffer);

    int pixelIndex = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        buffer[pixelIndex++] = ((pixel >> 16) & 0xFF) / std - mean; // R
        buffer[pixelIndex++] = ((pixel >> 8) & 0xFF) / std - mean; // G
        buffer[pixelIndex++] = (pixel & 0xFF) / std - mean; // B
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  Future<void> _processImage(io.File imageFile) async {
    setState(() {
      _statusMessage = "Processing image...";
    });

    try {
      // Decode the original image
      final originalImage = img.decodeImage(await imageFile.readAsBytes());
      if (originalImage == null) {
        setState(() {
          _statusMessage = "Failed to decode image.";
        });
        return;
      }

      // Resize image to 640x640
      final resizedImage =
          img.copyResize(originalImage, width: 640, height: 640);

      // Convert image to tensor
      final binaryData = imageToByteListFloat32(resizedImage, 640, 0.0, 255.0);

      // Perform object detection
      final recognitions = await Tflite.detectObjectOnBinary(
        binary: binaryData,
        model: "YOLO",
        threshold: 0.3,
        numResultsPerClass: 2,
        anchors: [
          0.573,
          0.678,
          1.874,
          2.063,
          3.338,
          5.474,
          7.883,
          3.528,
          9.771,
          9.168
        ],
        blockSize: 32,
        numBoxesPerBlock: 5,
        asynch: true,
      );

      // Check if recognitions are valid
      if (recognitions == null || recognitions.isEmpty) {
        setState(() {
          _statusMessage = "No objects detected.";
        });
        return;
      }

      // Annotate detections on the original image
      final annotatedImage = _drawBoundingBoxes(recognitions, originalImage);

      setState(() {
        _detections = recognitions
            .map((r) => {
                  "detectedClass": r["detectedClass"],
                  "confidenceInClass": r["confidenceInClass"],
                  "rect": r["rect"],
                })
            .toList();
        _inputImageMemory = Uint8List.fromList(img.encodeJpg(annotatedImage));
        _statusMessage = "Detection complete.";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error during detection: $e";
      });
    }
  }

  img.Image _drawBoundingBoxes(List<dynamic> results, img.Image originalImage) {
    for (final detection in results) {
      final label = detection["detectedClass"];
      final confidence = detection["confidenceInClass"];
      final rect = detection["rect"];

      final x1 = (rect["x"] * originalImage.width).toInt();
      final y1 = (rect["y"] * originalImage.height).toInt();
      final x2 = (rect["x"] + rect["w"]) * originalImage.width.toInt();
      final y2 = (rect["y"] + rect["h"]) * originalImage.height.toInt();

      img.drawRect(originalImage, x1, y1, x2, y2, img.getColor(255, 0, 0));
      img.drawString(originalImage, img.arial_24, x1, y1 - 10,
          "$label ${(confidence * 100).toStringAsFixed(2)}%",
          color: img.getColor(255, 255, 255));
    }
    return originalImage;
  }

  Future<bool> _checkPermissions() async {
    final permissions = [Permission.camera];
    final statuses = await permissions.request();
    return statuses.values.every((status) => status.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Object Detection")),
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
                    return Column(
                      children: [
                        Text(
                          "Detected: ${detection['detectedClass']}, Confidence: ${(detection['confidenceInClass'] * 100).toStringAsFixed(2)}%",
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
