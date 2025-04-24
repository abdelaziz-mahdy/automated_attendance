import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:automated_attendance/controllers/ui_state_controller.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:intl/intl.dart';

class ActiveVisitsPage extends StatefulWidget {
  const ActiveVisitsPage({super.key});

  @override
  State<ActiveVisitsPage> createState() => _ActiveVisitsPageState();
}

class _ActiveVisitsPageState extends State<ActiveVisitsPage> {
  final _dateFormat = DateFormat('MMM d, yyyy • h:mm a');
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeVisits = [];
  Timer? _refreshTimer;
  DateTime _lastUpdateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadActiveVisits();

    // Setup auto-refresh timer (every 2 seconds)
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadActiveVisits(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveVisits() async {
    // Only set loading state if we don't have data yet, to avoid flickering
    if (_activeVisits.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final controller = Provider.of<UIStateController>(context, listen: false);
      // Get active visits data
      final visits = await controller.getActiveVisits();

      // Always update the last update time and the state
      // This ensures the timestamp is refreshed even if the visits don't change
      setState(() {
        _activeVisits = visits;
        _isLoading = false;
        _lastUpdateTime = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading active visits: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_activeVisits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_alt_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No active visits",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "When people are detected, their visits will appear here",
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadActiveVisits,
              child: const Text("Refresh"),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActiveVisits,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Visits (${_activeVisits.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Use the stored lastUpdateTime instead of now
                Text(
                  'Last updated: ${DateFormat('h:mm:ss a').format(_lastUpdateTime)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _activeVisits.length,
                itemBuilder: (context, index) {
                  final visit = _activeVisits[index];
                  final TrackedFace? person = visit['person'];
                  final DateTime entryTime = visit['entryTime'];
                  final String cameraName =
                      visit['cameraName'] ?? 'Unknown Camera';
                  final Duration duration =
                      DateTime.now().difference(entryTime);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: person?.thumbnail != null
                          ? CircleAvatar(
                              backgroundImage: MemoryImage(person!.thumbnail!),
                              radius: 24,
                            )
                          : const CircleAvatar(
                              child: Icon(Icons.person),
                              radius: 24,
                            ),
                      title: Text(
                        person?.name ?? 'Unknown Person',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entered: ${_dateFormat.format(entryTime)}'),
                          Text('Camera: $cameraName'),
                          Text(
                            'Duration: ${_formatDuration(duration)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => _showVisitDetails(context, visit),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  void _showVisitDetails(BuildContext context, Map<String, dynamic> visit) {
    final TrackedFace? person = visit['person'];
    final DateTime entryTime = visit['entryTime'];
    final String cameraName = visit['cameraName'] ?? 'Unknown Camera';
    final Duration duration = DateTime.now().difference(entryTime);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (person?.thumbnail != null)
                CircleAvatar(
                  backgroundImage: MemoryImage(person!.thumbnail!),
                  radius: 48,
                ),
              const SizedBox(height: 16),
              Text(
                person?.name ?? 'Unknown Person',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _infoRow(Icons.access_time, 'Entry Time',
                  _dateFormat.format(entryTime)),
              _infoRow(Icons.timer, 'Duration', _formatDuration(duration)),
              _infoRow(Icons.videocam, 'Camera', cameraName),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
