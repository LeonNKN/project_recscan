import 'package:flutter/material.dart';
import 'package:recscan/widgets/overview/overview_transaction_card.dart';

class CreateReportPage extends StatefulWidget {
  final List<ReceiptModel> allReceipts;

  const CreateReportPage({Key? key, required this.allReceipts})
      : super(key: key);

  @override
  _CreateReportPageState createState() => _CreateReportPageState();
}

class _CreateReportPageState extends State<CreateReportPage> {
  final TextEditingController _titleController = TextEditingController();
  final Set<int> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Report'),
      ),
      body: Column(
        children: [
          // 1) A text field for naming the report
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Report Title',
                hintText: 'e.g. March Expenses',
              ),
            ),
          ),

          // 2) A list of all receipts that can be selected
          Expanded(
            child: ListView.builder(
              itemCount: widget.allReceipts.length,
              itemBuilder: (context, index) {
                final receipt = widget.allReceipts[index];
                final isSelected = _selectedIds.contains(receipt.id);
                return ListTile(
                  onTap: () {
                    setState(() {
                      isSelected
                          ? _selectedIds.remove(receipt.id)
                          : _selectedIds.add(receipt.id);
                    });
                  },
                  leading: Icon(
                    isSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: isSelected ? Colors.blue : null,
                  ),
                  title: Text(receipt.restaurantName),
                  subtitle: Text('RM${receipt.total.toStringAsFixed(2)}'),
                );
              },
            ),
          ),

          // 3) "Save" button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: ElevatedButton(
              onPressed: _onSave,
              child: const Text('Save Report'),
            ),
          ),
        ],
      ),
    );
  }

  void _onSave() {
    // If nothing is selected, or no title is given, you could handle that here
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one receipt.')),
      );
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a report title.')),
      );
      return;
    }

    // Build a new ReportModel
    final selectedReceipts =
        widget.allReceipts.where((r) => _selectedIds.contains(r.id)).toList();

    final newReport = ReportModel(
      id: DateTime.now().millisecondsSinceEpoch, // or use a real ID generator
      title: _titleController.text.trim(),
      receipts: selectedReceipts,
    );

    // Return it to the previous page
    Navigator.pop(context, newReport);
  }
}
