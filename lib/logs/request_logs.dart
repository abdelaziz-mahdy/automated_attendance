// lib/logs/request_logs.dart

import 'package:flutter/foundation.dart';

class ListNotifier extends ValueNotifier<List<String>> {
  ListNotifier() : super([]);

  void add(String listItem) {
    value.add(listItem);
    notifyListeners(); // here
  }
}

class RequestLogs {
  /// Holds the list of log strings in a [ValueNotifier].
  /// Whenever you update [logsNotifier.value], any UI
  /// that is listening will rebuild automatically.
  static final ListNotifier logsNotifier = ListNotifier();

  /// Adds a new log entry and notifies listeners.
  static void add(String log) {
    logsNotifier.value.add(log);
  }

  /// A convenience getter to fetch the current logs list.
  static List<String> get all => logsNotifier.value;
}
