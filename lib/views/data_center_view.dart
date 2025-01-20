import 'package:automated_attendance/services/camera_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DataCenterView extends StatelessWidget {
  const DataCenterView({super.key});

  @override
  Widget build(BuildContext context) {
    final cameraManager = context.watch<CameraManager>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Center: Discovered Providers"),
      ),
      body: Consumer<CameraManager>(
        builder: (context, manager, child) {
          final providers = manager.activeProviders.keys.toList();

          if (providers.isEmpty) {
            return const Center(child: Text("No active services found."));
          }

          // Use GridView instead of ListView
          return GridView.builder(
            // This delegate will ensure items have a max width of 200
            // and a height of 300 (via childAspectRatio).
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              // Aspect ratio = width / height
              // Here it's 200 / 300 = 0.666...
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
    );
  }
}
