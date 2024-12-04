import 'dart:io';
import 'dart:developer' as developer;
import 'dart:convert';
import '../structure/item_price_extraction_result.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// Utility for Text Extraction on Receipt Item and Price
Future<ItemPriceExtractionResult> extractTextFromImages(
    int classType,
    int numImages,
    List<String> itemsList,
    List<String> pricesList,
    List<File> imageFiles) async {
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    for (File image in imageFiles) {
      final InputImage inputImage = InputImage.fromFile(image);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      // Append results to list
      if (classType == 0) {
        itemsList.add(recognizedText.text);
      } else {
        pricesList.add(recognizedText.text);
      }
    }
  } catch (e) {
    developer.log("Error processing images: $e",
        name: 'extractTextFromImageError', level: 500);
    throw Exception("Failed to process images: $e");
  } finally {
    textRecognizer.close();
  }

  return ItemPriceExtractionResult(
    items: itemsList,
    prices: pricesList,
  );
}

Future<void> saveItemsWithDetailsToJson(List<String> items, List<double> prices,
    String address, String date, String identifier) async {
  /* {
  "address": "123 Main St, Springfield",
  "date": "2024-12-01",
  "items": [
    {"item": "Apple", "price": 1.2},
    {"item": "Banana", "price": 0.8},
    {"item": "Cherry", "price": 2.5}
  ],
  "total_price": 4.5
  }*/
  if (items.length != prices.length) {
    throw ArgumentError("The lengths of items and prices lists must be equal.");
  }

  try {
    // Combine items and prices into a list of maps
    List<Map<String, dynamic>> combinedList = [];
    double totalPrice = 0;

    for (int i = 0; i < items.length; i++) {
      combinedList.add({"item": items[i], "price": prices[i]});
      totalPrice += prices[i]; // Calculate total price
    }

    // Create a JSON object with all details
    Map<String, dynamic> jsonData = {
      "address": address,
      "date": date,
      "items": combinedList,
      "total_price": totalPrice
    };

    // Convert to JSON string
    String jsonString = jsonEncode(jsonData);

    // Save to file with identifier
    final directory =
        Directory.systemTemp; // Change this to your desired directory
    final file = File('${directory.path}/$identifier.json');

    await file.writeAsString(jsonString);
    developer.log("Data saved to ${file.path}",
        name: 'saveItemsWithDetailsToJsonSuccess', level: 500);
  } catch (e) {
    developer.log("Error saving JSON: $e",
        name: 'saveItemsWithDetailsToJsonError', level: 500);
  }
}
