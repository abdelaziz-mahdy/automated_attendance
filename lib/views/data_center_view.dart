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

          return ListView.builder(
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final address = providers[index];
              final frame = manager.getLastFrame(address);
              print("Frame: $frame");
              return Card(
                child: Column(
                  children: [
                    Text("Provider: $address"),
                    frame != null
                        ? Image.memory(
                            frame,
                            gaplessPlayback: true,
                          )
                        : const CircularProgressIndicator(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
