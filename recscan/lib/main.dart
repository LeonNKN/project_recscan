import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/scan_page.dart';
import 'pages/profile_page.dart';
import 'widgets/custom_nav_bar.dart'; // Import updated nav bar
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Floating Navigation Bar',
      theme: ThemeData(primarySwatch: Colors.purple),
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
  String _permissionStatus = "Checking permissions...";

  final List<Widget> _pages = [
    HomePage(), // Page for Home
    ScanPage(), // Page for First Floating Button
    ScanPage(), // Page for Second Floating Button
    ProfilePage(), // Page for Profile
  ];

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  /// Check and request permissions
  Future<void> _initializePermissions() async {
    bool granted = await _checkPermissions();
    setState(() {
      _permissionStatus = granted
          ? "Permissions granted. Ready to proceed."
          : "Permission denied. Some features may not work.";
    });

    if (!granted) {
      // Optional: Guide user to settings if permissions are permanently denied
      if (await Permission.camera.isPermanentlyDenied) {
        _showPermissionDialog();
      }
    }
  }

  /// Show a dialog to guide the user to settings
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permissions Required"),
        content: const Text(
            "Camera and storage permissions are required to use this app. Please grant them in your app settings."),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  /// Check and request permissions
  Future<bool> _checkPermissions() async {
    List<Permission> permissions = [];
    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) permissions.add(Permission.camera);

    if (permissions.isEmpty) {
      return true;
    } else {
      Map<Permission, PermissionStatus> statuses = await permissions.request();
      return statuses[Permission.camera] == PermissionStatus.granted;
    }
  }

  /// Handle navigation between pages
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _pages[_selectedIndex],
          if (_permissionStatus != "Permissions granted. Ready to proceed.")
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Text(
                  _permissionStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: CustomNavBarWithTwoFABs(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
