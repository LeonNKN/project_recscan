class SubItem {
  final String title;
  final double price;
  final int quantity; // Add quantity

  SubItem({
    required this.title,
    required this.price,
    required this.quantity,
  });
}

class CategoryItem {
  final String title;
  final String category;
  final List<SubItem> subItems;
  final double totalPrice;

  CategoryItem({
    required this.title,
    required this.category,
    required this.subItems,
    required this.totalPrice,
  });
}
