import 'package:flutter/material.dart';

class CustomNavBarWithCenterFAB extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final VoidCallback onScanTap;

  const CustomNavBarWithCenterFAB({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.onScanTap,
  });

  @override
  _CustomNavBarWithCenterFABState createState() =>
      _CustomNavBarWithCenterFABState();
}

class _CustomNavBarWithCenterFABState extends State<CustomNavBarWithCenterFAB> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Bottom Navigation Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            backgroundColor: Colors.transparent,
            currentIndex: widget.selectedIndex,
            unselectedItemColor: Colors.grey,
            selectedItemColor: Colors.purple,
            onTap: widget.onItemTapped,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.credit_card),
                label: 'Card',
              ),
              BottomNavigationBarItem(
                icon: SizedBox.shrink(),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart),
                label: 'Stat',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),

        // Center Scan Button
        Positioned(
          top: -20,
          left: MediaQuery.of(context).size.width / 2 - 30,
          child: GestureDetector(
            onTap: widget.onScanTap,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.purple,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.qr_code_scanner,
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
