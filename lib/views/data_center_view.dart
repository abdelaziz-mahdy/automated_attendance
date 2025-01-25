// lib/views/data_center_view.dart

import 'package:automated_attendance/services/camera_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DataCenterView extends StatelessWidget {
  const DataCenterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Center: Discovered Providers"),
      ),
      body: Column(
        children: [
          // 1) The Grid of active providers
          Expanded(
            flex: 2,
            child: Consumer<CameraManager>(
              builder: (context, manager, child) {
                final providers = manager.activeProviders.keys.toList();

                if (providers.isEmpty) {
                  return const Center(child: Text("No active services found."));
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: providers.length,
                  itemBuilder: (context, index) {
                    final address = providers[index];
                    final frame = manager.getLastFrame(address);

                    return Card(
                      child: SizedBox(
                        width: 200,
                        height: 300,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Provider: $address"),
                            const SizedBox(height: 8),
                            Expanded(
                              child: frame != null
                                  ? Image.memory(
                                      frame,
                                      gaplessPlayback: true,
                                      fit: BoxFit.cover,
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const Divider(height: 1),

          // 2) A list of all captured faces
          Expanded(
            flex: 1,
            child: Consumer<CameraManager>(
              builder: (context, manager, child) {
                final faces = manager.capturedFaces;
                if (faces.isEmpty) {
                  return const Center(child: Text("No faces captured yet."));
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal, // or vertical
                  itemCount: faces.length,
                  itemBuilder: (context, index) {
                    final faceBytes = faces[index];
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.memory(
                        faceBytes,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const Divider(height: 1),

          // 3) List of recognized people
          Expanded(
            flex: 1,
            child: Consumer<CameraManager>(
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
                    final personId = personEntry.key;
                    final trackedFace =
                        personEntry.value; // Now a TrackedFace object

                    return ListTile(
                      leading: trackedFace.thumbnail != null
                          ? Image.memory(trackedFace.thumbnail!)
                          : const Icon(Icons.person),
                      title: Text(trackedFace.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (trackedFace.firstSeen != null)
                            Text(
                                "First Seen: ${trackedFace.firstSeen!.toLocal()}"),
                          if (trackedFace.lastSeen != null)
                            Text(
                                "Last Seen: ${trackedFace.lastSeen!.toLocal()}"),
                          if (trackedFace.lastSeenProvider != null)
                            Text("Provider: ${trackedFace.lastSeenProvider!}"),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
