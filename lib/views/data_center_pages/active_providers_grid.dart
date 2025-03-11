// lib/views/data_center_view.dart

import 'package:automated_attendance/controllers/ui_state_controller.dart';
import 'package:automated_attendance/widgets/provider_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ActiveProvidersGrid extends StatelessWidget {
  const ActiveProvidersGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UIStateController>(
      builder: (context, controller, child) {
        final providers = controller.activeProviders.keys.toList();

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
            final frame = controller.getLastFrame(address);
            String providerStatus =
                "Online"; // Replace with actual status logic.
            final fps = controller.getProviderFps(address);

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
