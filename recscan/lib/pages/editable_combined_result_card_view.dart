import 'package:flutter/material.dart';
import '../models/models.dart';
import 'package:recscan/widgets/overview/overview_transaction_card.dart';
import 'package:provider/provider.dart';
import 'package:recscan/pages/category_provider.dart';

class EditableCombinedResultCardView extends StatefulWidget {
  final List<OrderItem> orderItems;
  final String subtotal;
  final String total;
  final String discountInfo;
  final String taxInfo;
  final String serviceChargeInfo;
  final Function(List<OrderItem> updatedOrderItems, String updatedSubtotal,
      String updatedTotal) onChanged;
  final Function(List<OrderItem> finalOrderItems, String finalSubtotal,
      String finalTotal, String selectedCategory) onDone;

  const EditableCombinedResultCardView({
    super.key,
    required this.orderItems,
    required this.subtotal,
    required this.total,
    this.discountInfo = '',
    this.taxInfo = '',
    this.serviceChargeInfo = '',
    required this.onChanged,
    required this.onDone,
  });

  @override
  _EditableCombinedResultCardViewState createState() =>
      _EditableCombinedResultCardViewState();
}

class _EditableCombinedResultCardViewState
    extends State<EditableCombinedResultCardView> {
  late List<OrderItem> _orderItems;
  late TextEditingController _subtotalController;
  late TextEditingController _totalController;
  String _selectedCategory = 'Default Category';
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _orderItems = widget.orderItems
        .map((item) => OrderItem(
              name: item.name,
              price: item.price,
              quantity: item.quantity,
            ))
        .toList();

    // Initialize controllers with default values - empty to ensure we calculate our own values
    _subtotalController = TextEditingController();
    _totalController = TextEditingController();

    // Calculate totals immediately after initialization
    Future.microtask(_forceUpdateTotals);

    // Set the default category to the first category from the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categories =
          Provider.of<CategoryProvider>(context, listen: false).categories;
      if (categories.isNotEmpty) {
        setState(() {
          _selectedCategory = categories.first;
        });
      }
    });
  }

  @override
  void dispose() {
    _subtotalController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  // Force recalculation and refresh of UI
  void _forceUpdateTotals() {
    _updateTotals();
    setState(() {}); // Force rebuild
  }

  void _updateTotals() {
    // First calculate the final price for each item (with discounts, taxes, etc.)
    double subtotal = 0.0;
    double finalTotal = 0.0;
    double discountAmount = 0.0;
    double taxAmount = 0.0;
    double serviceChargeAmount = 0.0;

    // Add up the original prices for subtotal
    subtotal = _orderItems.fold(
        0.0, (sum, item) => sum + (item.price * item.quantity));

    // Apply discount if any
    double discountedTotal = subtotal;
    if (widget.discountInfo.isNotEmpty) {
      double discountPercent = _getDiscountPercent();
      discountAmount = subtotal * (discountPercent / 100);
      discountedTotal = subtotal - discountAmount;
    }

    // Start with discounted total
    finalTotal = discountedTotal;

    // Add service charge if applicable
    if (widget.serviceChargeInfo.isNotEmpty) {
      double serviceChargePercent = _getServiceChargePercent();
      serviceChargeAmount = discountedTotal * (serviceChargePercent / 100);
      finalTotal += serviceChargeAmount;
    }

    // Add tax if applicable
    if (widget.taxInfo.isNotEmpty) {
      double taxPercent = _getTaxPercent();
      taxAmount = discountedTotal * (taxPercent / 100);
      finalTotal += taxAmount;
    }

    // Debug prints to verify calculations
    print('Raw Subtotal: $subtotal');
    print('Discount: $discountAmount (${_getDiscountPercent()}%)');
    print('After Discount: $discountedTotal');
    print('Service Charge: $serviceChargeAmount');
    print('Tax Amount: $taxAmount');
    print('FINAL TOTAL: $finalTotal');

    // Update the text controllers with calculated values
    _subtotalController.text = subtotal.toStringAsFixed(2);
    _totalController.text = finalTotal.toStringAsFixed(2);

    // Notify parent of changes
    widget.onChanged(
      _orderItems,
      _subtotalController.text,
      _totalController.text,
    );
  }

  void _updateOrderItem(int index, String field, String newValue) {
    setState(() {
      if (field == 'name') {
        _orderItems[index] = OrderItem(
          name: newValue.isNotEmpty ? newValue : 'Item ${index + 1}',
          price: _orderItems[index].price,
          quantity: _orderItems[index].quantity,
        );
      } else if (field == 'price') {
        double price = double.tryParse(newValue) ?? 0.0;
        _orderItems[index] = OrderItem(
          name: _orderItems[index].name,
          price: price,
          quantity: _orderItems[index].quantity,
        );
      } else if (field == 'quantity') {
        int quantity = int.tryParse(newValue) ?? 1;
        _orderItems[index] = OrderItem(
          name: _orderItems[index].name,
          price: _orderItems[index].price,
          quantity: quantity,
        );
      }
      _forceUpdateTotals();
    });
  }

  void _deleteOrderItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
      _forceUpdateTotals();
    });
  }

  void _addOrderItem() {
    setState(() {
      _orderItems.add(OrderItem(
        name: 'Item ${_orderItems.length + 1}',
        price: 0.00,
        quantity: 1,
      ));
      _forceUpdateTotals();
    });
  }

  void _selectCategory() async {
    final categories =
        Provider.of<CategoryProvider>(context, listen: false).categories;
    final selectedCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Category'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search field for categories
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search categories...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  // TODO: Implement category search
                },
              ),
              const SizedBox(height: 16),
              // Category list
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return ListTile(
                      leading: Icon(
                        _selectedCategory == category
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: _selectedCategory == category
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      title: Text(category),
                      onTap: () => Navigator.pop(context, category),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedCategory != null) {
      setState(() {
        _selectedCategory = selectedCategory;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Receipt Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: Icon(_isEditing ? Icons.done : Icons.edit),
                  onPressed: () => setState(() => _isEditing = !_isEditing),
                ),
              ],
            ),
          ),

          // Category Selection
          ListTile(
            leading: const Icon(Icons.category),
            title: Text(_selectedCategory),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _selectCategory,
          ),

          const Divider(),

          // Items List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Add help text for deleting items
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap and hold an item to delete it',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Items Header
                if (_orderItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Item',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            'Price',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            'Qty',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        // Add header for final price (after discounts/taxes)
                        Expanded(
                          child: Text(
                            'Final',
                            style: Theme.of(context).textTheme.titleSmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Items
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _orderItems.length,
                  itemBuilder: (context, index) {
                    final item = _orderItems[index];

                    // Calculate the final price including discounts/taxes
                    double originalTotal = item.price * item.quantity;

                    // STEP 1: Apply discount first (if any)
                    double discountedPrice = originalTotal;
                    if (widget.discountInfo.isNotEmpty) {
                      double discountPercent = _getDiscountPercent();
                      discountedPrice =
                          originalTotal * (1 - discountPercent / 100);
                    }

                    // STEP 2: Calculate tax and service charge on the DISCOUNTED price
                    double finalTotal = discountedPrice;
                    double serviceChargeAmount = 0.0;
                    double taxAmount = 0.0;

                    // Apply service charge if available (on discounted price)
                    if (widget.serviceChargeInfo.isNotEmpty) {
                      double serviceChargePercent = _getServiceChargePercent();
                      serviceChargeAmount =
                          discountedPrice * (serviceChargePercent / 100);
                      finalTotal += serviceChargeAmount;
                    }

                    // Apply tax if available (on discounted price)
                    if (widget.taxInfo.isNotEmpty) {
                      double taxPercent = _getTaxPercent();
                      taxAmount = discountedPrice * (taxPercent / 100);
                      finalTotal += taxAmount;
                    }

                    // Replace Row with GestureDetector for long-press to delete
                    return GestureDetector(
                      onLongPress: () {
                        // Show confirmation dialog before deleting
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Delete Item"),
                              content: Text(
                                  "Do you want to delete the item '${item.name}'?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _deleteOrderItem(index);
                                  },
                                  child: const Text("Delete",
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      // Add onTap handler to show calculation details
                      onTap: () {
                        if (!_isEditing && (finalTotal != originalTotal)) {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(item.name),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Calculation Breakdown:'),
                                    const SizedBox(height: 8),
                                    Table(
                                      columnWidths: const {
                                        0: FlexColumnWidth(3),
                                        1: FlexColumnWidth(2),
                                      },
                                      children: [
                                        TableRow(
                                          children: [
                                            Text('Original Price:'),
                                            Text(
                                                'RM${item.price.toStringAsFixed(2)}'),
                                          ],
                                        ),
                                        TableRow(
                                          children: [
                                            Text('Quantity:'),
                                            Text('${item.quantity}'),
                                          ],
                                        ),
                                        TableRow(
                                          children: [
                                            Text('Original Total:'),
                                            Text(
                                                'RM${originalTotal.toStringAsFixed(2)}'),
                                          ],
                                        ),
                                        if (discountedPrice != originalTotal)
                                          TableRow(
                                            children: [
                                              Text(
                                                  'Discount (${_getDiscountPercent().toStringAsFixed(1)}%):'),
                                              Text(
                                                  '-RM${(originalTotal - discountedPrice).toStringAsFixed(2)}'),
                                            ],
                                          ),
                                        TableRow(
                                          children: [
                                            Text('After Discount:'),
                                            Text(
                                                'RM${discountedPrice.toStringAsFixed(2)}'),
                                          ],
                                        ),
                                        if (serviceChargeAmount > 0)
                                          TableRow(
                                            children: [
                                              Text(
                                                  'Service (${_getServiceChargePercent().toStringAsFixed(1)}%):'),
                                              Text(
                                                  '+RM${serviceChargeAmount.toStringAsFixed(2)}'),
                                            ],
                                          ),
                                        if (taxAmount > 0)
                                          TableRow(
                                            children: [
                                              Text(
                                                  'Tax (${_getTaxPercent().toStringAsFixed(1)}%):'),
                                              Text(
                                                  '+RM${taxAmount.toStringAsFixed(2)}'),
                                            ],
                                          ),
                                        TableRow(
                                          children: [
                                            const Text('Final Total:',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            Text(
                                                'RM${finalTotal.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text("Close"),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: Colors.grey.shade300, width: 1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _isEditing
                                      ? TextFormField(
                                          initialValue: item.name,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 8),
                                            hintText: 'Item name',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onChanged: (value) =>
                                              _updateOrderItem(
                                                  index, 'name', value),
                                        )
                                      : Text(
                                          item.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  child: _isEditing
                                      ? TextFormField(
                                          initialValue: item.price.toString(),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 8),
                                            prefixText: 'RM',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) =>
                                              _updateOrderItem(
                                                  index, 'price', value),
                                        )
                                      : Text(
                                          'RM${item.price.toStringAsFixed(2)}'),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 60,
                                  child: _isEditing
                                      ? TextFormField(
                                          initialValue:
                                              item.quantity.toString(),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 8),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) =>
                                              _updateOrderItem(
                                                  index, 'quantity', value),
                                        )
                                      : Text(item.quantity.toString()),
                                ),
                                // Display the final price after discounts/taxes
                                Expanded(
                                  child: Text(
                                    'RM${finalTotal.toStringAsFixed(2)}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: finalTotal < originalTotal
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Show calculation information if there's a difference between original and final
                            if (finalTotal != originalTotal && !_isEditing)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (discountedPrice != originalTotal)
                                      Text(
                                        'Discount: -RM${(originalTotal - discountedPrice).toStringAsFixed(2)} (${_getDiscountPercent().toStringAsFixed(1)}%)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Final: RM${finalTotal.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.end,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.info_outline,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Add Item Button
                if (_isEditing)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ElevatedButton.icon(
                      onPressed: _addOrderItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(),

          // Totals Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal'),
                    Text(
                      'RM${_subtotalController.text}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'RM${_totalController.text}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Discount and Tax Information
          _buildDiscountAndTaxInfo(),

          // Done Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                // Force one final update before sending data to parent
                _forceUpdateTotals();

                widget.onDone(
                  _orderItems,
                  _subtotalController.text,
                  _totalController.text,
                  _selectedCategory,
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Receipt'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountAndTaxInfo() {
    return Column(
      children: [
        if (widget.discountInfo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Discount ${_getDiscountPercent().toStringAsFixed(1)}%: -RM${(_calculateSubtotal() * _getDiscountPercent() / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (widget.serviceChargeInfo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.serviceChargeInfo,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        if (widget.taxInfo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.taxInfo,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Helper method to calculate subtotal
  double _calculateSubtotal() {
    return _orderItems.fold(
        0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  // Add helper method to extract discount percentage
  double _getDiscountPercent() {
    if (widget.discountInfo.isEmpty) return 0.0;
    if (!widget.discountInfo.contains('%')) return 0.0;

    try {
      // Extract the percentage value from the discount info string
      final percentMatch =
          RegExp(r'(\d+\.?\d*)%').firstMatch(widget.discountInfo);
      if (percentMatch != null) {
        return double.tryParse(percentMatch.group(1) ?? '0') ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // Add helper methods for tax and service charge if needed
  double _getTaxPercent() {
    if (widget.taxInfo.isEmpty) return 0.0;
    if (!widget.taxInfo.contains('%')) return 0.0;

    try {
      final percentMatch = RegExp(r'(\d+\.?\d*)%').firstMatch(widget.taxInfo);
      if (percentMatch != null) {
        return double.tryParse(percentMatch.group(1) ?? '0') ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  double _getServiceChargePercent() {
    if (widget.serviceChargeInfo.isEmpty) return 0.0;
    if (!widget.serviceChargeInfo.contains('%')) return 0.0;

    try {
      final percentMatch =
          RegExp(r'(\d+\.?\d*)%').firstMatch(widget.serviceChargeInfo);
      if (percentMatch != null) {
        return double.tryParse(percentMatch.group(1) ?? '0') ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }
}
