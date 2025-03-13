import 'package:flutter/material.dart';
import '../models/models.dart';

class CreateReportPage extends StatefulWidget {
  final List<ReceiptModel> allReceipts;

  const CreateReportPage({super.key, required this.allReceipts});

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

          // 2) List of receipts to select from
          Expanded(
            child: ListView.builder(
              itemCount: widget.allReceipts.length,
              itemBuilder: (context, index) {
                final receipt = widget.allReceipts[index];
                final isSelected = _selectedIds.contains(receipt.id);

                return ListTile(
                  title: Text(receipt.restaurantName),
                  subtitle: Text(
                    '${receipt.dateTime.day}/${receipt.dateTime.month}/${receipt.dateTime.year}',
                  ),
                  trailing: Text('RM${receipt.total.toStringAsFixed(2)}'),
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(receipt.id);
                        } else {
                          _selectedIds.remove(receipt.id);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),

          // 3) Save button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _selectedIds.isEmpty ? null : _saveReport,
              child: const Text('Create Report'),
            ),
          ),
        ],
      ),
    );
  }

  void _saveReport() {
    // Build a new ReportModel
    final selectedReceipts =
        widget.allReceipts.where((r) => _selectedIds.contains(r.id)).toList();

    final newReport = ReportModel(
      id: DateTime.now().millisecondsSinceEpoch,
      title: _titleController.text.trim(),
      receipts: selectedReceipts,
    );

    // Return it to the previous page
    Navigator.pop(context, newReport);
  }
}
