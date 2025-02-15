// lib/views/data_center_view.dart

import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:automated_attendance/widgets/recognized_person_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RecognizedPeopleList extends StatefulWidget {
  final Function(TrackedFace)? onPersonSelected;

  const RecognizedPeopleList({super.key, required this.onPersonSelected});

  @override
  State<RecognizedPeopleList> createState() => _RecognizedPeopleListState();
}

class _RecognizedPeopleListState extends State<RecognizedPeopleList> {
  String? _selectedForMerge;

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraManager>(
      builder: (context, manager, child) {
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _buildContent(context, manager),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, CameraManager manager) {
    final trackedFaces = manager.trackedFaces;

    if (trackedFaces.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(
          icon: Icons.face_outlined,
          title: 'No Tracked Faces',
          message: 'No faces have been added to the tracking system yet.',
        ),
      );
    }

    final recognizedPeople = trackedFaces.entries
        .where((entry) => entry.value.firstSeen != null)
        .toList();

    if (recognizedPeople.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(
          icon: Icons.person_search,
          title: 'No Recognitions Yet',
          message: 'Waiting for the first person to be recognized...',
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final personEntry = recognizedPeople[index];
          final trackedFace = personEntry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: RecognizedPersonListTile(
              trackedFace: trackedFace,
              onTap: widget.onPersonSelected == null
                  ? null
                  : () => widget.onPersonSelected!(trackedFace),
              isSelectedForMerge: _selectedForMerge == trackedFace.id,
              onMergePressed: () => setState(() {
                _selectedForMerge =
                    _selectedForMerge == trackedFace.id ? null : trackedFace.id;
              }),
              onMergeWith: _selectedForMerge != null &&
                      _selectedForMerge != trackedFace.id
                  ? () {
                      manager.mergeFaces(_selectedForMerge!, trackedFace.id);
                      setState(() => _selectedForMerge = null);
                    }
                  : null,
            ),
          );
        },
        childCount: recognizedPeople.length,
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
