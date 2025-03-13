import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'pages/home_page.dart';
import 'pages/scan_page.dart' as scan_page; // alias to refer to ScanPage
import 'pages/record_page.dart'; // We'll show RecordPage in nav
import 'pages/settings_page.dart';
import 'pages/transaction_page.dart'; // TransactionPage
import 'widgets/custom_nav_bar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'pages/category_provider.dart';
import 'pages/category_item.dart'; // CategoryItem and SubItem models
import 'models/models.dart';
import 'services/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  final dbService = DatabaseService();
  await dbService.database;

  runApp(
    ChangeNotifierProvider(
      create: (context) => CategoryProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RecScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MainPage(),
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

  /// Open the scan page with a specific image source
  Future<void> _openScanPage(BuildContext context, ImageSource source) async {
    try {
      // Get the provider before navigating
      final provider = Provider.of<CategoryProvider>(context, listen: false);

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => scan_page.ScanPage(initialSource: source),
        ),
      );

      if (result != null && result is RestaurantCardModel) {
        // Add the card to the provider
        await provider.addRestaurantCard(result);

        // After scanning, go back to the home page
        if (mounted) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error in _openScanPage: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving receipt: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// This is called from CustomNavBarWithCenterFAB when a bottom item is tapped
  void _onItemTapped(int index) {
    switch (index) {
      case 2:
        // index 2 => the main center FAB in the nav bar
        // Open the scan page with a choice dialog
        _showScanOptionsDialog(context);
        break;

      case 5:
        // Extra FAB #1 => open camera directly
        _openScanPage(context, ImageSource.camera);
        break;

      case 6:
        // Extra FAB #2 => open gallery directly
        _openScanPage(context, ImageSource.gallery);
        break;

      default:
        // For indexes 0,1,3,4 => show the corresponding page
        setState(() {
          _selectedIndex = index;
        });
        break;
    }
  }

  void _showScanOptionsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan Receipt',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openScanPage(context, ImageSource.camera);
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openScanPage(context, ImageSource.gallery);
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        onScanTap: () => _showScanOptionsDialog(context),
      ),
    );
  }
}
