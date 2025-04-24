// lib/views/data_center_view.dart

import 'package:automated_attendance/controllers/ui_state_controller.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/utils/face_management_dialogs.dart';
import 'package:automated_attendance/widgets/dialogs/face_import_dialog.dart';
import 'package:automated_attendance/widgets/recognized_person_grid_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RecognizedPeopleList extends StatefulWidget {
  final Function(TrackedFace)? onPersonSelected;

  const RecognizedPeopleList({super.key, this.onPersonSelected});

  @override
  State<RecognizedPeopleList> createState() => _RecognizedPeopleListState();
}

class _RecognizedPeopleListState extends State<RecognizedPeopleList> {
  String? _selectedForMerge;

  // Control grid view properties
  int _getColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 6;
    if (width > 800) return 4;
    if (width > 600) return 3;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UIStateController>(
      builder: (context, manager, child) {
        return CustomScrollView(
          slivers: [
            // Add import faces button at the top
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      onPressed: _showImportDialog,
                      icon: const Icon(Icons.file_upload),
                      label: const Text('Import Faces'),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Add a header with X button when in merge mode
            if (_selectedForMerge != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.merge_type,
                                  color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Select another face to merge with the selected face',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() => _selectedForMerge = null);
                                },
                                tooltip: 'Cancel merge',
                                color: Colors.blue.shade700,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _buildContent(context, manager),
            ),
          ],
        );
      },
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => const FaceImportDialog(),
    );
  }

  Widget _buildContent(BuildContext context, UIStateController manager) {
    // Get tracked faces from manager - always from the latest state
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

    // Filter recognized people - stable sort by name for consistent UI
    final recognizedPeople = trackedFaces.entries
        .where((entry) => entry.value.firstSeen != null)
        .toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));

    if (recognizedPeople.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(
          icon: Icons.person_search,
          title: 'No Recognitions Yet',
          message: 'Waiting for the first person to be recognized...',
        ),
      );
    }

    // Using SliverGrid instead of SliverList for grid layout
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getColumnCount(context),
        childAspectRatio: 0.8, // Adjust for card dimensions
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final personEntry = recognizedPeople[index];
          final trackedFace = personEntry.value;

          return RecognizedPersonGridCard(
            key: Key(
                'tracked-face-${trackedFace.id}'), // Use stable keys for Flutter to track widgets
            trackedFace: trackedFace,
            onTap: widget.onPersonSelected == null
                ? null
                : () => widget.onPersonSelected!(trackedFace),
            isSelectedForMerge: _selectedForMerge == trackedFace.id,
            onMergePressed: () => setState(() {
              _selectedForMerge =
                  _selectedForMerge == trackedFace.id ? null : trackedFace.id;
            }),
            onMergeWith:
                _selectedForMerge != null && _selectedForMerge != trackedFace.id
                    ? () async {
                        // Get the selected face object
                        final selectedFace =
                            manager.trackedFaces[_selectedForMerge!]!;

                        // Show the merge confirmation dialog
                        final keepFaceId =
                            await FaceManagementDialogs.showMergeConfirmation(
                          context,
                          selectedFace, // The previously selected face
                          trackedFace, // The current face being viewed
                        );

                        if (keepFaceId != null) {
                          // Determine which is source and which is target
                          final sourceId = keepFaceId == selectedFace.id
                              ? trackedFace.id
                              : selectedFace.id;

                          // Reset selection state before the potentially long operation
                          setState(() => _selectedForMerge = null);

                          // Perform the merge operation - this will update the UI via notifyListeners
                          await manager.mergeFaces(keepFaceId, sourceId);
                        }
                      }
                    : null,
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
