// lib/views/data_center_view.dart

import 'package:automated_attendance/controllers/ui_state_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/captured_face.dart';

class CapturedFacesGrid extends StatelessWidget {
  const CapturedFacesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UIStateController>(
      builder: (context, controller, child) {
        final List<CapturedFace> faces = controller.capturedFaces;
        if (faces.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.face, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "No faces captured yet",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Detected faces will appear here",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 250,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: faces.length,
          itemBuilder: (context, index) {
            final face = faces[index];
            final hasName = face.name != null && face.name!.isNotEmpty;
            final displayName = hasName ? face.name! : 'Unknown Person';

            // Format date for display
            final dateFormat = DateFormat('MMM d, h:mm a');
            final formattedDate = dateFormat.format(face.timestamp);

            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Face image
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: Image.memory(
                              face.thumbnail,
                              fit: BoxFit.cover,
                            ),
                          ),

                          // Recognition status indicator
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: hasName
                                    ? Colors.green.withOpacity(0.8)
                                    : Colors.grey.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                hasName ? Icons.check : Icons.help_outline,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color:
                                  hasName ? Colors.black87 : Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
