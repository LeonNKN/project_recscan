import 'package:flutter/material.dart';

/// Model for individual items in a receipt
class OrderItem {
  final String name;
  final double price;
  final int quantity;

  OrderItem({
    required this.name,
    required this.price,
    required this.quantity,
  });

  double get total => price * quantity;
}

/// Model for a receipt/transaction
class ReceiptModel {
  final int id;
  final String restaurantName;
  final DateTime dateTime;
  final double total;

  ReceiptModel({
    required this.id,
    required this.restaurantName,
    required this.dateTime,
    required this.total,
  });
}

/// Model for a report that contains multiple receipts
class ReportModel {
  final int id;
  final String title;
  final List<ReceiptModel> receipts;

  ReportModel({
    required this.id,
    required this.title,
    required this.receipts,
  });
}

/// Model for a restaurant card that includes items and category
class RestaurantCardModel {
  final int id;
  final String restaurantName;
  final DateTime dateTime;
  final double subtotal;
  final double total;
  final String category;
  final Color categoryColor;
  final Color iconColor;
  final List<OrderItem> items;

  RestaurantCardModel({
    required this.id,
    required this.restaurantName,
    required this.dateTime,
    required this.subtotal,
    required this.total,
    required this.category,
    required this.categoryColor,
    required this.iconColor,
    required this.items,
  });
}

/// Model for category card display
class CardItem {
  final IconData icon;
  final String title;
  final String amount;

  CardItem({
    required this.icon,
    required this.title,
    required this.amount,
  });
}

/// Model for item price extraction results
class ItemPriceExtractionResult {
  final List<String> items;
  final List<String> prices;

  ItemPriceExtractionResult({
    this.items = const [],
    this.prices = const [],
  });
}
