import 'package:flutter/material.dart';
import 'category_provider.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Immediate Editing Demo',
      home: ExpandableListScreen(),
    );
  }
}

/// Model for each subitem that contains a title and a price.
class SubItem {
  String title;
  double price;
  SubItem({required this.title, required this.price});
}

/// Model for each category.
/// Added an extra field called 'category' which is stored but not displayed.
class CategoryItem {
  String title;
  String category; // New field added but not displayed.
  List<SubItem> subItems;
  double totalPrice; // Manually set total price.

  CategoryItem({
    required this.title,
    required this.category,
    required this.subItems,
    required this.totalPrice,
  });
}

/// The main screen containing the expandable list.
class ExpandableListScreen extends StatefulWidget {
  @override
  _ExpandableListScreenState createState() => _ExpandableListScreenState();
}

class _ExpandableListScreenState extends State<ExpandableListScreen> {
  // Sample data: each category contains a title, a category field (not shown in UI),
  // a list of subitems, and a manually set total price.
  List<CategoryItem> items = [
    CategoryItem(
      title: 'Category 1',
      category: 'Type A',
      subItems: [
        SubItem(title: 'Item 1.1', price: 10.0),
        SubItem(title: 'Item 1.2', price: 15.5),
        SubItem(title: 'Item 1.3', price: 7.25),
      ],
      totalPrice: 50.0,
    ),
    CategoryItem(
      title: 'Category 2',
      category: 'Type B',
      subItems: [
        SubItem(title: 'Item 2.1', price: 20.0),
        SubItem(title: 'Item 2.2', price: 30.0),
      ],
      totalPrice: 100.0,
    ),
    CategoryItem(
      title: 'Category 3',
      category: 'Type C',
      subItems: [
        SubItem(title: 'Item 3.1', price: 5.0),
        SubItem(title: 'Item 3.2', price: 8.75),
        SubItem(title: 'Item 3.3', price: 12.0),
        SubItem(title: 'Item 3.4', price: 3.5),
      ],
      totalPrice: 40.0,
    ),
  ];

  String _selectedFilter = 'All';

  void _selectFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    // For this sample, we simply print the selected filter.
    print("Selected Filter: $_selectedFilter");
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Expandable List'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (filter) =>
                    setState(() => _selectedFilter = filter),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'All', child: Text('All')),
                  // Add provider categories dynamically:
                  ...provider.categories.map((category) => PopupMenuItem(
                        value: category,
                        child: Text(category),
                      )),
                ],
              ),
            ],
          ),
          body: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              // If a filter is applied, show only matching items.
              if (_selectedFilter != 'All' &&
                  item.category != _selectedFilter) {
                return SizedBox.shrink();
              }
              return ExpansionTile(
                // Build a header row with an icon, title on the left, and total price on the right.
                title: Row(
                  children: [
                    Icon(Icons.image, color: Colors.blue),
                    SizedBox(width: 8.0),
                    Text(
                      item.title,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Spacer(),
                    Text(
                      '\$${item.totalPrice.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                  ],
                ),
                children: item.subItems.asMap().entries.map((entry) {
                  int subItemIndex = entry.key;
                  SubItem subItem = entry.value;
                  return EditableSubItemTile(
                    initialTitle: subItem.title,
                    initialPrice: subItem.price,
                    onSubmitted: (newTitle, newPrice) {
                      // Update the subitem data when editing is complete.
                      setState(() {
                        item.subItems[subItemIndex].title = newTitle;
                        item.subItems[subItemIndex].price = newPrice;
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
        );
      },
    );
  }
}

/// A custom widget that displays a subitem with immediate (in-line) editing.
/// It shows the subitem's title and price, and toggles into an edit mode
/// where both fields are editable.
class EditableSubItemTile extends StatefulWidget {
  final String initialTitle;
  final double initialPrice;
  final void Function(String newTitle, double newPrice) onSubmitted;

  const EditableSubItemTile({
    Key? key,
    required this.initialTitle,
    required this.initialPrice,
    required this.onSubmitted,
  }) : super(key: key);

  @override
  _EditableSubItemTileState createState() => _EditableSubItemTileState();
}

class _EditableSubItemTileState extends State<EditableSubItemTile> {
  bool isEditing = false;
  late TextEditingController _titleController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _priceController =
        TextEditingController(text: widget.initialPrice.toString());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  /// Toggles the editing state.
  /// When switching off editing, it validates and submits the updated text and price.
  void _toggleEditing() {
    setState(() {
      isEditing = !isEditing;
    });
    if (!isEditing) {
      // Try to parse the price text into a double.
      double newPrice =
          double.tryParse(_priceController.text) ?? widget.initialPrice;
      widget.onSubmitted(_titleController.text, newPrice);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: isEditing
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Item Title',
                  ),
                ),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Price',
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: Text(_titleController.text)),
                Text('\$${_priceController.text}'),
              ],
            ),
      trailing: IconButton(
        icon: Icon(isEditing ? Icons.check : Icons.edit),
        onPressed: _toggleEditing,
      ),
    );
  }
}
