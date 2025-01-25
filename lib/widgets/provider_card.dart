// lib/views/data_center_view.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ProviderCard extends StatelessWidget {
  final String address;
  final dynamic frame;
  final String status; // Added status

  const ProviderCard(
      {required this.address,
      required this.frame,
      required this.status,
      super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () {
          // Handle card tap (show more details, etc.)
        },
        onHover: (isHovering) {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text("Provider: $address",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  _buildStatusIndicator(status),
                ],
              ),
            ),
            Expanded(
              child: frame != null
                  ? Image.memory(
                      frame,
                      gaplessPlayback: true,
                      fit: BoxFit.cover,
                    )
                  : Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        color: Colors.white,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Status: $status"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color indicatorColor;
    IconData indicatorIcon;

    switch (status.toLowerCase()) {
      case "online":
        indicatorColor = Colors.green;
        indicatorIcon = Icons.check_circle;
        break;
      case "offline":
        indicatorColor = Colors.red;
        indicatorIcon = Icons.error;
        break;
      default:
        indicatorColor = Colors.grey;
        indicatorIcon = Icons.help;
    }

    return Icon(indicatorIcon, color: indicatorColor);
  }
}
