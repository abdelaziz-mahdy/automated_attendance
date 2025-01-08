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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Logs"),
      ),
      body: ValueListenableBuilder<List<String>>(
        valueListenable: RequestLogs.logsNotifier,
        builder: (context, logs, child) {
          // logs is the current list of log entries
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(logs[index]),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void initState() {
    CameraProviderServer().start();
    // TODO: implement initState
    super.initState();
  }

  @override
  void dispose() {
    CameraProviderServer().stop();
    RequestLogs.logsNotifier.clear();

    // TODO: implement dispose
    super.dispose();
  }
}
