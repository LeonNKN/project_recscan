import 'package:flutter/material.dart';
import 'package:recscan/pages/modify_transaction_page.dart';

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

class OrderItem {
  final String name;
  final double price;
  final int quantity;

  OrderItem({
    required this.name,
    required this.price,
    required this.quantity,
  });
}

class RestaurantCardModel {
  final int id;
  final String restaurantName;
  final DateTime dateTime;
  final double total;
  final String category;
  final Color categoryColor;
  final Color iconColor;
  final List<OrderItem> items;

  RestaurantCardModel({
    required this.id,
    required this.restaurantName,
    required this.dateTime,
    required this.total,
    required this.category,
    required this.categoryColor,
    required this.iconColor,
    required this.items,
  });
}

class ExpandableRestaurantCard extends StatefulWidget {
  final RestaurantCardModel data;

  const ExpandableRestaurantCard({
    Key? key,
    required this.data,
  }) : super(key: key);

  @override
  _ExpandableRestaurantCardState createState() =>
      _ExpandableRestaurantCardState();
}

class _ExpandableRestaurantCardState extends State<ExpandableRestaurantCard> {
  bool _isExpanded = false;

  // Store a local copy so we can update after editing
  late RestaurantCardModel _cardData;

  @override
  void initState() {
    super.initState();
    _cardData = widget.data; // Initialize local copy
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  /// Called when user presses "Edit" -> Navigate to ModifyTransactionPage
  Future<void> _onEditPressed() async {
    final updatedTransaction = await Navigator.push<RestaurantCardModel>(
      context,
      MaterialPageRoute(
        builder: (context) => ModifyTransactionPage(transaction: _cardData),
      ),
    );

    // If user saved changes, 'updatedTransaction' won't be null
    if (updatedTransaction != null) {
      setState(() {
        _cardData = updatedTransaction;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardData = _cardData;
    final itemCount = cardData.items.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _toggleExpand,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // --- Collapsed Row (Restaurant, total, category, item count) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Restaurant Name
                  Expanded(
                    child: Text(
                      cardData.restaurantName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Right: total, category, item count
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'RM${cardData.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
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
                      Text(
                        '$itemCount items',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // --- Expanded Section: Items + Export Buttons + Edit Button ---
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                // A thin divider
                Container(
                  height: 1,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),

                // List of items
                Column(
                  children: cardData.items.map((item) {
                    final itemTotal = item.price * item.quantity;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Item name
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          // Price
                          Text(
                            'RM${item.price.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          // Quantity in parentheses
                          Text(
                            '(${item.quantity})',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Subtotal
                          Text(
                            'RM${itemTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                // Export buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement your Excel export
                      },
                      child: const Text('Excel file'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement your PDF export
                      },
                      child: const Text('PDF file'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement your CSV export
                      },
                      child: const Text('CSV file'),
                    ),
                  ],
                ),

                // Optional: "Edit" button below export buttons
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _onEditPressed,
                    child: const Text('Edit'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
