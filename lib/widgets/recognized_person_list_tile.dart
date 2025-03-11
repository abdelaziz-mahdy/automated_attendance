// lib/views/data_center_view.dart

import 'package:automated_attendance/controllers/ui_state_controller.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/widgets/similar_faces_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:automated_attendance/views/data_center_pages/person_visits_view.dart';

class RecognizedPersonListTile extends StatefulWidget {
  final TrackedFace trackedFace;
  final VoidCallback? onTap;
  final bool isSelectedForMerge;
  final VoidCallback? onMergePressed;
  final VoidCallback? onMergeWith;

  const RecognizedPersonListTile({
    super.key,
    required this.trackedFace,
    this.onTap,
    this.isSelectedForMerge = false,
    this.onMergePressed,
    this.onMergeWith,
  });

  @override
  State<RecognizedPersonListTile> createState() =>
      _RecognizedPersonListTileState();
}

class _RecognizedPersonListTileState extends State<RecognizedPersonListTile> {
  late TextEditingController _nameController;
  final _dateFormat = DateFormat('MMM d, y HH:mm:ss.SSS');
  bool _isHovered = false;
  bool _isExpanded = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.trackedFace.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Face'),
        content: Text(
            'Are you sure you want to delete ${widget.trackedFace.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              final manager =
                  Provider.of<UIStateController>(context, listen: false);
              manager.deleteTrackedFace(widget.trackedFace.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _saveNameChanges() {
    setState(() {
      _isEditing = false;
    });
    Provider.of<UIStateController>(context, listen: false)
        .updateTrackedFaceName(widget.trackedFace.id, _nameController.text);
  }

  void _splitMergedFace(TrackedFace mergedFace, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Split Face'),
        content: const Text(
            'Are you sure you want to split this face? It will be removed from the merged group and restored as a separate face.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final manager =
                  Provider.of<UIStateController>(context, listen: false);
              manager.splitMergedFace(
                  widget.trackedFace.id, mergedFace.id, index);
            },
            child: const Text('Split'),
          ),
        ],
      ),
    );
  }

  void _openVisitHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonVisitsView(
          faceId: widget.trackedFace.id,
          personName: widget.trackedFace.name,
        ),
      ),
    );
  }

  void _showSimilarFaces() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: SimilarFacesView(
                    faceId: widget.trackedFace.id,
                    onMergeComplete: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        if (widget.onMergeWith != null) ...[
          FilledButton.icon(
            onPressed: widget.onMergeWith,
            icon: const Icon(Icons.merge_type),
            label: const Text('Merge Here'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue.shade100,
              foregroundColor: Colors.blue.shade900,
            ),
          ),
          const SizedBox(width: 8),
        ] else if (widget.isSelectedForMerge) ...[
          OutlinedButton.icon(
            onPressed: widget.onMergePressed,
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 8),
        ] else ...[
          // Edit button
          if (_isEditing) ...[
            IconButton(
              onPressed: _saveNameChanges,
              icon: const Icon(Icons.save),
              tooltip: 'Save name changes',
            ),
          ] else ...[
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit name',
            ),
          ],

          // Visit history button
          IconButton(
            onPressed: _openVisitHistory,
            icon: const Icon(Icons.history),
            tooltip: 'View visit history',
          ),

          // Find similar faces button
          IconButton(
            onPressed: _showSimilarFaces,
            icon: const Icon(Icons.face),
            tooltip: 'Find similar faces',
          ),

          // Delete button
          IconButton(
            onPressed: _showDeleteConfirmation,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete face',
            color: Colors.red.shade300,
          ),

          // Merge button
          if (widget.onMergePressed != null) ...[
            IconButton(
              onPressed: widget.onMergePressed,
              icon: const Icon(Icons.merge),
              tooltip: 'Merge with another face',
            ),
          ],

          const SizedBox(width: 8),
        ],
        if (widget.onTap != null) _buildNavigationIcon(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _isHovered ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isSelectedForMerge
                ? Colors.blue.shade400
                : (_isHovered ? Colors.blue.shade200 : Colors.grey.shade200),
            width: widget.isSelectedForMerge || _isHovered ? 2 : 1,
          ),
          boxShadow: _isHovered || widget.isSelectedForMerge
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            _buildMainContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainThumbnail(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildNameField()),
                          _buildQuickActions(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoSection(),
                      if (widget.trackedFace.mergedFaces.isNotEmpty)
                        _buildMergedFacesHeader(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded && widget.trackedFace.mergedFaces.isNotEmpty)
          _buildMergedFacesGrid(),
      ],
    );
  }

  Widget _buildMainThumbnail() {
    return Hero(
      tag: 'face_${widget.trackedFace.id}',
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.blue.shade100,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: widget.trackedFace.allThumbnails.isNotEmpty
              ? Image.memory(
                  widget.trackedFace.allThumbnails.first,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                )
              : _buildEmptyThumbnail(),
        ),
      ),
    );
  }

  Widget _buildEmptyThumbnail() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 2,
        ),
        color: Colors.grey.shade100,
      ),
      child: Icon(
        Icons.person,
        size: 60,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        isDense: true,
        filled: true,
        fillColor: _isEditing
            ? Colors.blue.shade50
            : (_isHovered ? Colors.grey.shade100 : Colors.transparent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: _isEditing
              ? BorderSide(color: Colors.blue.shade300)
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: _isEditing
              ? BorderSide(color: Colors.blue.shade300)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.blue.shade500),
        ),
        hintText: 'Enter name',
        suffixIcon: _isEditing
            ? IconButton(
                icon: const Icon(Icons.check, size: 18),
                onPressed: _saveNameChanges,
                color: Colors.green,
              )
            : null,
      ),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      enabled: _isEditing,
      onSubmitted: (_) => _saveNameChanges(),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.trackedFace.firstSeen != null)
          _buildInfoRow(
            Icons.visibility,
            'First seen: ${_dateFormat.format(widget.trackedFace.firstSeen!.toLocal())}',
          ),
        if (widget.trackedFace.lastSeen != null)
          _buildInfoRow(
            Icons.update,
            'Last seen: ${_dateFormat.format(widget.trackedFace.lastSeen!.toLocal())}',
          ),
        if (widget.trackedFace.lastSeenProvider != null)
          _buildInfoRow(
            Icons.camera,
            'Provider: ${widget.trackedFace.lastSeenProvider!}',
          ),
        // Add visit history button as part of the info section
        InkWell(
          onTap: _openVisitHistory,
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                'View detailed visit history',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMergedFacesHeader() {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          children: [
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: Colors.blue.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              'Merged faces (${widget.trackedFace.mergedFaces.length})',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMergedFacesGrid() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: widget.trackedFace.mergedFaces.length,
          itemBuilder: (context, index) {
            final mergedFace = widget.trackedFace.mergedFaces[index];
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          mergedFace.allThumbnails.first,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 4,
                            ),
                            color: Colors.black54,
                            child: Text(
                              DateFormat('HH:mm:ss').format(
                                mergedFace.lastSeen?.toLocal() ??
                                    DateTime.now(),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.call_split, size: 16),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      color: Colors.blue.shade700,
                      onPressed: () => _splitMergedFace(mergedFace, index),
                      tooltip: 'Split this face',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavigationIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _isHovered ? Colors.grey.shade100 : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        Icons.navigate_next,
        color: _isHovered ? Colors.grey.shade700 : Colors.grey.shade400,
      ),
    );
  }
}
