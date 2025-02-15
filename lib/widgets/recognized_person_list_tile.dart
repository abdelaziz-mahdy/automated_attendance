// lib/views/data_center_view.dart

import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class RecognizedPersonListTile extends StatefulWidget {
  final TrackedFace trackedFace;
  final VoidCallback? onTap;

  const RecognizedPersonListTile(
      {super.key, required this.trackedFace, required this.onTap});

  @override
  State<RecognizedPersonListTile> createState() =>
      _RecognizedPersonListTileState();
}

class _RecognizedPersonListTileState extends State<RecognizedPersonListTile> {
  late TextEditingController _nameController;
  final _dateFormat = DateFormat('MMM d, y HH:mm');
  bool _isHovered = false;

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
            color: Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThumbnailsSection(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNameField(),
                          const SizedBox(height: 8),
                          _buildInfoSection(),
                          if (widget.trackedFace.mergedFaces.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Merged faces: ${widget.trackedFace.mergedFaces.length}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.onTap != null) _buildNavigationIcon(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailsSection() {
    final allThumbnails = widget.trackedFace.allThumbnails;
    if (allThumbnails.isEmpty) {
      return _buildEmptyThumbnail();
    }

    return Row(
      children: [
        // Main thumbnail
        Hero(
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
              child: Stack(
                children: [
                  Image.memory(
                    allThumbnails.first,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                  if (widget.trackedFace.mergedFaces.isNotEmpty)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+${widget.trackedFace.mergedFaces.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Merged thumbnails
        if (allThumbnails.length > 1) ...[
          const SizedBox(width: 8),
          SizedBox(
            height: 120,
            width: 120,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white,
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: const [0.8, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstOut,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: allThumbnails.length - 1,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Image.memory(
                          allThumbnails[index + 1],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
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
