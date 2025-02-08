import 'package:flutter/material.dart';
import 'item_row.dart';

class CombinedResultCardView extends StatelessWidget {
  final List<ItemRow> itemRows;
  final String total;

  const CombinedResultCardView({
    Key? key,
    required this.itemRows,
    required this.total,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row.
            Row(
              children: const [
                Expanded(
                    child: Text('Item',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    child: Text('Price',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    child: Text('Qty',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    child: Text('Sub Price',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            const Divider(),
            // List of rows.
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itemRows.length,
              itemBuilder: (context, index) {
                final row = itemRows[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(child: Text(row.item)),
                      Expanded(child: Text(row.price)),
                      Expanded(child: Text(row.quantity)),
                      Expanded(child: Text(row.subPrice)),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
            // Display the overall total.
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "Total: $total",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
