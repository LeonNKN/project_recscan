import 'package:flutter/material.dart';
import 'package:recscan/widgets/overview/overview_transaction_card.dart';
import 'create_record_page.dart';
import 'package:provider/provider.dart';
import 'category_provider.dart';
import '../models/models.dart' as models;

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  _ReportPageState createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  // List of existing "Reports" that user created
  final List<models.ReportModel> _reports = [];

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, child) {
        final allTransactions = provider.restaurantCards;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Reports'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _onCreateNewReport(context, allTransactions),
                tooltip: 'Create New Report',
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Reports List
                if (_reports.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No reports yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () =>
                                _onCreateNewReport(context, allTransactions),
                            child: const Text('Create New Report'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final report = _reports[index];
                        return _buildReportTile(report);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build one card for each report with an ExpansionTile
  Widget _buildReportTile(models.ReportModel report) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        title: Text(
          report.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${report.receipts.length} receipt(s)',
          style: const TextStyle(fontSize: 14),
        ),
        children: [
          // Show each receipt that belongs to this report
          ...report.receipts.map((receipt) {
            return ListTile(
              title: Text(receipt.restaurantName),
              subtitle: Text(
                '${receipt.dateTime.day}/${receipt.dateTime.month}/${receipt.dateTime.year}',
              ),
              trailing: Text('RM${receipt.total.toStringAsFixed(2)}'),
              onTap: () {
                // TODO: Show receipt details
              },
            );
          }),

          // Add some spacing before the export buttons
          const SizedBox(height: 8),

          // Row of export buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _exportExcel(report),
                icon: const Icon(Icons.grid_on),
                label: const Text('Excel'),
              ),
              ElevatedButton.icon(
                onPressed: () => _exportPDF(report),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF'),
              ),
              ElevatedButton.icon(
                onPressed: () => _exportCSV(report),
                icon: const Icon(Icons.table_chart),
                label: const Text('CSV'),
              ),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Called when user taps "Create New Report"
  Future<void> _onCreateNewReport(BuildContext context,
      List<models.RestaurantCardModel> allTransactions) async {
    // Push a new page where user can pick receipts
    final newReport = await Navigator.push<models.ReportModel>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateReportPage(
          allReceipts: allTransactions
              .map((transaction) => models.ReceiptModel(
                    id: transaction.id,
                    restaurantName: transaction.restaurantName,
                    dateTime: transaction.dateTime,
                    total: transaction.total,
                  ))
              .toList(),
        ),
      ),
    );

    // If user actually created a report (not cancelled)
    if (newReport != null) {
      setState(() {
        _reports.add(newReport);
      });
    }
  }

  /// Dummy export functions
  void _exportExcel(models.ReportModel report) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting report "${report.title}" to Excel...')),
    );
  }

  void _exportPDF(models.ReportModel report) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting report "${report.title}" to PDF...')),
    );
  }

  void _exportCSV(models.ReportModel report) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting report "${report.title}" to CSV...')),
    );
  }
}
