import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  final String settingOption;

  const SettingsPage({Key? key, required this.settingOption}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<String> _categories = [];
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _categories = ['Type A', 'Type B', 'Type C', 'Type D'];
    _selectedCategory = _categories.contains(widget.settingOption)
        ? widget.settingOption
        : _categories[0];
  }

  void _addNewCategory(BuildContext context) {
    TextEditingController controller = TextEditingController();

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
                  !_categories.contains(newCategory)) {
                setState(() {
                  _categories.add(newCategory);
                  _selectedCategory = newCategory;
                });
                Navigator.pop(context);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editCategoryName(BuildContext context, String oldName) {
    TextEditingController controller = TextEditingController(text: oldName);

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
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              if (_categories.length > 1) {
                setState(() {
                  _categories.remove(oldName);
                  if (_selectedCategory == oldName) {
                    _selectedCategory = _categories.first;
                  }
                });
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
                  !_categories.contains(newName)) {
                setState(() {
                  final index = _categories.indexOf(oldName);
                  _categories[index] = newName;
                  if (_selectedCategory == oldName) {
                    _selectedCategory = newName;
                  }
                });
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings: $_selectedCategory'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ExpansionTile(
            title: Text('Select Category: $_selectedCategory'),
            children: [
              ..._categories.map((category) => ListTile(
                    title: Text(category),
                    trailing: _selectedCategory == category
                        ? Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () => setState(() => _selectedCategory = category),
                    onLongPress: () => _editCategoryName(context, category),
                  )),
              ListTile(
                leading: Icon(Icons.add, color: Colors.blue),
                title: Text('Add New Category',
                    style: TextStyle(color: Colors.blue)),
                onTap: () => _addNewCategory(context),
              ),
            ],
          ),
          // ... rest of your existing body code
        ],
      ),
    );
  }
}
