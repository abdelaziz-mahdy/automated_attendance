// lib/views/request_logs_page.dart
import 'package:flutter/material.dart';
import 'package:automated_attendance/logs/request_logs.dart';

class RequestLogsPage extends StatelessWidget {
  const RequestLogsPage({super.key});

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
}
