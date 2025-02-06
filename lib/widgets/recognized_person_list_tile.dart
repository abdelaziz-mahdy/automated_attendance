// lib/views/data_center_view.dart

import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RecognizedPersonListTile extends StatefulWidget {
  // Changed to StatefulWidget for editable name in ListTile
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
    return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap: widget.onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Tracked face thumbnail with increased width
              widget.trackedFace.thumbnail != null
                  ? SizedBox(
                      width: 300, // Increased width
                      height: 300,
                      child: Image.memory(
                        widget.trackedFace.thumbnail!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.person, size: 300),
              const SizedBox(width: 16),
              // Text content: editable name and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        border: InputBorder.none, // Remove TextField border
                        isDense: true, // Reduce padding
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      onChanged: (newValue) {
                        Provider.of<CameraManager>(context, listen: false)
                            .updateTrackedFaceName(
                                widget.trackedFace.id, newValue);
                      },
                    ),
                    if (widget.trackedFace.firstSeen != null)
                      Text(
                        "First Seen: ${widget.trackedFace.firstSeen!.toLocal()}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (widget.trackedFace.lastSeen != null)
                      Text(
                        "Last Seen: ${widget.trackedFace.lastSeen!.toLocal()}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (widget.trackedFace.lastSeenProvider != null)
                      Text(
                        "Provider: ${widget.trackedFace.lastSeenProvider!}",
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ));
  }
}
