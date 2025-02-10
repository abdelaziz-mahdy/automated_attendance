// lib/views/request_logs_page.dart
import 'package:automated_attendance/services/start_camera_provider_server.dart';
import 'package:flutter/material.dart';
import 'package:automated_attendance/logs/request_logs.dart';

class RequestLogsPage extends StatefulWidget {
  const RequestLogsPage({super.key});

  @override
  State<RequestLogsPage> createState() => _RequestLogsPageState();
}

class _RequestLogsPageState extends State<RequestLogsPage> {
  late CameraProviderServer _cameraProviderServer;
  int _totalFramesSent = 0;
  DateTime? _serverStartTime;
  DateTime? _serverEndTime;
  final List<int> _frameResponseTimes =
      []; // List to store response times for each frame
  double _averageResponseTime = 0.0;
  int _maxFramesPossible = 0;

  @override
  void initState() {
    super.initState();
    _cameraProviderServer = CameraProviderServer();
    _startServer();
  }

  void _startServer() {
    _cameraProviderServer.start().then((_) {
      setState(() {
        _serverStartTime = DateTime.now();
        _totalFramesSent = 0; // Reset frame count on restart
        _serverEndTime = null; // Clear end time
        _frameResponseTimes.clear(); // Clear previous response times
        _averageResponseTime = 0.0;
        _maxFramesPossible = 0;
      });

      // Listen for frame updates
      RequestLogs.logsNotifier.addListener(_updateFrameCount);
    });
  }

  void _stopServer() {
    _cameraProviderServer.stop().then((_) {
      // Stop listening
      RequestLogs.logsNotifier.removeListener(_updateFrameCount);
      if (mounted) {
        setState(() {
          _serverEndTime = DateTime.now();
        });
      }
    });
  }

  void _updateFrameCount() {
    // Check the latest log entry for successful frame transmission
    if (RequestLogs.all.isNotEmpty &&
        RequestLogs.all.first.contains("Handled /get_image in") &&
        RequestLogs.all.first.contains("(Success)")) {
      // Extract response time from the log entry
      final log = RequestLogs.all.first;
      final start = log.indexOf("in") + 3;
      final end = log.indexOf("ms", start);
      if (start >= 0 && end > start) {
        final timeString = log.substring(start, end).trim();
        final responseTime = int.tryParse(timeString);
        if (responseTime != null) {
          setState(() {
            _totalFramesSent++;
            _frameResponseTimes.add(responseTime);
            _averageResponseTime = _frameResponseTimes.reduce((a, b) => a + b) /
                _frameResponseTimes.length;
            _maxFramesPossible =
                ((1000 / (_averageResponseTime > 0 ? _averageResponseTime : 1)))
                    .toInt(); // Avoid division by zero
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _stopServer(); // Stop the server
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Camera Provider Logs"),
        actions: [
          if (_serverEndTime == null) // Show stop button if running
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopServer,
              tooltip: "Stop Server",
            )
          else // Show start button if stopped
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _startServer,
              tooltip: "Start Server",
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Statistics Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Server Statistics",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildStatRow("Status:",
                        _serverEndTime == null ? "Running" : "Stopped"),
                    _buildStatRow("Start Time:", _serverStartTime),
                    _buildStatRow("End Time:", _serverEndTime),
                    _buildStatRow("Total Frames Sent:", _totalFramesSent),
                    _buildStatRow(
                        "Avg. Frame Response Time:",
                        _averageResponseTime > 0
                            ? "${_averageResponseTime.toStringAsFixed(2)} ms"
                            : "N/A"),
                    if (_serverStartTime != null && _serverEndTime != null)
                      _buildStatRow(
                        "Uptime:",
                        _serverEndTime!.difference(_serverStartTime!),
                      ),
                    if (_maxFramesPossible > 0)
                      _buildStatRow(
                          "Est. Max Frames Possible:", _maxFramesPossible),
                  ],
                ),
              ),
            ),
          ),
          // Logs Section
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: RequestLogs.logsNotifier,
              builder: (context, logs, child) {
                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    return _buildLogEntry(logs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(
            value is DateTime
                ? value.toLocal().toString()
                : value is Duration
                    ? value.toString().split('.').first
                    : value.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(String log) {
    IconData? icon;
    Color? color;

    if (log.contains("Error")) {
      icon = Icons.error_outline;
      color = Colors.red;
    } else if (log.contains("Handled /get_image in") &&
        log.contains("(Success)")) {
      icon = Icons.check_circle_outline;
      color = Colors.green;
    } else if (log.contains("404")) {
      icon = Icons.warning_amber;
      color = Colors.orange;
    } else {
      icon = Icons.info_outline;
      color = Colors.blue;
    }

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(log),
      dense: true,
    );
  }
}
