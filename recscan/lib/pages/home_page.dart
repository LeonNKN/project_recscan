import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'category_provider.dart';
import 'scan_page.dart' as scan_page;
import 'package:recscan/widgets/overview/overview_header.dart';
import 'package:recscan/widgets/overview/overview_transaction_card.dart';
import 'search_page.dart';
import 'categorypage.dart';
import '../models/models.dart' as models;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, child) {
        final allCards = provider.restaurantCards;

        return Scaffold(
          appBar: AppBar(
            title: const Text('RecScan'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _openSearchPage(context, allCards),
              ),
              IconButton(
                icon: const Icon(Icons.category),
                onPressed: () => _openCategoryPage(context),
              ),
            ],
          ),
          body: Column(
            children: [
              // Overview Header
              OverviewHeader(
                onDropdownChanged: (newPeriod) {
                  // TODO: Implement period filtering
                },
              ),

              // Category Overview Cards
              Container(
                height: 120,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.categories.length,
                  itemBuilder: (context, index) {
                    final category = provider.categories[index];
                    final categoryCards = provider.getCardsByCategory(category);
                    final totalAmount = categoryCards.fold(
                      0.0,
                      (sum, card) => sum + card.total,
                    );

                    return Card(
                      margin: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          provider.setSelectedCategory(category);
                          _openCategoryPage(context);
                        },
                        child: Container(
                          width: 140,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'RM${totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${categoryCards.length} items',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Recent Transactions
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openCategoryPage(context),
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ),

              // Transactions List
              Expanded(
                child: allCards.isEmpty
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
                              'No receipts yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the camera button to scan a receipt',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: allCards.length,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemBuilder: (context, index) {
                          final card = allCards[index];
                          return ExpandableRestaurantCard(
                            data: TransactionCardModel(
                              id: card.id,
                              restaurantName: card.restaurantName,
                              dateTime: card.dateTime,
                              subtotal: card.subtotal,
                              total: card.total,
                              category: card.category,
                              categoryColor: card.categoryColor,
                              iconColor: card.iconColor,
                              items: card.items,
                            ),
                            onLongPress: () =>
                                _showDeleteConfirmationDialog(context, card),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openScanPage(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => scan_page.ScanPage()),
    );
    if (result != null && result is models.RestaurantCardModel) {
      Provider.of<CategoryProvider>(context, listen: false)
          .addRestaurantCard(result);
    }
  }

  void _openSearchPage(
      BuildContext context, List<models.RestaurantCardModel> cards) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchPage(allCards: cards),
      ),
    );
  }

  void _openCategoryPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoryPage(),
      ),
    );
  }

  void _showEditTransactionDialog(
      BuildContext context, models.RestaurantCardModel card) {
    final nameController = TextEditingController(text: card.restaurantName);
    String selectedCategory = card.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Consumer<CategoryProvider>(
        builder: (context, provider, child) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Transaction',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Restaurant Name',
                      border: OutlineInputBorder(),
                    ),
                    controller: nameController,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedCategory,
                    items: provider.categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        selectedCategory = value;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Update the transaction details
                          provider.updateTransactionName(
                              card.id, nameController.text);
                          provider.updateTransactionCategory(
                              card.id, selectedCategory);
                          Navigator.pop(context);
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, models.RestaurantCardModel card) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Transaction'),
          content: Text(
              'Are you sure you want to delete the transaction from ${card.restaurantName}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Provider.of<CategoryProvider>(context, listen: false)
                    .deleteRestaurantCard(card.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Transaction deleted'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () {
                        Provider.of<CategoryProvider>(context, listen: false)
                            .addRestaurantCard(card);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
