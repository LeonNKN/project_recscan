import 'package:flutter/material.dart';
import 'package:recscan/widgets/overview/overview_transaction_card.dart';

// If your RestaurantCardModel is defined elsewhere, import it here.
// For example:
// import 'path/to/restaurant_card_model.dart';

class SearchPage extends StatefulWidget {
  final List<RestaurantCardModel> allCards;

  const SearchPage({Key? key, required this.allCards}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _query = "";
  List<RestaurantCardModel> _searchResults = [];

  // This simulates an async search. In a real app, you could call an API.
  Future<void> _search(String query) async {
    // Optional: simulate network delay or heavy computation
    await Future.delayed(const Duration(milliseconds: 300));

    // Filter by restaurantName (case-insensitive)
    final results = widget.allCards
        .where((card) =>
            card.restaurantName.toLowerCase().contains(query.toLowerCase()))
        .toList();

    setState(() {
      _searchResults = results;
    });
  }

  @override
  void initState() {
    super.initState();
    // Optionally show all items or no items at first
    _searchResults = widget.allCards; // or []
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar with a TextField for searching
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by restaurant name...',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            _query = value;
            _search(value);
          },
        ),
      ),
      body: _buildResults(),
    );
  }

  Widget _buildResults() {
    if (_query.isEmpty) {
      // If user hasn't typed anything yet
      return const Center(
        child: Text('Type to search by restaurant name.'),
      );
    }
    if (_searchResults.isEmpty) {
      // No matches
      return const Center(
        child: Text('No results found.'),
      );
    }
    // Show matching results
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final cardData = _searchResults[index];
        return ListTile(
          title: Text(cardData.restaurantName),
          subtitle: Text(
            'Category: ${cardData.category}, Total: RM${cardData.total}',
          ),
          onTap: () {
            // If you want to return this item to the previous screen:
            Navigator.pop(context, cardData);
          },
        );
      },
    );
  }
}
