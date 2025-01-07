import 'package:automated_attendance/discovery/broadcast_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Broadcast Service should start and stop', () async {
    final broadcastService = BroadcastService();

    // Start broadcasting
    await broadcastService.startBroadcast('Test Service', '_example._tcp', 4040);
    expect(broadcastService, isNotNull);

    // Stop broadcasting
    await broadcastService.stopBroadcast();
    expect(broadcastService, isNotNull);
  });
}
