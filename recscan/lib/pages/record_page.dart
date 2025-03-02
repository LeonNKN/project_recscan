import 'package:flutter/material.dart';
import 'package:recscan/widgets/overview/overview_transaction_card.dart';
import 'create_record_page.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({Key? key}) : super(key: key);

  @override
  _ReportPageState createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  // List of existing "Reports" that user created
  final List<ReportModel> _reports = [];

  // Hardcoded list of receipts (replace with your real data fetching)
  final List<ReceiptModel> _allReceipts = [
    ReceiptModel(
      id: 1001,
      restaurantName: 'KAYU RESTAURANT',
      dateTime: DateTime(2025, 3, 19, 16, 32),
      total: 100.00,
    ),
    ReceiptModel(
      id: 1002,
      restaurantName: 'City Utility',
      dateTime: DateTime(2025, 4, 2, 10, 0),
      total: 60.0,
    ),
    ReceiptModel(
      id: 1003,
      restaurantName: 'Groceries Store',
      dateTime: DateTime(2025, 5, 1, 18, 15),
      total: 75.50,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Simple AppBar with back button
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Report'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Create New Report button
            ElevatedButton(
              onPressed: _onCreateNewReport,
              child: const Text('Create New Report'),
            ),
            const SizedBox(height: 16),

            // If no reports, show placeholder
            if (_reports.isEmpty)
              const Text(
                'No reports yet. Tap "Create New Report" to get started.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              )
            else
              // Otherwise, list them
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
  }

  /// Build one card for each report with an ExpansionTile
  Widget _buildReportTile(ReportModel report) {
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
          ...report.receipts.map((r) {
            return ListTile(
              title: Text(r.restaurantName),
              trailing: Text('RM${r.total.toStringAsFixed(2)}'),
            );
          }).toList(),

          // Add some spacing before the export buttons
          const SizedBox(height: 8),

          // Row of export buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _exportExcel(report),
                icon: const Icon(Icons.grid_on), // or any icon you prefer
                label: const Text('Excel file'),
              ),
              ElevatedButton.icon(
                onPressed: () => _exportPDF(report),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF file'),
              ),
              ElevatedButton.icon(
                onPressed: () => _exportCSV(report),
                icon: const Icon(Icons.table_chart),
                label: const Text('CSV file'),
              ),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Called when user taps "Create New Report"
  Future<void> _onCreateNewReport() async {
    // Push a new page where user can pick receipts
    final newReport = await Navigator.push<ReportModel>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateReportPage(allReceipts: _allReceipts),
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
  void _exportExcel(ReportModel report) {
    // TODO: Implement Excel export logic
    debugPrint('Exporting report "${report.title}" to Excel...');
  }

  void _exportPDF(ReportModel report) {
    // TODO: Implement PDF export logic
    debugPrint('Exporting report "${report.title}" to PDF...');
  }

  void _exportCSV(ReportModel report) {
    // TODO: Implement CSV export logic
    debugPrint('Exporting report "${report.title}" to CSV...');
  }
}
