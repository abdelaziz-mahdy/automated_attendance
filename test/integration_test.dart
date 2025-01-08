import 'dart:async';

import 'package:automated_attendance/discovery/broadcast_service.dart';
import 'package:automated_attendance/discovery/discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  late BroadcastService broadcastService;
  late DiscoveryService discoveryService;

  setUpAll(() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
      if (record.error != null) print('Error: ${record.error}');
      if (record.stackTrace != null) print('Stack: ${record.stackTrace}');
    });
  });

  setUp(() {
    broadcastService = BroadcastService();
    discoveryService = DiscoveryService();
  });

  tearDown(() async {
    await broadcastService.dispose();
    await discoveryService.dispose();
  });

  test('Discovery and Broadcast integration test', () async {
    const String testName = 'Test Service';
    const String testType = '_example._tcp';
    const int testPort = 4040; // We'll use this same port for both services

    final serviceFoundCompleter = Completer<void>();
    bool serviceFound = false;

    // Listen for discovery events
    final subscription = discoveryService.discoveryStream.listen((service) {
      print('Discovered service: ${service.name} (${service.type})');
      if (service.name == testName && service.type == testType) {
        serviceFound = true;
        if (!serviceFoundCompleter.isCompleted) {
          serviceFoundCompleter.complete();
        }
      }
    });

    // Listen for errors with detailed logging
    discoveryService.errors.listen((error) {
      print('Discovery error: $error');
    });
    broadcastService.errors.listen((error) {
      print('Broadcast error: $error');
    });

    try {
      print('Starting discovery service on port $testPort...');
      await discoveryService.startDiscovery(
        serviceType: testType,
        port: testPort, // Specify the port
        timeout: const Duration(seconds: 30),
        cleanupInterval: const Duration(seconds: 5),
      );
      print('Discovery service started');

      // Add a small delay before starting broadcast
      await Future.delayed(const Duration(seconds: 1));

      print('Starting broadcast service...');
      await broadcastService.startBroadcast(
        serviceName: testName,
        serviceType: testType,
        port: testPort,
        broadcastInterval: const Duration(milliseconds: 200),
      );
      print('Broadcast service started');

      // Periodically log status and active services
      final statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        print('Status - Broadcasting: ${broadcastService.isBroadcasting}, '
            'Discovering: ${discoveryService.isDiscovering}, '
            'Service Found: $serviceFound');
        print(
            'Active services: ${discoveryService.activeServices.map((s) => s.name).toList()}');
      });

      try {
        await serviceFoundCompleter.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException(
                'Service was not discovered within the expected timeframe.\n'
                'Broadcasting: ${broadcastService.isBroadcasting}\n'
                'Discovering: ${discoveryService.isDiscovering}\n'
                'Active services: ${discoveryService.activeServices}');
          },
        );
        print(
            "active services: ${discoveryService.activeServices.map((s) => s.toJson()).toList()}");

        expect(
          discoveryService.activeServices.any(
            (service) => service.name == testName && service.type == testType,
          ),
          isTrue,
          reason: 'Service should be listed in active services',
        );
      } finally {
        statusTimer.cancel();
      }
    } finally {
      print('Cleaning up...');
      await subscription.cancel();
      await broadcastService.stopBroadcast();
      await discoveryService.stopDiscovery();
      print('Cleanup complete');
    }
  });
}
