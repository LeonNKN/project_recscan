import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'category_provider.dart';
import 'scan_page.dart' as scan_page;
import 'package:recscan/widgets/overview/overview_header.dart';
import 'package:recscan/widgets/overview/overview_transaction_card.dart';
import 'search_page.dart';
import 'categorypage.dart';

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
                height: 100,
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
                          width: 160,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'RM${totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
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
                padding: const EdgeInsets.all(16),
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
                          return ExpandableRestaurantCard(
                            data: allCards[index],
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openScanPage(context),
            child: const Icon(Icons.camera_alt),
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
    if (result != null && result is RestaurantCardModel) {
      Provider.of<CategoryProvider>(context, listen: false)
          .addRestaurantCard(result);
    }
  }

  void _openSearchPage(BuildContext context, List<RestaurantCardModel> cards) {
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
}
