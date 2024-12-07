import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<Map<String, List<String>>> extractTextFromImages(
    List<File> images) async {
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final List<String> items = [];
  final List<String> prices = [];

  for (File image in images) {
    try {
      final inputImage = InputImage.fromFile(image);
      final recognizedText = await textRecognizer.processImage(inputImage);

      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          final text = line.text;

          // Extract items and prices (example logic)
          if (text.contains(RegExp(r'\d+\.\d{2}'))) {
            prices.add(text);
          } else {
            items.add(text);
          }
        }
      }
    } catch (e) {
      print("Error processing image: $e");
    }
  }

  await textRecognizer.close();

  return {"items": items, "prices": prices};
}
