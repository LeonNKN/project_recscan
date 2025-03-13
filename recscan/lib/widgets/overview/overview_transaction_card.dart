import 'package:flutter/material.dart';
import '../../models/models.dart';

// A basic model for your receipts (same as your RestaurantCardModel)
class ReceiptModel {
  final int id;
  final String restaurantName;
  final DateTime dateTime;
  final double total;
  // ... plus items, etc.

  ReceiptModel({
    required this.id,
    required this.restaurantName,
    required this.dateTime,
    required this.total,
    // etc...
  });
}

// A new model for "Report"
class ReportModel {
  final int id;
  final String title; // e.g. "Report A", "March Expenses", etc.
  final List<ReceiptModel> receipts;

  ReportModel({
    required this.id,
    required this.title,
    required this.receipts,
  });
}

class TransactionCardModel {
  final int id;
  final String restaurantName;
  final DateTime dateTime;
  final double subtotal;
  final double total;
  final String category;
  final Color categoryColor;
  final Color iconColor;
  final List<OrderItem> items;

  TransactionCardModel({
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

class ExpandableRestaurantCard extends StatefulWidget {
  final TransactionCardModel data;
  final VoidCallback? onLongPress;

  const ExpandableRestaurantCard({
    super.key,
    required this.data,
    this.onLongPress,
  });

  @override
  _ExpandableRestaurantCardState createState() =>
      _ExpandableRestaurantCardState();
}

class _ExpandableRestaurantCardState extends State<ExpandableRestaurantCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final cardData = widget.data;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Restaurant Name and DateTime
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cardData.restaurantName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${cardData.dateTime.day}/${cardData.dateTime.month}/${cardData.dateTime.year}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right: Total and Category
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'RM${cardData.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        cardData.category,
                        style: TextStyle(
                          fontSize: 14,
                          color: cardData.categoryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Expanded Content
              if (_isExpanded) ...[
                const Divider(height: 24),
                // Items List
                ...cardData.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Item name and quantity
                          Expanded(
                            flex: 3,
                            child: Text(
                              '${item.quantity}x ${item.name}',
                              style: const TextStyle(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Price and Total
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'RM${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'RM${item.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),

                const Divider(height: 24),
                // Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:'),
                    Text('RM${cardData.subtotal.toStringAsFixed(2)}'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'RM${cardData.total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
