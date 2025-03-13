import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'category_provider.dart';

class SettingsPage extends StatefulWidget {
  final String settingOption;

  const SettingsPage({super.key, required this.settingOption});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late CategoryProvider _categoryProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _categoryProvider = Provider.of<CategoryProvider>(context);
    // Safely set the selected category
    if (_categoryProvider.categories.isNotEmpty) {
      _categoryProvider.setSelectedCategory(
        _categoryProvider.categories.contains(widget.settingOption)
            ? widget.settingOption
            : _categoryProvider.categories.first,
      );
    }
  }

  /// Opens a dialog to add a new category with user feedback.
  void _addNewCategory(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newCategory = controller.text.trim();
              if (newCategory.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Category name cannot be empty')),
                );
              } else if (_categoryProvider.categories.contains(newCategory)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Category already exists')),
                );
              } else {
                _categoryProvider.addCategory(newCategory);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  /// Opens a dialog to edit or delete an existing category with confirmation and feedback.
  void _editCategoryName(BuildContext context, String oldName) {
    final TextEditingController controller =
        TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          // Delete button with confirmation
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _categoryProvider.categories.length > 1
                ? () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Deletion'),
                        content:
                            Text('Are you sure you want to delete "$oldName"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _categoryProvider.deleteCategory(oldName);
                              // Ensure selected category is valid after deletion
                              if (_categoryProvider.selectedCategory ==
                                      oldName &&
                                  _categoryProvider.categories.isNotEmpty) {
                                _categoryProvider.setSelectedCategory(
                                    _categoryProvider.categories.first);
                              }
                              Navigator.pop(
                                  context); // Close confirmation dialog
                              Navigator.pop(context); // Close edit dialog
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  }
                : null, // Disable button if only one category remains
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Category name cannot be empty')),
                );
              } else if (newName != oldName &&
                  _categoryProvider.categories.contains(newName)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Category already exists')),
                );
              } else if (newName != oldName) {
                _categoryProvider.editCategory(oldName, newName);
                Navigator.pop(context);
              } else {
                Navigator.pop(context); // Close dialog if no changes
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _addNewCategory(context),
                tooltip: 'Add New Category',
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Categories Section
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.category, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ...provider.categories.map((category) => ListTile(
                          leading: Icon(
                            provider.selectedCategory == category
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: provider.selectedCategory == category
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          title: Text(category),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () =>
                                    _editCategoryName(context, category),
                                tooltip: 'Edit Category',
                              ),
                              if (provider.categories.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _showDeleteConfirmation(
                                      context, category),
                                  tooltip: 'Delete Category',
                                ),
                            ],
                          ),
                          onTap: () => provider.setSelectedCategory(category),
                        )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "$category"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _categoryProvider.deleteCategory(category);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
