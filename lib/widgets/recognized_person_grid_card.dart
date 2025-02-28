// filepath: /Users/AbdelazizMahdy/flutter_projects/cameras_viewer/lib/widgets/recognized_person_grid_card.dart

import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:automated_attendance/views/data_center_pages/person_visits_view.dart';

class RecognizedPersonGridCard extends StatefulWidget {
  final TrackedFace trackedFace;
  final VoidCallback? onTap;
  final bool isSelectedForMerge;
  final VoidCallback? onMergePressed;
  final VoidCallback? onMergeWith;

  const RecognizedPersonGridCard({
    super.key,
    required this.trackedFace,
    this.onTap,
    this.isSelectedForMerge = false,
    this.onMergePressed,
    this.onMergeWith,
  });

  @override
  State<RecognizedPersonGridCard> createState() =>
      _RecognizedPersonGridCardState();
}

class _RecognizedPersonGridCardState extends State<RecognizedPersonGridCard> {
  late TextEditingController _nameController;
  final _dateFormat = DateFormat('MMM d, y HH:mm:ss');
  final _shortDateFormat = DateFormat('MMM d, HH:mm');
  bool _isHovered = false;
  bool _isShowingDetails = false;
  bool _isEditing = false;
  bool _isShowingActions = false;

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

  void _saveNameChanges() {
    setState(() {
      _isEditing = false;
    });
    Provider.of<CameraManager>(context, listen: false)
        .updateTrackedFaceName(widget.trackedFace.id, _nameController.text);
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
                  Provider.of<CameraManager>(context, listen: false);
              manager.deleteTrackedFace(widget.trackedFace.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openMergedFacesView() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, controller) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Merged Faces',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: _buildMergedFacesGrid(controller),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMergedFacesGrid(ScrollController controller) {
    return widget.trackedFace.mergedFaces.isEmpty
        ? const Center(child: Text('No merged faces'))
        : GridView.builder(
            controller: controller,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: widget.trackedFace.mergedFaces.length,
            itemBuilder: (context, index) {
              final mergedFace = widget.trackedFace.mergedFaces[index];
              return _buildMergedFaceCard(mergedFace, index);
            },
          );
  }

  Widget _buildMergedFaceCard(TrackedFace mergedFace, int index) {
    return Stack(
      children: [
        Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: mergedFace.allThumbnails.isNotEmpty
                    ? Image.memory(
                        mergedFace.allThumbnails.first,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                color: Colors.black54,
                child: Text(
                  mergedFace.lastSeen != null
                      ? _shortDateFormat.format(mergedFace.lastSeen!.toLocal())
                      : 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.white.withOpacity(0.7),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.call_split,
                  size: 16,
                  color: Colors.blue.shade700,
                ),
              ),
              onTap: () => _splitMergedFace(mergedFace, index),
            ),
          ),
        ),
      ],
    );
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
                  Provider.of<CameraManager>(context, listen: false);
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        if (!_isEditing) {
          _isShowingActions = false;
        }
      }),
      child: GestureDetector(
        onTap: widget.onTap ??
            () {
              setState(() {
                _isShowingDetails = !_isShowingDetails;
              });
            },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCardHeader(),
              Expanded(child: _buildCardContent()),
              if (_isShowingDetails) _buildCardDetails(),
              _buildCardFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: _isEditing
          ? TextField(
              controller: _nameController,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                isDense: true,
                filled: true,
                fillColor: Colors.blue.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.blue.shade300),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check, size: 18),
                  onPressed: _saveNameChanges,
                  color: Colors.green,
                ),
              ),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              onSubmitted: (_) => _saveNameChanges(),
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    widget.trackedFace.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isHovered || _isShowingActions)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _isEditing = true),
                  ),
              ],
            ),
    );
  }

  Widget _buildCardContent() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Main face image
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: widget.trackedFace.allThumbnails.isNotEmpty
              ? Hero(
                  tag: 'face_${widget.trackedFace.id}',
                  child: Image.memory(
                    widget.trackedFace.allThumbnails.first,
                    fit: BoxFit.cover,
                  ),
                )
              : Container(
                  color: Colors.grey.shade200,
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                ),
        ),

        // Overlay for merged faces count if any
        if (widget.trackedFace.mergedFaces.isNotEmpty)
          Positioned(
            bottom: 8,
            right: 8,
            child: InkWell(
              onTap: _openMergedFacesView,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.trackedFace.mergedFaces.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Selection overlay if hovered
        if (_isHovered && !_isShowingActions && !widget.isSelectedForMerge)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // IconButton(
                    //   icon: const Icon(Icons.visibility, color: Colors.white),
                    //   onPressed: () => setState(() {
                    //     _isShowingDetails = !_isShowingDetails;
                    //     _isShowingActions = true;
                    //   }),
                    //   tooltip: 'Show details',
                    // ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz, color: Colors.white),
                      onPressed: () => setState(() => _isShowingActions = true),
                      tooltip: 'Show actions',
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Action buttons overlay if showing actions
        if (_isShowingActions && !widget.isSelectedForMerge)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Close button in top-right corner
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          setState(() => _isShowingActions = false),
                    ),
                  ),
                  const Spacer(),

                  // Actions
                  _buildActionButton(
                    icon: Icons.history,
                    label: 'Visit History',
                    onPressed: _openVisitHistory,
                  ),
                  const SizedBox(height: 8),

                  if (widget.trackedFace.mergedFaces.isNotEmpty)
                    _buildActionButton(
                      icon: Icons.people,
                      label: 'Merged Faces',
                      onPressed: _openMergedFacesView,
                    ),
                  if (widget.trackedFace.mergedFaces.isNotEmpty)
                    const SizedBox(height: 8),

                  if (widget.onMergePressed != null)
                    _buildActionButton(
                      icon: Icons.merge,
                      label: 'Merge',
                      onPressed: widget.onMergePressed!,
                    ),
                  if (widget.onMergePressed != null) const SizedBox(height: 8),

                  _buildActionButton(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    onPressed: _showDeleteConfirmation,
                    color: Colors.red,
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),

        // Merge selection overlay
        if (widget.isSelectedForMerge)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade400, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.blue.shade700,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selected for merge',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: widget.onMergePressed,
                    child: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Merge target overlay
        if (widget.onMergeWith != null)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade400, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.merge_type,
                    color: Colors.green.shade700,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Merge into this face?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: widget.onMergeWith,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade500,
                    ),
                    child: const Text('Confirm Merge'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 16, color: color),
        label: Text(label),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color ?? Colors.black87,
          side: BorderSide(color: color ?? Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _buildCardDetails() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.trackedFace.firstSeen != null)
            _buildDetailRow(
              Icons.visibility,
              'First: ${_shortDateFormat.format(widget.trackedFace.firstSeen!.toLocal())}',
            ),
          if (widget.trackedFace.lastSeen != null)
            _buildDetailRow(
              Icons.update,
              'Last: ${_shortDateFormat.format(widget.trackedFace.lastSeen!.toLocal())}',
            ),
          if (widget.trackedFace.lastSeenProvider != null)
            _buildDetailRow(
              Icons.camera,
              widget.trackedFace.lastSeenProvider!,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFooter() {
    if (widget.onMergeWith != null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: FilledButton(
          onPressed: widget.onMergeWith,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.blue.shade500,
          ),
          child: const Text('Merge Here'),
        ),
      );
    }

    return const SizedBox(height: 0);
  }
}
