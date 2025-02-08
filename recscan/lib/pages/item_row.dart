// models/item_row.dart
class ItemRow {
  String item;
  String price;
  String quantity;
  String subPrice;
  bool isUserAdded;

  ItemRow({
    required this.item,
    required this.price,
    required this.quantity,
    required this.subPrice,
    this.isUserAdded = false,
  });

  void calculateValues() {
    try {
      double priceValue = double.tryParse(price) ?? 0;
      int quantityValue = int.tryParse(quantity) ?? 0;
      subPrice = (priceValue * quantityValue).toStringAsFixed(2);
    } catch (e) {
      subPrice = 'Error';
    }
  }
}
