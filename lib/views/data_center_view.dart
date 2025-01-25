// lib/views/data_center_view.dart
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:automated_attendance/widgets/person_details_panel.dart';
import 'package:automated_attendance/widgets/provider_card.dart';
import 'package:automated_attendance/widgets/recognized_person_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class DataCenterView extends StatefulWidget {
  const DataCenterView({super.key});

  @override
  State<DataCenterView> createState() => _DataCenterViewState();
}

class _DataCenterViewState extends State<DataCenterView> {
  // Removed SingleTickerProviderStateMixin
  int _selectedIndex = 0; // Track selected index for NavigationRail
  TrackedFace? _selectedPersonDetails; // For details panel

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
                  _selectedPersonDetails =
                      null; // Clear details panel on tab switch
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
                          // Handle settings action
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
                        RecognizedPeopleList(onPersonSelected: (person) {
                          setState(() {
                            _selectedPersonDetails =
                                person; // Update details panel
                          });
                        }),
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
  final Function(TrackedFace) onPersonSelected; // Callback for selection

  const RecognizedPeopleList({Key? key, required this.onPersonSelected})
      : super(key: key);

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
              onTap: () => onPersonSelected(trackedFace),
            );
          },
        );
      },
    );
  }
}
