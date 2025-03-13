import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'category_provider.dart';
import 'scan_page.dart' as scan_page;
import '../models/models.dart';
import '../widgets/overview/overview_transaction_card.dart'
    hide RestaurantCardModel;

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, child) {
        final cards = provider.getCardsByCategory(provider.selectedCategory);

        return Scaffold(
          appBar: AppBar(
            title: Text(provider.selectedCategory),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showAddCategoryDialog(context, provider),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditCategoryDialog(context, provider),
              ),
            ],
          ),
          body: Column(
            children: [
              // Category Selection
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.categories.length,
                  itemBuilder: (context, index) {
                    final category = provider.categories[index];
                    final isSelected = category == provider.selectedCategory;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            provider.setSelectedCategory(category);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),

              // Transactions List
              Expanded(
                child: cards.isEmpty
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
                              'No transactions in this category',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: cards.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          return ExpandableRestaurantCard(
                            data: TransactionCardModel(
                              id: cards[index].id,
                              restaurantName: cards[index].restaurantName,
                              dateTime: cards[index].dateTime,
                              subtotal: cards[index].subtotal,
                              total: cards[index].total,
                              category: cards[index].category,
                              categoryColor: cards[index].categoryColor,
                              iconColor: cards[index].iconColor,
                              items: cards[index].items,
                            ),
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
    if (result != null && result is RestaurantCardModel) {
      Provider.of<CategoryProvider>(context, listen: false)
          .addRestaurantCard(result);
    }
  }

  void _showAddCategoryDialog(BuildContext context, CategoryProvider provider) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Entertainment',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.addCategory(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(
      BuildContext context, CategoryProvider provider) {
    final controller = TextEditingController(text: provider.selectedCategory);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Entertainment',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.editCategory(
                    provider.selectedCategory, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
