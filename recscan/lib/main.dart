import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/scan_page.dart' as scan_page; // alias to refer to ScanPage
import 'pages/record_page.dart'; // We'll show RecordPage in nav
import 'pages/settings_page.dart';
import 'unwanted/transaction_page.dart'; // TransactionPage
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
  const MyApp({super.key});

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
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  String _permissionStatus = "Checking permissions...";

  // We have 5 bottom nav items (indexes 0..4).
  // Index 2 is the FAB placeholder, so we put a placeholder page at _pages[2].
  final List<Widget> _pages = [
    HomePage(), // index 0 => Home
    TransactionPage(), // index 1 => Card
    Container(), // index 2 => placeholder for FAB (no page)
    ReportPage(), // index 3 => Stat
    SettingsPage(settingOption: 'Type A'), // index 4 => Profile (or Settings)
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
            "Camera permissions are required to use this app. Please grant them in your app settings."),
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
    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      var result = await Permission.camera.request();
      return result.isGranted;
    }
    return true;
  }

  /// If you want to open ScanPage from the center FAB:
  void _onFloatingActionButtonTapped() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => scan_page.ScanPage()),
    );
    if (result != null && result is CategoryItem) {
      Provider.of<CategoryProvider>(context, listen: false)
          .addCategory(result.category);
    }
    // After scanning, go back to the home page.
    setState(() {
      _selectedIndex = 0;
    });
  }

  /// This is called from CustomNavBarWithCenterFAB when a bottom item is tapped
  void _onItemTapped(int index) {
    // If the user tapped the camera or gallery FAB (indexes 5 or 6),
    // handle them as special actions (NOT pages in _pages).
    switch (index) {
      case 2:
        // index 2 => the main center FAB in the nav bar
        // This is toggled inside CustomNavBarWithCenterFAB, so do nothing here.
        break;

      case 5:
        // Extra FAB #1 => e.g. open camera
        // Or do something else:
        debugPrint("Camera FAB tapped!");
        // If you want to open the scanning page:
        _onFloatingActionButtonTapped();
        break;

      case 6:
        // Extra FAB #2 => e.g. open gallery
        debugPrint("Gallery FAB tapped!");
        // Implement your own logic here...
        break;

      default:
        // For indexes 0,1,3,4 => show the corresponding page
        setState(() {
          _selectedIndex = index;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Display the currently selected page from the list
          _pages[_selectedIndex],
          // If permissions not granted, overlay a semi-transparent message
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
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
