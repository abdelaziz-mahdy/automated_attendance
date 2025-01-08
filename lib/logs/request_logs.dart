// lib/logs/request_logs.dart

class RequestLogs {
  // Internal list that holds the log entries
  static final List<String> _logs = [];

  /// Adds a new log entry
  static void add(String log) {
    _logs.add(log);
    // If you want real-time updates in your UI, 
    // you could do something like notifyListeners 
    // or use a Stream.
  }

  /// Provides read-only access to the logs
  static List<String> get all => _logs;
}
