// lib/views/data_center_view.dart

import 'package:automated_attendance/services/camera_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
