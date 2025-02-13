// lib/views/data_center_view.dart

import 'package:automated_attendance/services/camera_manager.dart';
import 'package:automated_attendance/widgets/provider_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
            String providerStatus =
                "Online"; // Replace with actual status logic.
            final fps = manager.getProviderFps(address);

            return ProviderCard(
              address: address,
              frame: frame,
              status: providerStatus,
              fps: fps, // NEW: Pass current FPS to the ProviderCard.
            );
          },
        );
      },
    );
  }
}
