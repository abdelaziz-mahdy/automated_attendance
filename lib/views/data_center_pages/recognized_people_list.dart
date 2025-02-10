// lib/views/data_center_view.dart

import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:automated_attendance/widgets/recognized_person_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RecognizedPeopleList extends StatelessWidget {
  final Function(TrackedFace)? onPersonSelected; // Callback for selection

  const RecognizedPeopleList({super.key, required this.onPersonSelected});

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
              onTap: onPersonSelected == null
                  ? null
                  : () => onPersonSelected!(trackedFace),
            );
          },
        );
      },
    );
  }
}
