import 'package:flutter/material.dart';

/// Model to hold each card's data
class CardItem {
  final IconData icon;
  final String title;
  final String amount;

  CardItem({
    required this.icon,
    required this.title,
    required this.amount,
  });
}

/// A horizontally scrollable list of Card widgets
class HorizontalCardsListView extends StatelessWidget {
  final List<CardItem> items;

  const HorizontalCardsListView({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200, // Adjust height to fit your design
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        padding: const EdgeInsets.all(16.0),
        itemBuilder: (context, index) {
          final cardItem = items[index];
          return MyCustomCard(
            icon: cardItem.icon,
            title: cardItem.title,
            amount: cardItem.amount,
          );
        },
      ),
    );
  }
}

/// Custom Card widget to match a "dark card" design
class MyCustomCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String amount;

  const MyCustomCard({
    super.key,
    required this.icon,
    required this.title,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2D2D2D), // Dark grey card background
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(right: 16.0),
      child: Container(
        width: 160, // Adjust card width as desired
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
