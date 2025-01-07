import 'package:automated_attendance/discovery/broadcast_service.dart';
import 'package:automated_attendance/discovery/discovery_service.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Discovery and Broadcast Integration Test', () {
    final broadcastService = BroadcastService();
    final discoveryService = DiscoveryService();
    const String testName = 'Test Service';
    const String testType = '_example._tcp';
    const int testPort = 4040;

    setUp(() async {
      // Start the broadcast service
      await broadcastService.startBroadcast(testName, testType, testPort);
    });

    tearDown(() async {
      // Stop both services after each test
      await broadcastService.stopBroadcast();
      await discoveryService.stopDiscovery();
    });

    test('Broadcast service is discoverable', () async {
      // Start discovery service
      await discoveryService.startDiscovery(testType);

      // Wait for a short duration to allow discovery to find the service
      await Future.delayed(Duration(seconds: 2));

      // Validate discovery by capturing events
      bool serviceFound = false;
      discoveryService.eventStream.listen((event) {
        if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
          serviceFound = true;
          expect(event.service!.name, equals(testName));
          expect(event.service!.port, equals(testPort));
          expect(event.service!.type, equals(testType));
        }
      });

      // Allow time for discovery events to be processed
      await Future.delayed(Duration(seconds: 3));

      // Assert that the service was found
      expect(serviceFound, isTrue);
    });
  });
}
