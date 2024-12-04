import 'package:flutter/material.dart';

class CustomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomNavBar({
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white, // Background color for navigation bar
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20), // Rounded top corners
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 10), // Adjust padding
            child: BottomNavigationBar(
              elevation: 0,
              backgroundColor:
                  Colors.transparent, // Transparent to show custom background
              currentIndex: selectedIndex,
              onTap: (index) {
                if (index != 1)
                  onItemTapped(index); // Avoid triggering middle button
              },
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: SizedBox(), // Placeholder for floating button
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: -30, // Float the button above the navigation bar
          left: MediaQuery.of(context).size.width / 2 - 30, // Center the button
          child: GestureDetector(
            onTap: () {
              onItemTapped(1); // Middle button navigates to ScanPage
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.purple, // Background color for floating button
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt, // Middle button icon (Camera)
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
