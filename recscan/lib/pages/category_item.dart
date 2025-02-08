// models/category_item.dart
class SubItem {
  String title;
  double price;
  SubItem({required this.title, required this.price});
}

class CategoryItem {
  String title;
  String category; // Category type (for filtering)
  List<SubItem> subItems;
  double totalPrice;
  CategoryItem({
    required this.title,
    required this.category,
    required this.subItems,
    required this.totalPrice,
  });
}
