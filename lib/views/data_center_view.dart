// lib/views/data_center_view.dart
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:automated_attendance/widgets/provider_card.dart';
import 'package:automated_attendance/widgets/recognized_person_list_tile.dart';
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
  int? _currentFps;
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
      _currentFps = prefs.getInt('fps') ?? 10;
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
            bool _useIsolates = cameraManager.useIsolates;

            return AlertDialog(
              title: const Text("Settings"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // FPS Slider
                  Row(
                    children: [
                      const Text("FPS:"),
                      Expanded(
                        child: Slider(
                          min: 1,
                          max: 100,
                          divisions: 99,
                          value: _currentFps?.toDouble() ?? 10,
                          label: _currentFps?.toString() ?? "10",
                          onChanged: (value) {
                            setState(() {
                              _currentFps = value.round();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "Frames Per Second: $_currentFps",
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 20),

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
                            setState(() {
                              _currentMaxFaces = value.round();
                            });
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
                    value: _useIsolates,
                    onChanged: (bool value) {
                      setState(() {
                        _useIsolates = value;
                      });
                      cameraManager.updateUseIsolates(value);
                    },
                  ),
                  Text(
                    "Use Isolates: $_useIsolates",
                    style: const TextStyle(fontSize: 12),
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
                TextButton(
                  onPressed: () {
                    // Apply and save settings
                    cameraManager.updateSettings(
                        _currentFps!, _currentMaxFaces!);
                    if (!mounted) return;
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: const Text("Apply"),
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
                      children: [
                        // Tab 1: Active Providers
                        ActiveProvidersGrid(),
                        // Tab 2: Captured Faces
                        CapturedFacesGrid(),
                        // Tab 3: Recognized People
                        RecognizedPeopleList(onPersonSelected: null),
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

// --- Active Providers Tab ---
class ActiveProvidersGrid extends StatelessWidget {
  const ActiveProvidersGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraManager>(
      builder: (context, manager, child) {
        final providers = manager.activeProviders.keys.toList();

        if (providers.isEmpty) {
          return const Center(child: Text("No active services found."));
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 350, // Wider cards
            mainAxisSpacing: 20, // Increased spacing
            crossAxisSpacing: 20,
            childAspectRatio: 1.2, // Slightly taller cards to fit more info
          ),
          itemCount: providers.length,
          itemBuilder: (context, index) {
            final address = providers[index];
            final frame = manager.getLastFrame(address);
            // Assuming you have a way to get provider status from CameraManager
            String providerStatus =
                "Online"; // Replace with actual status logic

            return ProviderCard(
                address: address, frame: frame, status: providerStatus);
          },
        );
      },
    );
  }
}

// --- Captured Faces Tab ---
class CapturedFacesGrid extends StatelessWidget {
  const CapturedFacesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraManager>(
      builder: (context, manager, child) {
        final faces = manager.capturedFaces;
        if (faces.isEmpty) {
          return const Center(child: Text("No faces captured yet."));
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 250, // Larger image size
            mainAxisSpacing: 15, // Increased spacing
            crossAxisSpacing: 15,
            childAspectRatio: 1,
          ),
          itemCount: faces.length,
          itemBuilder: (context, index) {
            final faceBytes = faces[index];
            return InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: Image.memory(faceBytes),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(
                  faceBytes,
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- Recognized People Tab ---
class RecognizedPeopleList extends StatelessWidget {
  final Function(TrackedFace)? onPersonSelected; // Callback for selection

  const RecognizedPeopleList({super.key, required this.onPersonSelected});

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraManager>(
      builder: (context, manager, child) {
        final trackedFaces = manager.trackedFaces;

        if (trackedFaces.isEmpty) {
          return const Center(child: Text("No tracked faces added."));
        }

        final recognizedPeople = trackedFaces.entries
            .where((entry) => entry.value.firstSeen != null)
            .toList();

        if (recognizedPeople.isEmpty) {
          return const Center(child: Text("No people recognized yet."));
        }

        return ListView.builder(
          itemCount: recognizedPeople.length,
          itemBuilder: (context, index) {
            final personEntry = recognizedPeople[index];
            final trackedFace = personEntry.value;

            return RecognizedPersonListTile(
              trackedFace: trackedFace,
              onTap: onPersonSelected == null
                  ? null
                  : () => onPersonSelected!(trackedFace),
            );
          },
        );
      },
    );
  }
}
