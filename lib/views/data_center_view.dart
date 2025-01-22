// data_center_view.dart

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
        ],
      ),
    );
  }
}
