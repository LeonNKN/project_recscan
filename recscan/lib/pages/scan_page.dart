import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Object Detection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ScanPage(),
    );
  }
}

// Add this new class to handle painting bounding boxes
class BoundingBoxOverlay extends StatelessWidget {
  final List<ResultObjectDetection> detections;
  final Size imageSize;

  const BoundingBoxOverlay({
    super.key,
    required this.detections,
    required this.imageSize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: detections.map((detection) {
        final rect = detection.rect;
        return Positioned(
          left: rect.left * imageSize.width,
          top: rect.top * imageSize.height,
          width: (rect.right - rect.left) * imageSize.width,
          height: (rect.bottom - rect.top) * imageSize.height,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.red,
                width: 2,
              ),
            ),
            child: Text(
              '${detection.className} ${(detection.score * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.red,
                backgroundColor: Colors.white,
                fontSize: 10,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  late ModelObjectDetection _objectModel;
  List<ResultObjectDetection> _detections = [];
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void initState() {
    super.initState();
    loadModel(); // Initialize the model when the widget is created
  }

  @override
  void dispose() {
    _textRecognizer.close(); // Clean up recognizer
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      // Read the original image file
      final originalImageFile = File(pickedFile.path);
      final bytes = await originalImageFile.readAsBytes();

      // Decode and resize the image
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) return;

      final resizedImage =
          img.copyResize(originalImage, width: 640, height: 640);

      // Save resized image to temporary file
      final directory = await getTemporaryDirectory();
      final resizedPath =
          '${directory.path}/resized_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final resizedFile = File(resizedPath);
      await resizedFile.writeAsBytes(img.encodeJpg(resizedImage));

      setState(() {
        _image = resizedFile; // Use the resized image
      });
    }
  }

  Future<File?> _cropImageToDetection(File image, Rect detectionRect) async {
    final originalImage = img.decodeImage(await image.readAsBytes());
    if (originalImage == null) return null;

    final width = originalImage.width;
    final height = originalImage.height;

    final left = (detectionRect.left * width).clamp(0, width).toInt();
    final top = (detectionRect.top * height).clamp(0, height).toInt();
    final right = (detectionRect.right * width).clamp(0, width).toInt();
    final bottom = (detectionRect.bottom * height).clamp(0, height).toInt();

    final croppedWidth = right - left;
    final croppedHeight = bottom - top;

    if (croppedWidth <= 0 || croppedHeight <= 0) return null;

    final croppedImage = img.copyCrop(
      originalImage,
      x: left,
      y: top,
      width: croppedWidth,
      height: croppedHeight,
    );

    // Adjust dimensions to be multiples of 32
    int newWidth = ((croppedWidth + 31) ~/ 32) * 32;
    int newHeight = ((croppedHeight + 31) ~/ 32) * 32;

    // Create a new image with a white background
    final adjustedImage = img.Image(width: newWidth, height: newHeight);
    img.fill(adjustedImage, color: img.ColorRgb8(255, 255, 255));

    // Paste the cropped image into the adjusted image
    img.compositeImage(adjustedImage, croppedImage, dstX: 0, dstY: 0);

    // Save the adjusted image
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return File(path)..writeAsBytesSync(img.encodeJpg(adjustedImage));
  }

  void loadModel() async {
    _objectModel = await PytorchLite.loadObjectDetectionModel(
        "assets/best.torchscript", 5, 640, 640,
        labelPath: "assets/labels.txt",
        objectDetectionModelType: ObjectDetectionModelType.yolov8);
  }

  Widget _buildImageWithBoundingBoxes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth - 40; // Account for padding
        final imageSize = Size(640, 640); // Original image size

        return AspectRatio(
          aspectRatio: 1, // Maintain square aspect ratio
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: imageSize.width,
              height: imageSize.height,
              child: Stack(
                children: [
                  Image.file(
                    _image!,
                    width: imageSize.width,
                    height: imageSize.height,
                    fit: BoxFit.cover,
                  ),
                  BoundingBoxOverlay(
                    detections: _detections,
                    imageSize: imageSize,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _runObjectDetection() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture an image first!')),
      );
      return;
    }

    try {
      final objDetect = await _objectModel.getImagePrediction(
        await _image!.readAsBytes(),
        minimumScore: 0.1,
        iOUThreshold: 0.3,
      );

      setState(() => _detections = objDetect);

      final results = StringBuffer('Detected ${objDetect.length} objects:\n');

      for (final detection in objDetect) {
        final pytorchRect = detection.rect;
        // Convert PyTorchRect to Flutter Rect
        final flutterRect = Rect.fromLTRB(
          pytorchRect.left,
          pytorchRect.top,
          pytorchRect.right,
          pytorchRect.bottom,
        );

        // Object detection info
        results.writeln(
            '${detection.className} (${(detection.score * 100).toStringAsFixed(1)}%): '
            '[${pytorchRect.left.toStringAsFixed(2)}, ${pytorchRect.top.toStringAsFixed(2)}, '
            '${pytorchRect.right.toStringAsFixed(2)}, ${pytorchRect.bottom.toStringAsFixed(2)}]');

        // Text recognition for this detection
        final croppedFile = await _cropImageToDetection(_image!, flutterRect);
        if (croppedFile != null) {
          final inputImage = InputImage.fromFilePath(croppedFile.path);
          final text = await _textRecognizer.processImage(inputImage);

          if (text.text.isNotEmpty) {
            results.writeln('Detected text: ${text.text}');
            print('Text in ${detection.className}: ${text.text}');
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(results.toString()),
          duration: const Duration(seconds: 10),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
    }
  }

// Update the build method's column to handle larger image
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Object Detection')),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _image == null
                    ? const Text('No image selected')
                    : _buildImageWithBoundingBoxes(),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _pickImage,
                  child: const Text('Open Camera'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _runObjectDetection,
                  child: const Text('Run Object Detection'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
