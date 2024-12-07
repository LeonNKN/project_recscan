import 'package:flutter/material.dart';

class CustomNavBarWithTwoFABs extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomNavBarWithTwoFABs({
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background Container for Bottom Navigation Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
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
            padding: const EdgeInsets.only(top: 10),
            child: BottomNavigationBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              currentIndex: selectedIndex,
              unselectedItemColor:
                  Colors.black, // Set unselected color to black
              selectedItemColor: Colors.black, // Set selected color to black
              onTap: (index) {
                if (index != 1 && index != 2) {
                  onItemTapped(index); // Avoid triggering the FAB buttons
                }
              },
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: SizedBox(), // Placeholder for first floating button
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: SizedBox(), // Placeholder for second floating button
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

        // First Floating Button
        Positioned(
          top: -30,
          left: MediaQuery.of(context).size.width / 2 - 75,
          child: GestureDetector(
            onTap: () {
              onItemTapped(1); // First floating button action
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),

        // Second Floating Button
        Positioned(
          top: -30,
          left: MediaQuery.of(context).size.width / 2 + 15,
          child: GestureDetector(
            onTap: () {
              onItemTapped(2); // Second floating button action
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.edit,
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
