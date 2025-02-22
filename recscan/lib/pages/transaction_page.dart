import 'package:flutter/material.dart';
import 'package:recscan/widgets/overview/overview_transaction_card.dart';
import 'search_page.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({Key? key}) : super(key: key);

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  // Example date range text
  String _dateRangeText = 'Today / 19/12/2024 - 20/12/2024';

  // Track which category is currently selected
  String _selectedCategory = 'All';

  // List of categories to display in the horizontal scroll
  final List<String> _categories = [
    'All',
    'Utility',
    'Shopping',
    'Groceries',
    'Rent',
    'Bills',
    'Entertainment',
    'Travel',
  ];

  // Sample data for ExpandableRestaurantCard
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
      restaurantName: 'City Utility',
      dateTime: DateTime(2025, 4, 2, 10, 0),
      total: 60.0,
      category: 'Utility',
      categoryColor: Colors.orange,
      iconColor: Colors.green,
      items: [
        OrderItem(name: 'Water Bill', price: 30.0, quantity: 1),
        OrderItem(name: 'Electric Bill', price: 30.0, quantity: 1),
      ],
    ),
    RestaurantCardModel(
      id: 1003,
      restaurantName: 'Groceries Store',
      dateTime: DateTime(2025, 5, 1, 18, 15),
      total: 75.50,
      category: 'Groceries',
      categoryColor: Colors.purple,
      iconColor: Colors.brown,
      items: [
        OrderItem(name: 'Apples', price: 5.0, quantity: 3),
        OrderItem(name: 'Bread', price: 4.5, quantity: 1),
        OrderItem(name: 'Milk', price: 6.0, quantity: 1),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SafeArea ensures content is shown below the system status bar
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              // --- Top Row: Back Arrow, Title, Filter Icon, Search Icon ---
              Row(
                children: [
                  // Back arrow
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),

                  // Page title: "Transaction"
                  const Text(
                    'Transaction',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Push icons to the right
                  const Spacer(),

                  // Filter icon
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _onFilterPressed,
                  ),

                  // Search icon
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _onSearchPressed, // See below
                  ),
                ],
              ),

              // --- Below the title row: date/filter text ---
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _dateRangeText,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --- Horizontally scrollable category selector ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_categories.length, (index) {
                    final category = _categories[index];
                    final bool isLast = (index == _categories.length - 1);

                    return Row(
                      children: [
                        _buildCategoryItem(category),
                        if (!isLast) _buildVerticalDivider(),
                      ],
                    );
                  }),
                ),
              ),

              const SizedBox(height: 24),

              // --- List of ExpandableRestaurantCard, filtered by category ---
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredCards().length,
                  itemBuilder: (context, index) {
                    final cardData = _filteredCards()[index];
                    return ExpandableRestaurantCard(data: cardData);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build one category text widget
  Widget _buildCategoryItem(String category) {
    final isSelected = (_selectedCategory == category);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        child: Text(
          category,
          style: TextStyle(
            fontSize: 16,
            // Highlight the selected category
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue : Colors.black,
          ),
        ),
      ),
    );
  }

  // A thin vertical line to separate category texts
  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 20,
      color: Colors.grey[400],
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
    );
  }

  // Return the list of RestaurantCardModel, filtered by _selectedCategory
  List<RestaurantCardModel> _filteredCards() {
    if (_selectedCategory == 'All') {
      return _restaurantCards;
    } else {
      return _restaurantCards
          .where((card) => card.category == _selectedCategory)
          .toList();
    }
  }

  // Called when user taps the filter icon
  void _onFilterPressed() async {
    setState(() {
      _dateRangeText = 'Custom / 01/01/2025 - 05/01/2025';
    });
  }

  // 2) Called when user taps the search icon -> Open SearchPage
  void _onSearchPressed() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchPage(allCards: _restaurantCards),
      ),
    );
    // If the user taps on an item in the search results, 'result' could be a RestaurantCardModel
    debugPrint('Search result: $result');
  }
}
