import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Navigation Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    Center(child: Text('Home Page')),
    Center(child: Text('Camera Page')),
    Center(child: Text('Profile Page')),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Custom Navigation Example'),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        color: Colors
            .blue.shade50, // Set the background color of the navigation bar
        padding:
            EdgeInsets.symmetric(vertical: 10), // Add padding to adjust height
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'Home', 0),
            _buildNavItem(Icons.camera, 'Camera', 1),
            _buildNavItem(Icons.person, 'Profile', 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: isSelected ? 60 : 40, // Larger when selected
            height: isSelected ? 60 : 40,
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: isSelected ? 30 : 24,
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 4), // Space between icon and label
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blue : Colors.black,
              fontSize: isSelected ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
