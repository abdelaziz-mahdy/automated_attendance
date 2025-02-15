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

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: RecognizedPersonListTile(
                  trackedFace: trackedFace,
                  onTap: widget.onPersonSelected == null
                      ? null
                      : () => widget.onPersonSelected!(trackedFace),
                ),
              ),
              if (_selectedForMerge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    borderRadius: BorderRadius.circular(20),
                    elevation: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedForMerge == trackedFace.id
                            ? Colors.blue.shade100
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _selectedForMerge == trackedFace.id
                          ? TextButton.icon(
                              icon: const Icon(Icons.close),
                              label: const Text('Cancel'),
                              onPressed: () =>
                                  setState(() => _selectedForMerge = null),
                            )
                          : TextButton.icon(
                              icon: const Icon(Icons.merge),
                              label: const Text('Merge Here'),
                              onPressed: () {
                                manager.mergeFaces(
                                    _selectedForMerge!, trackedFace.id);
                                setState(() => _selectedForMerge = null);
                              },
                            ),
                    ),
                  ),
                ),
              if (_selectedForMerge == null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.merge),
                    onPressed: () =>
                        setState(() => _selectedForMerge = trackedFace.id),
                    tooltip: 'Merge with another face',
                  ),
                ),
            ],
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
