// category_provider.dart
import 'package:flutter/foundation.dart';
import 'category_item.dart'; // Create a file for CategoryItem if not done already

class CategoryProvider with ChangeNotifier {
  // Predefined category names (for filtering)
  List<String> _categories = ['Type A', 'Type B', 'Type C', 'Type D'];
  String _selectedCategory = 'Type A';

  // New list to store exported scan results (history)
  final List<CategoryItem> _scannedCategories = [];

  List<String> get categories => _categories;
  String get selectedCategory => _selectedCategory;

  // Getter for scanned results
  List<CategoryItem> get scannedCategories => _scannedCategories;

  // For filtering, you can continue to use addCategory/editCategory on _categories
  void addCategory(String newCategory) {
    _categories.add(newCategory);
    _selectedCategory = newCategory;
    notifyListeners();
  }

  void editCategory(String oldName, String newName) {
    final index = _categories.indexOf(oldName);
    if (index != -1) {
      _categories[index] = newName;
      if (_selectedCategory == oldName) {
        _selectedCategory = newName;
      }
      notifyListeners();
    }
  }

  void deleteCategory(String category) {
    if (_categories.length > 1) {
      _categories.remove(category);
      if (_selectedCategory == category) {
        _selectedCategory = _categories.first;
      }
      notifyListeners();
    }
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // NEW: Add a scan result (CategoryItem) to the history.
  void addScannedCategory(CategoryItem newCategory) {
    _scannedCategories.add(newCategory);
    // Optionally add the category name from the scanned result if it's not already in _categories.
    if (!_categories.contains(newCategory.category)) {
      _categories.add(newCategory.category);
    }
    _selectedCategory = newCategory.category;
    notifyListeners();
  }
}
