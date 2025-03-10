import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'category_provider.dart';
import 'scan_page.dart' as scan_page;
import 'package:recscan/widgets/overview/overview_transaction_card.dart';

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
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (_) =>
                            provider.setSelectedCategory(category),
                      ),
                    );
                  },
                ),
              ),

              // Cards List
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
                              'No receipts in ${provider.selectedCategory}',
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
                            data: cards[index],
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
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                provider.addCategory(name);
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Categories'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: provider.categories.length,
            itemBuilder: (context, index) {
              final category = provider.categories[index];
              return ListTile(
                title: Text(category),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: provider.categories.length > 1
                      ? () {
                          provider.deleteCategory(category);
                          Navigator.pop(context);
                        }
                      : null,
                ),
                onTap: () => _showRenameCategoryDialog(
                  context,
                  provider,
                  category,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showRenameCategoryDialog(
    BuildContext context,
    CategoryProvider provider,
    String oldCategory,
  ) {
    final controller = TextEditingController(text: oldCategory);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldCategory) {
                provider.editCategory(oldCategory, newName);
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}
