import 'package:flutter/material.dart';
import 'category_provider.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  final String settingOption;

  const SettingsPage({Key? key, required this.settingOption}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final CategoryProvider _categoryProvider;

  @override
  void initState() {
    super.initState();
    // Obtain the provider without listening for rebuilds here.
    _categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    _categoryProvider.setSelectedCategory(
      _categoryProvider.categories.contains(widget.settingOption)
          ? widget.settingOption
          : _categoryProvider.categories.first,
    );
  }

  /// Opens a dialog to add a new category.
  void _addNewCategory(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Category'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newCategory = controller.text.trim();
              if (newCategory.isNotEmpty &&
                  !_categoryProvider.categories.contains(newCategory)) {
                _categoryProvider.addCategory(newCategory);
                Navigator.pop(context);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  /// Opens a dialog to edit or delete an existing category.
  void _editCategoryName(BuildContext context, String oldName) {
    final TextEditingController controller =
        TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Category'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          // Delete button
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              if (_categoryProvider.categories.length > 1) {
                _categoryProvider.deleteCategory(oldName);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('At least one category required')),
                );
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty &&
                  newName != oldName &&
                  !_categoryProvider.categories.contains(newName)) {
                _categoryProvider.editCategory(oldName, newName);
                Navigator.pop(context);
              }
            },
            child: Text('Save'),
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
                  // Display each category in the provider.
                  ...provider.categories.map((category) => ListTile(
                        title: Text(category),
                        trailing: provider.selectedCategory == category
                            ? Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () => provider.setSelectedCategory(category),
                        // Long press to edit (or delete) the category.
                        onLongPress: () => _editCategoryName(context, category),
                      )),
                  // Tile to add a new category.
                  ListTile(
                    leading: Icon(Icons.add, color: Colors.blue),
                    title: Text(
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
