// category_provider.dart
import 'package:flutter/foundation.dart';

class CategoryProvider with ChangeNotifier {
  List<String> _categories = ['Type A', 'Type B', 'Type C', 'Type D'];
  String _selectedCategory = 'Type A';

  List<String> get categories => _categories;
  String get selectedCategory => _selectedCategory;

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
}
