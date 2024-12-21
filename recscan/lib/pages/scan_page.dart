import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/yolo_model.dart';
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
  List<ClassificationResult>? _detections;
  ImageClassifier? imageClassifier;

  @override
  void initState() {
    super.initState();
    _checkPermissions().then((permissionsGranted) {
      if (permissionsGranted) {
        _initializeModel();
      } else {
        setState(() {
          _statusMessage = "Permission denied. Cannot proceed.";
        });
      }
    });
  }

  Future<void> _initializeModel() async {
    try {
      final modelPath =
          await _copyAssetToAppSupportDir('assets/best_float32.tflite');
      final metadataPath =
          await _copyAssetToAppSupportDir('assets/best_metadata.json');
      final model = LocalYoloModel(
        id: '',
        task: Task.classify,
        format: Format.tflite,
        modelPath: modelPath,
        metadataPath: metadataPath,
      );

      imageClassifier = ImageClassifier(model: model);
      setState(() {
        _statusMessage = "Model initialized successfully.";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Failed to initialize model: $e";
      });
    }
  }

  Future<String> _copyAssetToAppSupportDir(String assetPath) async {
    final directory = await getApplicationSupportDirectory();
    final path = '${directory.path}/$assetPath';
    await io.Directory(dirname(path)).create(recursive: true);
    final file = io.File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
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

  Future<void> _processImage(io.File imageFile) async {
    if (imageClassifier == null) {
      setState(() {
        _statusMessage = "Model is not initialized.";
      });
      return;
    }

    setState(() {
      _statusMessage = "Processing image...";
    });

    try {
      final results =
          await imageClassifier!.classify(imagePath: imageFile.path);

      // Ensure the results list is non-null and filter out null items
      final nonNullResults =
          (results ?? []).whereType<ClassificationResult>().toList();

      final originalImage = img.decodeImage(await imageFile.readAsBytes());

      if (originalImage == null) {
        setState(() {
          _statusMessage = "Failed to decode image.";
        });
        return;
      }

      final detectedRegions = _drawBoundingBoxes(nonNullResults, originalImage);
      setState(() {
        _detections = detectedRegions;
        _inputImageMemory = Uint8List.fromList(img.encodeJpg(originalImage));
        _statusMessage = "Processing complete.";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error during processing: $e";
      });
    }
  }

  List<ClassificationResult> _drawBoundingBoxes(
      List<ClassificationResult> results, img.Image originalImage) {
    final detectedRegions = <ClassificationResult>[];

    for (final detection in results) {
      final confidence = detection.confidence;
      if (confidence > 0.1) {
        detectedRegions.add(detection);

        // Placeholder bounding box logic
        final boundingBox = [10, 20, 100, 200]; // Replace with real values
        _drawBoundingBox(originalImage, boundingBox[0], boundingBox[1],
            boundingBox[2], boundingBox[3], 4);
      }
    }

    return detectedRegions;
  }

  void _drawBoundingBox(
      img.Image image, int x1, int y1, int x2, int y2, int thickness) {
    for (int i = 0; i < thickness; i++) {
      img.drawRect(
        image,
        x1 - i,
        y1 - i,
        x2 + i,
        y2 + i,
        img.getColor(255, 0, 0),
      );
    }
  }

  Future<bool> _checkPermissions() async {
    final permissions = [
      Permission.camera,
      Permission.storage,
    ];
    final statuses = await permissions.request();

    return statuses.values.every((status) => status.isGranted);
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
                    return Column(
                      children: [
                        Text(
                          "Detected: ${detection.label}, Confidence: ${(detection.confidence * 100).toStringAsFixed(2)}%",
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
