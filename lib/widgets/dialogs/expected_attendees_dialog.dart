import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:automated_attendance/controllers/ui_state_controller.dart';

class ExpectedAttendeesDialog extends StatelessWidget {
  const ExpectedAttendeesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: Provider.of<UIStateController>(context, listen: false)
            .getAvailableFaces(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final faces = snapshot.data!;

          return Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_add),
                    const SizedBox(width: 12),
                    const Text(
                      'Manage Expected Attendees',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: _ExpectedAttendeesList(faces: faces),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExpectedAttendeesList extends StatelessWidget {
  final List<Map<String, dynamic>> faces;

  const _ExpectedAttendeesList({required this.faces});

  @override
  Widget build(BuildContext context) {
    return Consumer<UIStateController>(
      builder: (context, controller, _) {
        return ListView.separated(
          shrinkWrap: true,
          itemCount: faces.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final face = faces[index];
            final isExpected =
                controller.isPersonExpected(face['id'] as String);

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: face['thumbnail'] != null
                    ? MemoryImage(face['thumbnail'])
                    : null,
                child:
                    face['thumbnail'] == null ? const Icon(Icons.person) : null,
              ),
              title: Text(face['name'] as String),
              trailing: Switch(
                value: isExpected,
                onChanged: (value) async {
                  if (value) {
                    await controller.markPersonAsExpected(face['id'] as String);
                  } else {
                    await controller
                        .unmarkPersonAsExpected(face['id'] as String);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
