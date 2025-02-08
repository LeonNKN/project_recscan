// scan_page.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// Import our editable combined result view widget.
import 'editable_combined_result_card_view.dart';
// Import the common ItemRow model.
import 'item_row.dart';
// Import CategoryItem and SubItem models (for export).
import 'category_item.dart';

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
              border: Border.all(color: Colors.red, width: 2),
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
  List<ItemRow> _itemRows = [];
  final _formKey = GlobalKey<FormState>();
  String _total = ''; // Holds detected total

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final originalImageFile = File(pickedFile.path);
      final bytes = await originalImageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) return;
      final resizedImage =
          img.copyResize(originalImage, width: 640, height: 640);
      final directory = await getTemporaryDirectory();
      final resizedPath =
          '${directory.path}/resized_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final resizedFile = File(resizedPath);
      await resizedFile.writeAsBytes(img.encodeJpg(resizedImage));
      setState(() {
        _image = resizedFile;
      });
    }
  }

  double computeMean(img.Image image) {
    double sum = 0.0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        sum += pixel.r;
      }
    }
    return sum / (image.width * image.height);
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
    final processedImage = img.grayscale(croppedImage);
    img.normalize(processedImage, min: 0, max: 255);
    img.contrast(processedImage, contrast: 100);
    img.adjustColor(processedImage, saturation: 2.0);
    int newWidth = ((croppedWidth + 31) ~/ 32) * 32;
    int newHeight = ((croppedHeight + 31) ~/ 32) * 32;
    final paddingX = (newWidth - croppedWidth) ~/ 2;
    final paddingY = (newHeight - croppedHeight) ~/ 2;
    final adjustedImage = img.Image(width: newWidth, height: newHeight);
    img.fill(adjustedImage, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(adjustedImage, processedImage,
        dstX: paddingX, dstY: paddingY);
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(path);
    await file.writeAsBytes(img.encodeJpg(adjustedImage));
    return file;
  }

  void loadModel() async {
    _objectModel = await PytorchLite.loadObjectDetectionModel(
      "assets/best.torchscript",
      5,
      640,
      640,
      labelPath: "assets/labels.txt",
      objectDetectionModelType: ObjectDetectionModelType.yolov8,
    );
  }

  Widget _buildImageWithBoundingBoxes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const imageSize = Size(640, 640);
        return AspectRatio(
          aspectRatio: 1,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: imageSize.width,
              height: imageSize.height,
              child: Stack(
                children: [
                  Image.file(_image!,
                      width: imageSize.width,
                      height: imageSize.height,
                      fit: BoxFit.cover),
                  BoundingBoxOverlay(
                      detections: _detections, imageSize: imageSize),
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
        minimumScore: 0.5,
        iOUThreshold: 0.3,
      );
      setState(() {
        _detections = objDetect;
      });

      // Separate detections into lists.
      List<String> detectedItems = [];
      List<String> detectedPrices = [];
      List<String> detectedQty = [];
      List<String> detectedSubPrices = [];
      String detectedTotal = '';

      for (final detection in objDetect) {
        final pytorchRect = detection.rect;
        final flutterRect = Rect.fromLTRB(
          pytorchRect.left,
          pytorchRect.top,
          pytorchRect.right,
          pytorchRect.bottom,
        );
        final croppedFile = await _cropImageToDetection(_image!, flutterRect);
        if (croppedFile != null) {
          final inputImage = InputImage.fromFilePath(croppedFile.path);
          final recognizedText = await _textRecognizer.processImage(inputImage);
          if (recognizedText.text.isNotEmpty) {
            String className = detection.className?.toLowerCase() ?? '';
            if (className.contains('item')) {
              detectedItems.add(recognizedText.text);
            } else if (className.contains('sub') &&
                !className.contains('total')) {
              detectedSubPrices.add(recognizedText.text);
            } else if (className.contains('price')) {
              if (className.contains('total')) {
                detectedTotal = recognizedText.text;
              } else {
                detectedPrices.add(recognizedText.text);
              }
            } else if (className.contains('qty') ||
                className.contains('quantity')) {
              detectedQty.add(recognizedText.text);
            }
            print('Detected ${detection.className}: ${recognizedText.text}');
          }
        }
      }

      int rowCount = [
        detectedItems.length,
        detectedPrices.length,
        detectedQty.length,
        detectedSubPrices.length
      ].reduce((a, b) => a > b ? a : b);

      List<ItemRow> combinedRows = [];
      for (int i = 0; i < rowCount; i++) {
        String itemValue =
            (i < detectedItems.length) ? detectedItems[i] : "PLACEHOLDER";
        String priceValue =
            (i < detectedPrices.length) ? detectedPrices[i] : "0.00";
        String qtyValue = (i < detectedQty.length) ? detectedQty[i] : "1";
        String subPriceValue =
            (i < detectedSubPrices.length) ? detectedSubPrices[i] : "0.00";
        combinedRows.add(ItemRow(
          item: itemValue,
          price: priceValue,
          quantity: qtyValue,
          subPrice: subPriceValue,
          isUserAdded: false,
        ));
      }

      setState(() {
        _itemRows = combinedRows;
        _total = detectedTotal;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
    }
  }

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => _pickImage(ImageSource.camera),
                      child: const Text('Open Camera'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      child: const Text('Choose from Gallery'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _runObjectDetection,
                  child: const Text('Run Object Detection'),
                ),
                if (_itemRows.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  EditableCombinedResultCardView(
                    itemRows: _itemRows,
                    total: _total,
                    onChanged: (updatedRows, updatedTotal) {
                      setState(() {
                        _itemRows = updatedRows;
                        _total = updatedTotal;
                      });
                    },
                    onDone: (finalRows, finalTotal) {
                      // Convert finalRows into a list of SubItems.
                      List<SubItem> subItems = finalRows.map((row) {
                        double price = double.tryParse(row.price) ?? 0.0;
                        int qty = int.tryParse(row.quantity) ?? 1;
                        return SubItem(title: row.item, price: price * qty);
                      }).toList();
                      double totalPrice = subItems.fold(
                          0.0, (prev, element) => prev + element.price);
                      CategoryItem exportedResult = CategoryItem(
                        title: 'Scan Result',
                        category: 'Scanned',
                        subItems: subItems,
                        totalPrice: totalPrice,
                      );
                      Navigator.pop(context, exportedResult);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
