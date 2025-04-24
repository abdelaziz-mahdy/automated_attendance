import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:automated_attendance/controllers/ui_state_controller.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/visit_tracking_service.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class ActiveVisitsPage extends StatefulWidget {
  const ActiveVisitsPage({super.key});

  @override
  State<ActiveVisitsPage> createState() => _ActiveVisitsPageState();
}

class _ActiveVisitsPageState extends State<ActiveVisitsPage> {
  final _dateFormat = DateFormat('MMM d, yyyy • h:mm a');
  
  @override
  Widget build(BuildContext context) {
    // Use StreamBuilder instead of manual refresh timer for reactive updates
    return StreamBuilder<List<ActiveVisit>>(
      stream: Provider.of<UIStateController>(context).activeVisitsStream,
      builder: (context, snapshot) {
        // Show loading indicator while waiting for first data
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        // Show error message if stream has error
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  "Error loading visits",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }
        
        // Get active visits from snapshot
        final visits = snapshot.data ?? [];
        
        // Show empty state when no visits
        if (visits.isEmpty) {
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
              ],
            ),
          );
        }
        
        // Show the list of active visits
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Visits (${visits.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Real-time updates with automatic refresh
                  Text(
                    'Last updated: ${DateFormat('h:mm:ss a').format(DateTime.now())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                // Fix constructor with AnimatedBuilder widget
                child: ListView.builder(
                  itemCount: visits.length,
                  itemBuilder: (context, index) {
                    final visit = visits[index];
                    final person = visit.person; // Use the person variable
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: visit.person.thumbnail != null
                            ? CircleAvatar(
                                backgroundImage: MemoryImage(visit.person.thumbnail!),
                                radius: 24,
                              )
                            : const CircleAvatar(
                                child: Icon(Icons.person),
                                radius: 24,
                              ),
                        title: Text(
                          visit.person.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Entered: ${_dateFormat.format(visit.entryTime)}'),
                            Text('Camera: ${visit.cameraId}'),
                            // Use AnimatedBuilder to constantly update duration
                            AnimatedBuilder(
                              animation:  AlwaysAnimatedModel(),
                              builder: (context, _) {
                                return Text(
                                  'Duration: ${_formatDuration(visit.duration)}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                );
                              }
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
        );
      },
    );
  }
  
  // Extract visit card to separate method for cleaner code
  Widget _buildVisitCard(BuildContext context, ActiveVisit visit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: visit.person.thumbnail != null
            ? CircleAvatar(
                backgroundImage: MemoryImage(visit.person.thumbnail!),
                radius: 24,
              )
            : const CircleAvatar(
                child: Icon(Icons.person),
                radius: 24,
              ),
        title: Text(
          visit.person.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entered: ${_dateFormat.format(visit.entryTime)}'),
            Text('Camera: ${visit.cameraId}'),
            // Use AnimatedBuilder to constantly update duration
            AnimatedBuilder(
              animation:  AlwaysAnimatedModel(),
              builder: (context, _) {
                return Text(
                  'Duration: ${_formatDuration(visit.duration)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                );
              }
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

  void _showVisitDetails(BuildContext context, ActiveVisit visit) {
    final person = visit.person;
    final DateTime entryTime = visit.entryTime;
    final String cameraName = visit.cameraId;
    final Duration duration = visit.duration;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (person.thumbnail != null)
                CircleAvatar(
                  backgroundImage: MemoryImage(person.thumbnail!),
                  radius: 48,
                ),
              const SizedBox(height: 16),
              Text(
                person.name,
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

// Fix the AlwaysAnimatedModel class to use dart:async Timer
class AlwaysAnimatedModel extends ChangeNotifier {
  Timer? _timer;
  
  AlwaysAnimatedModel() {
    // Update every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
