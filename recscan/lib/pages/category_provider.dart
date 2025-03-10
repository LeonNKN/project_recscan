import 'package:flutter/material.dart';
import 'package:recscan/widgets/overview/overview_transaction_card.dart'; // Adjust import as needed

class CategoryProvider with ChangeNotifier {
  // List of restaurant cards
  final List<RestaurantCardModel> _restaurantCards = [];

  // List of categories (starting with default categories)
  final List<String> _categories = [
    'Food & Beverage',
    'Groceries',
    'Shopping',
    'Others'
  ];

  // Currently selected category
  String _selectedCategory = 'Food & Beverage';

  // Getters
  List<RestaurantCardModel> get restaurantCards => _restaurantCards;
  List<String> get categories => _categories;
  String get selectedCategory => _selectedCategory;

  // Set the selected category
  void setSelectedCategory(String category) {
    if (_categories.contains(category)) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  // Add a new category
  void addCategory(String newCategory) {
    if (newCategory.isNotEmpty && !_categories.contains(newCategory)) {
      _categories.add(newCategory);
      notifyListeners();
    }
  }

  // Edit an existing category
  void editCategory(String oldCategory, String newCategory) {
    if (newCategory.isNotEmpty &&
        !_categories.contains(newCategory) &&
        _categories.contains(oldCategory)) {
      final index = _categories.indexOf(oldCategory);
      _categories[index] = newCategory;

      // Update selected category if it was the one edited
      if (_selectedCategory == oldCategory) {
        _selectedCategory = newCategory;
      }

      // Update all cards with the old category
      for (int i = 0; i < _restaurantCards.length; i++) {
        final card = _restaurantCards[i];
        if (card.category == oldCategory) {
          _restaurantCards[i] = RestaurantCardModel(
            id: card.id,
            restaurantName: card.restaurantName,
            dateTime: card.dateTime,
            subtotal: card.subtotal,
            total: card.total,
            category: newCategory,
            categoryColor: card.categoryColor,
            iconColor: card.iconColor,
            items: card.items,
          );
        }
      }

      notifyListeners();
    }
  }

  // Delete a category
  void deleteCategory(String category) {
    if (_categories.length > 1 && _categories.contains(category)) {
      _categories.remove(category);

      // Move all cards from deleted category to default category
      for (int i = 0; i < _restaurantCards.length; i++) {
        final card = _restaurantCards[i];
        if (card.category == category) {
          _restaurantCards[i] = RestaurantCardModel(
            id: card.id,
            restaurantName: card.restaurantName,
            dateTime: card.dateTime,
            subtotal: card.subtotal,
            total: card.total,
            category: _categories.first,
            categoryColor: card.categoryColor,
            iconColor: card.iconColor,
            items: card.items,
          );
        }
      }

      // Set selected category to the first one if the deleted one was selected
      if (_selectedCategory == category) {
        _selectedCategory = _categories.first;
      }
      notifyListeners();
    }
  }

  // Add a restaurant card
  void addRestaurantCard(RestaurantCardModel card) {
    _restaurantCards.add(card);
    notifyListeners();
  }

  // Get cards by category
  List<RestaurantCardModel> getCardsByCategory(String category) {
    return _restaurantCards.where((card) => card.category == category).toList();
  }
}
