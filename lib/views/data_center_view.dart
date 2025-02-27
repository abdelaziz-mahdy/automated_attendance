// lib/views/data_center_view.dart
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:automated_attendance/views/data_center_pages/active_providers_grid.dart';
import 'package:automated_attendance/views/data_center_pages/captured_faces_grid.dart';
import 'package:automated_attendance/views/data_center_pages/face_analytics_page.dart';
import 'package:automated_attendance/views/data_center_pages/recognized_people_list.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataCenterView extends StatefulWidget {
  const DataCenterView({super.key});

  @override
  State<DataCenterView> createState() => _DataCenterViewState();
}

class _DataCenterViewState extends State<DataCenterView> {
  // Removed SingleTickerProviderStateMixin
  int _selectedIndex = 0; // Track selected index for NavigationRail

  // Settings variables
  int? _currentMaxFaces;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentMaxFaces = prefs.getInt('maxFaces') ?? 10;
    });
  }

  // Function to show the settings dialog
  void _showSettingsDialog(BuildContext context) {
    final cameraManager =
        Provider.of<CameraManager>(context, listen: false); // Get it here

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            bool useIsolates = cameraManager.useIsolates;

            return AlertDialog(
              title: const Text("Settings"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Max Faces Slider
                  Row(
                    children: [
                      const Text("Max Faces:"),
                      Expanded(
                        child: Slider(
                          min: 1,
                          max: 100,
                          divisions: 99,
                          value: _currentMaxFaces?.toDouble() ?? 10,
                          label: _currentMaxFaces?.toString() ?? "10",
                          onChanged: (value) {
                            final newMax = value.round();
                            setState(() {
                              _currentMaxFaces = newMax;
                            });
                            cameraManager.updateSettings(newMax);
                          },
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "Max Faces in Memory: $_currentMaxFaces",
                    style: const TextStyle(fontSize: 12),
                  ),

                  SwitchListTile(
                    title: const Text('Use Isolates'),
                    value: useIsolates,
                    onChanged: (bool value) {
                      setState(() {
                        useIsolates = value;
                      });
                      cameraManager.updateUseIsolates(value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Center"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT SIDE: NAVIGATION RAIL
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all, // Show all labels
              groupAlignment: -0.9, // Align items towards the top
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.videocam_outlined),
                  selectedIcon: Icon(Icons.videocam),
                  label: Text('Providers'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.face_outlined),
                  selectedIcon: Icon(Icons.face),
                  label: Text('Faces'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outlined),
                  selectedIcon: Icon(Icons.people),
                  label: Text('People'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics),
                  label: Text('Analytics'),
                ),
              ],
              trailing: Expanded(
                // Add extra buttons at the bottom of the rail
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Divider(thickness: 1),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0, top: 12.0),
                      child: IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: 'Settings',
                        onPressed: () {
                          _showSettingsDialog(context); // Show settings dialog
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: IconButton(
                        icon: const Icon(Icons.info_outlined),
                        tooltip: 'About',
                        onPressed: () {
                          // Handle about action
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            // RIGHT SIDE: MAIN CONTENT AREA - Now directly using IndexedStack
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3, // Main content takes more space
                    child: IndexedStack(
                      // Using IndexedStack instead of TabBarView
                      index: _selectedIndex,
                      children: const [
                        // Tab 1: Active Providers
                        ActiveProvidersGrid(),
                        // Tab 2: Captured Faces
                        CapturedFacesGrid(),
                        // Tab 3: Recognized People
                        RecognizedPeopleList(onPersonSelected: null),
                        // Tab 4: Analytics (NEW)
                        FaceAnalyticsPage(),
                      ],
                    ),
                  ),
                  // // DETAILS PANEL (Conditionally shown for Recognized People)
                  // if (_selectedIndex == 2 &&
                  //     _selectedPersonDetails !=
                  //         null) // Show details only for People tab
                  //   Expanded(
                  //     flex: 1, // Details panel takes less space
                  //     child:
                  //         PersonDetailsPanel(person: _selectedPersonDetails!),
                  //   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
