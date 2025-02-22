import 'package:flutter/material.dart';
// Import your ModifyTransactionPage
import 'package:recscan/pages/modify_transaction_page.dart';

// Models
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _toggleExpand,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // --- Header Row ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Icon / Colored Box
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cardData.iconColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Restaurant Name, Date/Time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cardData.restaurantName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          // e.g. "19/03/2025, 16:32"
                          '${cardData.dateTime.day.toString().padLeft(2, '0')}/'
                          '${cardData.dateTime.month.toString().padLeft(2, '0')}/'
                          '${cardData.dateTime.year}, '
                          '${cardData.dateTime.hour.toString().padLeft(2, '0')}:'
                          '${cardData.dateTime.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Amount + Category Chip
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
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cardData.categoryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          cardData.category,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // --- Expandable Section ---
              if (_isExpanded) ...[
                const SizedBox(height: 8),
                Container(
                  height: 2,
                  color: Colors.black12,
                ),
                const SizedBox(height: 8),

                // Show each OrderItem
                ...cardData.items.map((item) {
                  final itemTotal = item.price * item.quantity;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        // Left side: item name, then price + quantity
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'RM${item.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'RM${itemTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _onEditPressed, // <--- Navigates to Modify
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
