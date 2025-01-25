// lib/views/data_center_view.dart

import 'package:automated_attendance/services/camera_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RecognizedPersonListTile extends StatefulWidget {
  // Changed to StatefulWidget for editable name in ListTile
  final TrackedFace trackedFace;

  final VoidCallback onTap;

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
      child: ListTile(
        leading: widget.trackedFace.thumbnail != null
            ? ClipOval(
                child: Image.memory(widget.trackedFace.thumbnail!,
                    width: 50, height: 50, fit: BoxFit.cover))
            : const Icon(Icons.person),
        title: TextField(
          // Replaced Text with TextField for inline edit
          controller: _nameController,
          decoration: const InputDecoration(
            border: InputBorder.none, // Remove TextField border
            isDense: true, // Reduce padding
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
          onChanged: (newValue) {
            Provider.of<CameraManager>(context, listen: false)
                .updateTrackedFaceName(widget.trackedFace.id, newValue);
          },
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.trackedFace.firstSeen != null)
              Text("First Seen: ${widget.trackedFace.firstSeen!.toLocal()}",
                  style: const TextStyle(fontSize: 12)),
            if (widget.trackedFace.lastSeen != null)
              Text("Last Seen: ${widget.trackedFace.lastSeen!.toLocal()}",
                  style: const TextStyle(fontSize: 12)),
            if (widget.trackedFace.lastSeenProvider != null)
              Text("Provider: ${widget.trackedFace.lastSeenProvider!}",
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
        onTap: widget.onTap,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
