// editable_combined_result_card_view.dart
import 'package:flutter/material.dart';
import 'item_row.dart';

class EditableCombinedResultCardView extends StatefulWidget {
  final List<ItemRow> itemRows;
  final String total;
  final Function(List<ItemRow> updatedRows, String updatedTotal) onChanged;
  final Function(List<ItemRow> finalRows, String finalTotal)
      onDone; // Add this parameter

  const EditableCombinedResultCardView({
    Key? key,
    required this.itemRows,
    required this.total,
    required this.onChanged,
    required this.onDone, // And require it in the constructor
  }) : super(key: key);

  @override
  _EditableCombinedResultCardViewState createState() =>
      _EditableCombinedResultCardViewState();
}

class _EditableCombinedResultCardViewState
    extends State<EditableCombinedResultCardView> {
  late List<ItemRow> _rows;
  late TextEditingController _totalController;

  @override
  void initState() {
    super.initState();
    _rows = widget.itemRows
        .map((row) => ItemRow(
              item: row.item,
              price: row.price,
              quantity: row.quantity,
              subPrice: row.subPrice,
              isUserAdded: row.isUserAdded,
            ))
        .toList();
    _totalController = TextEditingController(text: widget.total);
  }

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  void _updateRow(int index, String field, String newValue) {
    setState(() {
      if (field == 'item') {
        _rows[index].item = newValue.isNotEmpty ? newValue : 'PLACEHOLDER';
      } else if (field == 'price') {
        _rows[index].price = newValue.isNotEmpty ? newValue : '0.00';
      } else if (field == 'quantity') {
        _rows[index].quantity = newValue.isNotEmpty ? newValue : '1';
      } else if (field == 'subPrice') {
        _rows[index].subPrice = newValue.isNotEmpty ? newValue : '0.00';
      }
      double price = double.tryParse(_rows[index].price) ?? 0.0;
      int qty = int.tryParse(_rows[index].quantity) ?? 1;
      _rows[index].subPrice = (price * qty).toStringAsFixed(2);
      widget.onChanged(_rows, _totalController.text);
    });
  }

  void _deleteRow(int index) {
    setState(() {
      _rows.removeAt(index);
      widget.onChanged(_rows, _totalController.text);
    });
  }

  void _addRow() {
    setState(() {
      _rows.add(ItemRow(
        item: 'PLACEHOLDER',
        price: '0.00',
        quantity: '1',
        subPrice: '0.00',
        isUserAdded: true,
      ));
      widget.onChanged(_rows, _totalController.text);
    });
  }

  Widget _buildEditableRow(int index) {
    final row = _rows[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              initialValue: row.item,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Item',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              ),
              onChanged: (value) => _updateRow(index, 'item', value),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextFormField(
              initialValue: row.price,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Price',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => _updateRow(index, 'price', value),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextFormField(
              initialValue: row.quantity,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Qty',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => _updateRow(index, 'quantity', value),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextFormField(
              initialValue: row.subPrice,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Sub Price',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => _updateRow(index, 'subPrice', value),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 16),
            onPressed: () => _deleteRow(index),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header row.
            Row(
              children: const [
                Expanded(
                    child: Text('Item',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(
                    child: Text('Price',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(
                    child: Text('Qty',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(
                    child: Text('Sub Price',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 24),
              ],
            ),
            const Divider(),
            // Editable rows.
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rows.length,
              itemBuilder: (context, index) => _buildEditableRow(index),
            ),
            // Add Row button.
            TextButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Row', style: TextStyle(fontSize: 12)),
            ),
            const Divider(),
            // Editable total field.
            TextFormField(
              controller: _totalController,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Total',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                widget.onChanged(_rows, value);
              },
            ),
            // DONE button to export final result.
            ElevatedButton(
              onPressed: () {
                widget.onDone(_rows, _totalController.text);
              },
              child: const Text('DONE', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
