import 'package:flutter/material.dart';

class CustomNavBarWithCenterFAB extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomNavBarWithCenterFAB({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
  }) : super(key: key);

  @override
  _CustomNavBarWithCenterFABState createState() =>
      _CustomNavBarWithCenterFABState();
}

class _CustomNavBarWithCenterFABState extends State<CustomNavBarWithCenterFAB> {
  bool _isExpanded = false; // controls whether the extra FABs are visible

  void _toggleFAB() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Typical BottomNavigationBar height is 56
    // We'll add some top padding in the container for a rounded look
    const double navBarHeight = kBottomNavigationBarHeight; // 56
    const double extraTopPadding = 10;

    // Make the FAB about the size of a large icon so it lines up nicely
    const double fabSize = 40;

    // The vertical center of the nav icons is roughly (navBarHeight / 2 + extraTopPadding).
    // We want the FAB center to match that, so:
    final double fabVerticalPosition =
        (navBarHeight / 2) + extraTopPadding - (fabSize / 2);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1) The background Container + BottomNavigationBar
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
          child: Padding(
            padding: const EdgeInsets.only(top: extraTopPadding),
            child: BottomNavigationBar(
              // Ensure it's "fixed" so each of the 5 items has consistent spacing
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              backgroundColor: Colors.transparent,
              currentIndex: widget.selectedIndex,
              unselectedItemColor: Colors.grey,
              selectedItemColor: Colors.purple,
              onTap: (index) {
                // Toggle FAB only if center (index 2) is tapped
                if (index != 2) {
                  widget.onItemTapped(index);
                } else {
                  _toggleFAB();
                }
              },
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
                  // 3rd item: placeholder for the FAB
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
        ),

        // 2) The center FAB, aligned with other icons
        Positioned(
          top: fabVerticalPosition,
          left: MediaQuery.of(context).size.width / 2 - (fabSize / 2),
          child: GestureDetector(
            onTap: _toggleFAB,
            child: Container(
              width: fabSize,
              height: fabSize,
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
              child: Icon(
                _isExpanded ? Icons.close : Icons.qr_code_scanner,
                color: Colors.white,
                size: fabSize * 0.6, // scale icon to fit
              ),
            ),
          ),
        ),

        // 3) Extra FAB #1 (e.g. Camera)
        Positioned(
          top: fabVerticalPosition - 60, // place it above the main FAB
          left: MediaQuery.of(context).size.width / 2 - 95,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isExpanded ? 1.0 : 0.0,
            child: Visibility(
              visible: _isExpanded,
              child: GestureDetector(
                onTap: () {
                  // e.g. call onItemTapped(5)
                  widget.onItemTapped(5);
                  setState(() => _isExpanded = false);
                },
                child: Container(
                  width: 50,
                  height: 50,
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
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),

        // 4) Extra FAB #2 (e.g. Gallery)
        Positioned(
          top: fabVerticalPosition - 60,
          left: MediaQuery.of(context).size.width / 2 + 45,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isExpanded ? 1.0 : 0.0,
            child: Visibility(
              visible: _isExpanded,
              child: GestureDetector(
                onTap: () {
                  // e.g. call onItemTapped(6)
                  widget.onItemTapped(6);
                  setState(() => _isExpanded = false);
                },
                child: Container(
                  width: 50,
                  height: 50,
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
                  child: const Icon(
                    Icons.photo,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
