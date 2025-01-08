// lib/views/request_logs_page.dart
import 'package:flutter/material.dart';
import 'package:automated_attendance/logs/request_logs.dart';

class RequestLogsPage extends StatefulWidget {
  const RequestLogsPage({Key? key}) : super(key: key);

  @override
  State<RequestLogsPage> createState() => _RequestLogsPageState();
}

class _RequestLogsPageState extends State<RequestLogsPage> {
  @override
  void initState() {
    super.initState();
    // If you want real-time updates, you could use a Timer,
    // a StreamBuilder, or implement something like setState() callbacks
    // whenever a new log is added.
  }

  @override
  Widget build(BuildContext context) {
    final logs = RequestLogs.all;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Logs"),
      ),
      body: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(logs[index]),
          );
        },
      ),
    );
  }
}
