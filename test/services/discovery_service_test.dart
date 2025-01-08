import 'package:automated_attendance/discovery/discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Discovery Service should start and stop', () async {
    final discoveryService = DiscoveryService();

    // Start discovery
    await discoveryService.startDiscovery(serviceType: '_example._tcp', port: 4040);
    expect(discoveryService, isNotNull);

    // Stop discovery
    await discoveryService.stopDiscovery();
    expect(discoveryService, isNotNull);
  });
}
