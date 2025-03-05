// lib/views/data_center_view.dart
import 'package:automated_attendance/controllers/ui_state_controller.dart';
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
    final controller = Provider.of<UIStateController>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            bool useIsolates = controller.useIsolates;

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
                            controller.updateSettings(newMax);
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
                      controller.updateUseIsolates(value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: const Text("Close"),
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
            // Navigation Rail on the left
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (index) {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                        labelType: NavigationRailLabelType.all,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.videocam_outlined),
                            selectedIcon: Icon(Icons.videocam),
                            label: Text('Cameras'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.face_outlined),
                            selectedIcon: Icon(Icons.face),
                            label: Text('Captured'),
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
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: IconButton(
                                icon: const Icon(Icons.settings),
                                onPressed: () {
                                  _showSettingsDialog(context);
                                },
                                tooltip: 'Settings',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Vertical divider
            const VerticalDivider(
              width: 24,
              thickness: 1,
              indent: 8,
              endIndent: 8,
            ),

            // Content area - Expanded to take remaining width
            Expanded(
              child: _buildSelectedView(_selectedIndex),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedView(int index) {
    switch (index) {
      case 0:
        return const ActiveProvidersGrid();
      case 1:
        return const CapturedFacesGrid();
      case 2:
        return const RecognizedPeopleList();
      case 3:
        return const FaceAnalyticsPage();
      default:
        return const Center(child: Text("Unknown view"));
    }
  }
}
