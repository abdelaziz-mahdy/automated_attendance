import 'dart:async';
import 'package:automated_attendance/discovery/broadcast_service.dart';
import 'package:automated_attendance/discovery/discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BroadcastService broadcastService1;
  late BroadcastService broadcastService2;
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
    broadcastService1 = BroadcastService();
    broadcastService2 = BroadcastService();
    discoveryService = DiscoveryService();
  });

  tearDown(() async {
    await broadcastService1.dispose();
    await broadcastService2.dispose();
    await discoveryService.dispose();
  });

  test('Single service discovery test', () async {
    const String testName = 'Test Service';
    const String testType = '_example._tcp';
    const int testPort = 4040;

    final serviceFoundCompleter = Completer<void>();
    bool serviceFound = false;

    // Listen for discovery events
    final subscription = discoveryService.discoveryStream.listen((service) {
      if (service.name == testName && service.type == testType) {
        serviceFound = true;
        if (!serviceFoundCompleter.isCompleted) {
          serviceFoundCompleter.complete();
        }
      }
    });

    // Start discovery
    await discoveryService.startDiscovery(
      serviceType: testType,
      port: testPort,
      timeout: const Duration(seconds: 5),
      cleanupInterval: const Duration(seconds: 1),
    );

    // Give discovery a moment to bind
    await Future.delayed(const Duration(milliseconds: 500));

    // Start broadcasting
    await broadcastService1.startBroadcast(
      serviceName: testName,
      serviceType: testType,
      port: testPort,
      broadcastInterval: const Duration(milliseconds: 300),
    );

    // Wait up to 5 seconds for the service to be found
    await serviceFoundCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () =>
          throw TimeoutException('Service was not discovered in time.'),
    );

    expect(serviceFound, isTrue);
    expect(
        discoveryService.activeServices.any(
          (s) => s.name == testName && s.type == testType,
        ),
        isTrue);

    // Cleanup
    await subscription.cancel();
    await broadcastService1.stopBroadcast();
    await discoveryService.stopDiscovery();
  });

  test('Multiple services and removal test', () async {
    const String serviceName1 = 'Test Service 1';
    const String serviceName2 = 'Test Service 2';
    const String testType = '_example._tcp';
    const int testPort = 5050;

    final service1FoundCompleter = Completer<void>();
    final service2FoundCompleter = Completer<void>();

    // Listen for discovery events
    final subscription = discoveryService.discoveryStream.listen((service) {
      if (service.name == serviceName1 && service.type == testType) {
        if (!service1FoundCompleter.isCompleted) {
          service1FoundCompleter.complete();
        }
      }
      if (service.name == serviceName2 && service.type == testType) {
        if (!service2FoundCompleter.isCompleted) {
          service2FoundCompleter.complete();
        }
      }
    });

    // Start discovery
    await discoveryService.startDiscovery(
      serviceType: testType,
      port: testPort,
      // We'll give a short timeout for removal
      timeout: const Duration(seconds: 3),
      cleanupInterval: const Duration(seconds: 1),
    );

    // Start broadcasting two services
    await broadcastService1.startBroadcast(
      serviceName: serviceName1,
      serviceType: testType,
      port: testPort,
      broadcastInterval: const Duration(milliseconds: 300),
    );
    await broadcastService2.startBroadcast(
      serviceName: serviceName2,
      serviceType: testType,
      port: testPort,
      broadcastInterval: const Duration(milliseconds: 300),
    );

    // Wait for both services to be found
    await service1FoundCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () =>
          throw TimeoutException('Service 1 not discovered in time'),
    );
    await service2FoundCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () =>
          throw TimeoutException('Service 2 not discovered in time'),
    );

    // Check that both are active
    expect(
      discoveryService.activeServices
          .where((s) => s.name == serviceName1)
          .length,
      1,
      reason: 'Service 1 should be in active services',
    );
    expect(
      discoveryService.activeServices
          .where((s) => s.name == serviceName2)
          .length,
      1,
      reason: 'Service 2 should be in active services',
    );

    // Now stop broadcasting Service 2
    await broadcastService2.stopBroadcast();

    // Wait enough time for service 2 to expire (3 seconds + some buffer)
    await Future.delayed(const Duration(seconds: 5));

    // Check that Service 2 is removed, but Service 1 remains
    expect(
      discoveryService.activeServices
          .where((s) => s.name == serviceName1)
          .length,
      1,
      reason: 'Service 1 should still be active',
    );
    expect(
      discoveryService.activeServices
          .where((s) => s.name == serviceName2)
          .isEmpty,
      true,
      reason: 'Service 2 should have been removed due to inactivity',
    );

    // Cleanup
    await subscription.cancel();
    await broadcastService1.stopBroadcast();
    await discoveryService.stopDiscovery();
  });
}
