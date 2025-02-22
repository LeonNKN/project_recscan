import 'package:flutter/material.dart';
import 'package:recscan/widgets/overview/overview_transaction_card.dart';

class ModifyTransactionPage extends StatefulWidget {
  final RestaurantCardModel transaction;

  const ModifyTransactionPage({Key? key, required this.transaction})
      : super(key: key);

  @override
  _ModifyTransactionPageState createState() => _ModifyTransactionPageState();
}

class _ModifyTransactionPageState extends State<ModifyTransactionPage> {
  late TextEditingController _restaurantNameController;
  late DateTime _selectedDate;
  late String _selectedCategory;

  // We'll store a mutable list of items so we can edit them
  late List<_EditableOrderItem> _editableItems;

  @override
  void initState() {
    super.initState();

    _restaurantNameController =
        TextEditingController(text: widget.transaction.restaurantName);

    _selectedDate = widget.transaction.dateTime;
    _selectedCategory = widget.transaction.category;

    // Convert each OrderItem into a local editable model
    _editableItems = widget.transaction.items.map((item) {
      return _EditableOrderItem(
        nameController: TextEditingController(text: item.name),
        priceController: TextEditingController(text: item.price.toString()),
        quantityController:
            TextEditingController(text: item.quantity.toString()),
      );
    }).toList();
  }

  @override
  void dispose() {
    _restaurantNameController.dispose();
    for (final e in _editableItems) {
      e.nameController.dispose();
      e.priceController.dispose();
      e.quantityController.dispose();
    }
    super.dispose();
  }

  /// Calculate the sum of all (price * quantity) in the current editable items
  double get _calculatedTotal {
    double total = 0.0;
    for (final e in _editableItems) {
      final price = double.tryParse(e.priceController.text) ?? 0.0;
      final quantity = int.tryParse(e.quantityController.text) ?? 0;
      total += price * quantity;
    }
    return total;
  }

  /// When user taps "Save" or "Update," we construct a new RestaurantCardModel
  /// with updated fields. Then we pop with that new model as the result.
  void _onSave() {
    // Build updated OrderItems
    final updatedItems = _editableItems.map((e) {
      final price = double.tryParse(e.priceController.text) ?? 0.0;
      final quantity = int.tryParse(e.quantityController.text) ?? 0;
      return OrderItem(
        name: e.nameController.text,
        price: price,
        quantity: quantity,
      );
    }).toList();

    final updatedTransaction = RestaurantCardModel(
      id: widget.transaction.id,
      restaurantName: _restaurantNameController.text,
      dateTime: _selectedDate,
      total: _calculatedTotal,
      category: _selectedCategory,
      categoryColor: widget.transaction.categoryColor,
      iconColor: widget.transaction.iconColor,
      items: updatedItems,
    );

    Navigator.pop(context, updatedTransaction);
  }

  /// Example method to change date/time (you can open a DatePicker)
  void _pickDate() async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (newDate != null) {
      setState(() {
        _selectedDate = DateTime(
          newDate.year,
          newDate.month,
          newDate.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  /// Example method to change category (could be a dropdown or dialog)
  void _pickCategory() async {
    final categories = ['Shopping', 'Utility', 'Food', 'Travel'];
    final newCategory = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Pick a Category'),
        children: categories.map((cat) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, cat),
            child: Text(cat),
          );
        }).toList(),
      ),
    );
    if (newCategory != null) {
      setState(() {
        _selectedCategory = newCategory;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateString = '${_selectedDate.day.toString().padLeft(2, '0')}/'
        '${_selectedDate.month.toString().padLeft(2, '0')}/'
        '${_selectedDate.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modify Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Center(
              child: Text(
                'MODIFY TRANSACTION',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Time + Date, Category in a row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Time + Date button
                ElevatedButton(
                  onPressed: _pickDate,
                  child: Text('Time + Date\n($dateString)',
                      textAlign: TextAlign.center),
                ),
                // Category button
                ElevatedButton(
                  onPressed: _pickCategory,
                  child: Text('Category\n($_selectedCategory)',
                      textAlign: TextAlign.center),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Restaurant Name
            Center(
              child: TextField(
                controller: _restaurantNameController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Restaurant Name',
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Table header row (Name, Qty, Price)
            Container(
              color: Colors.grey[300],
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: const [
                  Expanded(
                    flex: 3,
                    child: Text('Item Name',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text('Qty',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text('Price',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Editable items
            ..._editableItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: index == _editableItems.length - 1
                          ? Colors.transparent
                          : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Item Name
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: item.nameController,
                        decoration: const InputDecoration(
                          hintText: 'Item name',
                          isDense: true,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    // Quantity
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: item.quantityController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          hintText: 'Qty',
                          isDense: true,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    // Price
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: item.priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.end,
                        decoration: const InputDecoration(
                          hintText: 'Price',
                          isDense: true,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 16),

            // TOTAL row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'TOTAL  ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'RM${_calculatedTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Save Button
            Center(
              child: ElevatedButton(
                onPressed: _onSave,
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small helper class to hold editable fields for an OrderItem
class _EditableOrderItem {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController quantityController;

  _EditableOrderItem({
    required this.nameController,
    required this.priceController,
    required this.quantityController,
  });
}
