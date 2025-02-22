import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/scan_page.dart' as scan_page; // alias to refer to ScanPage
import 'pages/settings_page.dart';
import 'pages/transaction_page.dart'; // Import TransactionPage
import 'widgets/custom_nav_bar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'pages/category_provider.dart';
import 'pages/category_item.dart'; // CategoryItem and SubItem models

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => CategoryProvider(),
      child: MyApp(),
    ),
  );
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

  // Include all main navigation pages here
  final List<Widget> _pages = [
    HomePage(), // Home page (index 0)
    TransactionPage(), // Transaction Page (index 1)
    SettingsPage(settingOption: 'Type A'), // Settings page (index 2)
  ];

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    bool granted = await _checkPermissions();
    setState(() {
      _permissionStatus = granted
          ? "Permissions granted. Ready to proceed."
          : "Permission denied. Some features may not work.";
    });
    if (!granted) {
      if (await Permission.camera.isPermanentlyDenied) {
        _showPermissionDialog();
      }
    }
  }

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

  /// Instead of having ScanPage in the _pages list, we open it modally.
  void _onFloatingActionButtonTapped() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => scan_page.ScanPage()),
    );
    if (result != null && result is CategoryItem) {
      Provider.of<CategoryProvider>(context, listen: false)
          .addScannedCategory(result);
    }
    // After scanning, go back to the home page.
    setState(() {
      _selectedIndex = 0;
    });
  }

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
          _pages[_selectedIndex], // Display selected page
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
      bottomNavigationBar: CustomNavBarWithCenterFAB(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped, // Use _onItemTapped
      ),
    );
  }
}
