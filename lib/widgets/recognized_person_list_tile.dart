// lib/views/data_center_view.dart

import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
        ] else if (widget.onMergePressed != null) ...[
          IconButton(
            onPressed: widget.onMergePressed,
            icon: const Icon(Icons.merge),
            tooltip: 'Merge with another face',
          ),
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
        fillColor: _isHovered ? Colors.grey.shade100 : Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
        hintText: 'Enter name',
      ),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      onChanged: (newValue) {
        Provider.of<CameraManager>(context, listen: false)
            .updateTrackedFaceName(widget.trackedFace.id, newValue);
      },
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
            return Container(
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
                            mergedFace.lastSeen?.toLocal() ?? DateTime.now(),
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
