import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_helper.dart';

class CategoryProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

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

  CategoryProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      debugPrint('Loading data from database...');
      // Load categories from database
      final categories = await _dbService.getAllCategories();
      debugPrint('Loaded ${categories.length} categories');
      if (categories.isNotEmpty) {
        _categories.clear();
        _categories.addAll(categories.map((c) => c['name'] as String));
      }

      // Load transactions
      final transactions = await _dbService.getTransactionsWithCategory();
      debugPrint('Loaded ${transactions.length} transactions');
      _restaurantCards.clear();

      for (final transaction in transactions) {
        try {
          final colorStr = transaction['category_color'] as String;
          final color = Color(
              int.parse(colorStr.replaceAll('0xFF', ''), radix: 16) +
                  0xFF000000);

          final iconColorStr = transaction['icon_color'] as String;
          final iconColor = Color(
              int.parse(iconColorStr.replaceAll('0xFF', ''), radix: 16) +
                  0xFF000000);

          // Load order items for this transaction
          final orderItems = await _dbService
              .getOrderItemsForTransaction(transaction['id'] as int);
          final items = orderItems
              .map((item) => OrderItem(
                    name: item['name'] as String,
                    quantity: item['quantity'] as int,
                    price: item['price'] as double,
                  ))
              .toList();

          debugPrint(
              'Loaded ${items.length} items for transaction ${transaction['id']}');

          _restaurantCards.add(RestaurantCardModel(
            id: transaction['id'],
            restaurantName: transaction['restaurant_name'],
            dateTime: DateTime.parse(transaction['date_time']),
            subtotal: transaction['subtotal'] ?? 0.0,
            total: transaction['total'],
            category: transaction['category_name'],
            categoryColor: color,
            iconColor: iconColor,
            items: items,
          ));
        } catch (e) {
          debugPrint('Error parsing transaction: $e');
        }
      }
      debugPrint('Current restaurant cards: ${_restaurantCards.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

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
  Future<void> addRestaurantCard(RestaurantCardModel card) async {
    try {
      debugPrint('Adding restaurant card: ${card.restaurantName}');

      // Get category ID
      final categories = await _dbService.getAllCategories();
      final category = categories.firstWhere(
        (c) => c['name'] == card.category,
        orElse: () => categories.first, // Use first category as fallback
      );

      final categoryId = category['id'] as int;
      debugPrint('Found category ID: $categoryId');

      // Insert transaction
      final transactionId = await _dbService.insertTransaction(
        categoryId: categoryId,
        restaurantName: card.restaurantName,
        dateTime: card.dateTime,
        subtotal: card.subtotal,
        total: card.total,
      );
      debugPrint('Inserted transaction with ID: $transactionId');

      // Insert order items
      for (final item in card.items) {
        await _dbService.insertOrderItem(
          transactionId: transactionId,
          name: item.name,
          price: item.price,
          quantity: item.quantity,
        );
      }
      debugPrint('Inserted ${card.items.length} order items');

      // Add to memory
      _restaurantCards.insert(0, card);
      debugPrint(
          'Added card to memory. Current count: ${_restaurantCards.length}');

      // Notify listeners to update UI
      notifyListeners();

      // Reload data to ensure consistency
      await _loadData();
    } catch (e) {
      debugPrint('Error adding restaurant card: $e');
      rethrow;
    }
  }

  // Get cards by category
  List<RestaurantCardModel> getCardsByCategory(String category) {
    return _restaurantCards.where((card) => card.category == category).toList();
  }

  // Update a transaction's details
  void updateTransaction(RestaurantCardModel updatedCard) {
    final index =
        _restaurantCards.indexWhere((card) => card.id == updatedCard.id);
    if (index != -1) {
      _restaurantCards[index] = updatedCard;
      notifyListeners();
    }
  }

  // Update a transaction's restaurant name
  void updateTransactionName(int cardId, String newName) {
    final index = _restaurantCards.indexWhere((card) => card.id == cardId);
    if (index != -1) {
      final card = _restaurantCards[index];
      _restaurantCards[index] = RestaurantCardModel(
        id: card.id,
        restaurantName: newName,
        dateTime: card.dateTime,
        subtotal: card.subtotal,
        total: card.total,
        category: card.category,
        categoryColor: card.categoryColor,
        iconColor: card.iconColor,
        items: card.items,
      );
      notifyListeners();
    }
  }

  // Update a transaction's category
  void updateTransactionCategory(int cardId, String newCategory) {
    final index = _restaurantCards.indexWhere((card) => card.id == cardId);
    if (index != -1) {
      final card = _restaurantCards[index];
      _restaurantCards[index] = RestaurantCardModel(
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
      notifyListeners();
    }
  }

  // Delete a restaurant card
  Future<void> deleteRestaurantCard(int cardId) async {
    try {
      debugPrint('Deleting restaurant card with ID: $cardId');

      // Remove from database
      await _dbService.deleteTransaction(cardId);
      debugPrint('Deleted transaction from database');

      // Remove from memory
      _restaurantCards.removeWhere((card) => card.id == cardId);
      debugPrint(
          'Removed card from memory. Current count: ${_restaurantCards.length}');

      // Notify listeners to update UI
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting restaurant card: $e');
      rethrow;
    }
  }
}
