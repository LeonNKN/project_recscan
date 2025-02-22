import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'category_provider.dart';
import 'category_item.dart';
import 'scan_page.dart' as scan_page;
import 'package:recscan/widgets/overview/overview_category_card_view.dart';
import 'package:recscan/widgets/overview/overview_header.dart'; // <-- updated header
import 'package:recscan/widgets/overview/overview_transaction_card.dart';

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
  // Example data for your horizontal card view (existing)
  final List<CardItem> _cardItems = [
    CardItem(
      icon: Icons.shopping_cart,
      title: 'CONSUMER LOAN',
      amount: '-\$6,496.00',
    ),
    CardItem(
      icon: Icons.shopping_cart,
      title: 'AUTO LOAN',
      amount: '-\$1,250.00',
    ),
    CardItem(
      icon: Icons.shopping_cart,
      title: 'PERSONAL LOAN',
      amount: '-\$3,400.00',
    ),
  ];

  // Example data for your ExpandableRestaurantCard
  final List<RestaurantCardModel> _restaurantCards = [
    RestaurantCardModel(
      id: 1001,
      restaurantName: 'KAYU RESTAURANT',
      dateTime: DateTime(2025, 3, 19, 16, 32),
      total: 100.00,
      category: 'Shopping',
      categoryColor: Colors.blue,
      iconColor: Colors.red,
      items: [
        OrderItem(name: 'Jalapeno', price: 15.0, quantity: 2),
        OrderItem(name: 'nasi', price: 15.0, quantity: 1),
        OrderItem(name: 'ice', price: 34.0, quantity: 1),
      ],
    ),
    RestaurantCardModel(
      id: 1002,
      restaurantName: 'Example Cafe',
      dateTime: DateTime(2025, 3, 20, 10, 15),
      total: 56.70,
      category: 'Food',
      categoryColor: Colors.orange,
      iconColor: Colors.green,
      items: [
        OrderItem(name: 'Latte', price: 12.5, quantity: 1),
        OrderItem(name: 'Sandwich', price: 15.0, quantity: 1),
      ],
    ),
  ];

  // Dummy search function (you can implement your own)
  void _searchTransactions() {
    // Show a dialog, or use showSearch with a SearchDelegate
    debugPrint('Search icon tapped! Implement search logic here.');
  }

  // Navigate to ScanPage and wait for result
  Future<void> _openScanPage(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => scan_page.ScanPage()),
    );
    if (result != null && result is CategoryItem) {
      // Suppose you add scanned categories to a provider, etc.
      Provider.of<CategoryProvider>(context, listen: false)
          .addScannedCategory(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            // Empty title or you could add your own text
            title: const Text(''),
            // Replace category selector with search icon
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _searchTransactions,
              ),
            ],
          ),
          body: Column(
            children: [
              // 1) OverviewHeader (optional)
              OverviewHeader(
                onDropdownChanged: (newPeriod) {
                  debugPrint('Selected period: $newPeriod');
                  // Filter your data or do something with newPeriod if needed
                },
              ),

              // 2) Horizontal cards below the header (optional)
              HorizontalCardsListView(items: _cardItems),

              // 3) A vertical list of ExpandableRestaurantCards
              Expanded(
                child: ListView.builder(
                  itemCount: _restaurantCards.length,
                  itemBuilder: (context, index) {
                    return ExpandableRestaurantCard(
                      data: _restaurantCards[index],
                    );
                  },
                ),
              ),
            ],
          ),

          // Floating Action Button for scanning, if needed
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openScanPage(context),
            child: const Icon(Icons.camera_alt),
          ),
        );
      },
    );
  }
}
