import 'package:flutter/material.dart';
import '../models/models.dart';
import 'package:recscan/widgets/overview/overview_transaction_card.dart';
import 'package:provider/provider.dart';
import 'package:recscan/pages/category_provider.dart';

class EditableCombinedResultCardView extends StatefulWidget {
  final List<OrderItem> orderItems;
  final String subtotal;
  final String total;
  final Function(List<OrderItem> updatedOrderItems, String updatedSubtotal,
      String updatedTotal) onChanged;
  final Function(List<OrderItem> finalOrderItems, String finalSubtotal,
      String finalTotal, String selectedCategory) onDone;

  const EditableCombinedResultCardView({
    super.key,
    required this.orderItems,
    required this.subtotal,
    required this.total,
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
    _subtotalController = TextEditingController(text: widget.subtotal);
    _totalController = TextEditingController(text: widget.total);

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
      _updateTotals();
    });
  }

  void _updateTotals() {
    double subtotal =
        _orderItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
    _subtotalController.text = subtotal.toStringAsFixed(2);
    _totalController.text = subtotal.toStringAsFixed(2);

    widget.onChanged(
      _orderItems,
      _subtotalController.text,
      _totalController.text,
    );
  }

  void _deleteOrderItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
      _updateTotals();
    });
  }

  void _addOrderItem() {
    setState(() {
      _orderItems.add(OrderItem(
        name: 'Item ${_orderItems.length + 1}',
        price: 0.00,
        quantity: 1,
      ));
      _updateTotals();
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
                        const SizedBox(width: 40),
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
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
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
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onChanged: (value) =>
                                        _updateOrderItem(index, 'name', value),
                                  )
                                : Text(item.name),
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
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) =>
                                        _updateOrderItem(index, 'price', value),
                                  )
                                : Text('RM${item.price.toStringAsFixed(2)}'),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: _isEditing
                                ? TextFormField(
                                    initialValue: item.quantity.toString(),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) => _updateOrderItem(
                                        index, 'quantity', value),
                                  )
                                : Text(item.quantity.toString()),
                          ),
                          if (_isEditing)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteOrderItem(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
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

          // Done Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
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
}
