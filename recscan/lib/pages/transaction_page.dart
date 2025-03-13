import 'package:flutter/material.dart';
import '../models/models.dart';
import 'package:provider/provider.dart';
import 'category_provider.dart';

class TransactionPage extends StatelessWidget {
  const TransactionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, child) {
        final allCards = provider.restaurantCards;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Transactions'),
          ),
          body: allCards.isEmpty
              ? Center(
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
                        'No transactions yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: allCards.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(allCards[index].restaurantName),
                        subtitle: Text(
                          '${allCards[index].dateTime.day}/${allCards[index].dateTime.month}/${allCards[index].dateTime.year}',
                        ),
                        trailing: Text(
                          'RM${allCards[index].total.toStringAsFixed(2)}',
                        ),
                        onTap: () {
                          // TODO: Show transaction details
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
