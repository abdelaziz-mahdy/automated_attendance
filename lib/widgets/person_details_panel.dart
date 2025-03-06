// lib/views/data_center_view.dart

import 'package:automated_attendance/controllers/ui_state_controller.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PersonDetailsPanel extends StatefulWidget {
  // Changed to StatefulWidget for editable name
  final TrackedFace person;

  const PersonDetailsPanel({super.key, required this.person});

  @override
  State<PersonDetailsPanel> createState() => _PersonDetailsPanelState();
}

class _PersonDetailsPanelState extends State<PersonDetailsPanel> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.person.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Person Details",
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            if (widget.person.thumbnail != null)
              ClipOval(
                child: Image.memory(widget.person.thumbnail!,
                    width: 80, height: 80, fit: BoxFit.cover),
              ),
            const SizedBox(height: 15),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (newValue) {
                Provider.of<UIStateController>(context, listen: false)
                    .updateTrackedFaceName(widget.person.id, newValue);
              },
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            if (widget.person.firstSeen != null)
              Text("First Seen: ${widget.person.firstSeen!.toLocal()}"),
            if (widget.person.lastSeen != null)
              Text("Last Seen: ${widget.person.lastSeen!.toLocal()}"),
            if (widget.person.lastSeenProvider != null)
              Text("Provider: ${widget.person.lastSeenProvider!}"),
            const SizedBox(height: 20),
            Text("Captured Thumbnails:",
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            // Display captured thumbnails here if needed
          ],
        ),
      ),
    );
  }
}
