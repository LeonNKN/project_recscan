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
  late final CategoryProvider _categoryProvider;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<CategoryProvider>(context);
    _categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    // Safely set the selected category
    if (_categoryProvider.categories.isNotEmpty) {
      _categoryProvider.setSelectedCategory(
        _categoryProvider.categories.contains(widget.settingOption)
            ? widget.settingOption
            : _categoryProvider.categories.first,
      );
    } else {
      // Handle the case of an empty category list if needed
      // For now, we'll assume the provider initializes with at least one category
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
            title: Text('Settings: ${provider.selectedCategory}'),
          ),
          body: ListView(
            children: [
              ExpansionTile(
                title: Text('Select Category: ${provider.selectedCategory}'),
                children: [
                  // Display each category in the provider
                  ...provider.categories.map((category) => ListTile(
                        title: Text(category),
                        trailing: provider.selectedCategory == category
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () => provider.setSelectedCategory(category),
                        onLongPress: () => _editCategoryName(context, category),
                      )),
                  // Tile to add a new category
                  ListTile(
                    leading: const Icon(Icons.add, color: Colors.blue),
                    title: const Text(
                      'Add New Category',
                      style: TextStyle(color: Colors.blue),
                    ),
                    onTap: () => _addNewCategory(context),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
