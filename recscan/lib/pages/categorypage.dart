import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'category_provider.dart';
import 'category_item.dart'; // Ensure you have your CategoryItem and SubItem models here.
// Use an alias to ensure you're referring to the correct ScanPage.
import 'scan_page.dart' as scan_page;

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Immediate Editing Demo',
      home: ExpandableListScreen(),
    );
  }
}

class ExpandableListScreen extends StatefulWidget {
  @override
  _ExpandableListScreenState createState() => _ExpandableListScreenState();
}

class _ExpandableListScreenState extends State<ExpandableListScreen> {
  // Local sample data.
  List<CategoryItem> localItems = [
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

  // This method navigates to the ScanPage and waits for an exported result.
  Future<void> _openScanPage(BuildContext context) async {
    // Assume ScanPage returns a CategoryItem when done.
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => scan_page.ScanPage()), // use alias if needed
    );
    if (result != null && result is CategoryItem) {
      Provider.of<CategoryProvider>(context, listen: false)
          .addScannedCategory(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, child) {
        // Combine local sample data with scanned results.
        List<CategoryItem> allItems = [];
        allItems.addAll(localItems);
        allItems.addAll(provider.scannedCategories);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Expandable List'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (filter) =>
                    setState(() => _selectedFilter = filter),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'All', child: Text('All')),
                  ...provider.categories.map(
                    (category) =>
                        PopupMenuItem(value: category, child: Text(category)),
                  ),
                ],
              ),
            ],
          ),
          body: ListView.builder(
            itemCount: allItems.length,
            itemBuilder: (context, index) {
              final item = allItems[index];
              if (_selectedFilter != 'All' &&
                  item.category != _selectedFilter) {
                return const SizedBox.shrink();
              }
              return ExpansionTile(
                title: Row(
                  children: [
                    const Icon(Icons.image, color: Colors.blue),
                    const SizedBox(width: 8.0),
                    Text(
                      item.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '\$${item.totalPrice.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                  ],
                ),
                children: item.subItems
                    .map((subItem) => EditableSubItemTile(
                          initialTitle: subItem.title,
                          initialPrice: subItem.price,
                          onSubmitted: (newTitle, newPrice) {
                            setState(() {
                              subItem.title = newTitle;
                              subItem.price = newPrice;
                            });
                          },
                        ))
                    .toList(),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openScanPage(context),
            child: const Icon(Icons.camera_alt),
          ),
        );
      },
    );
  }
}

/// A custom widget that displays a subitem with immediate inline editing.
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

  void _toggleEditing() {
    setState(() {
      isEditing = !isEditing;
    });
    if (!isEditing) {
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
                  decoration: const InputDecoration(
                    labelText: 'Item Title',
                  ),
                ),
                TextField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
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
