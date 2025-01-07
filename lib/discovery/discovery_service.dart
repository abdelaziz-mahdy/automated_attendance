import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

class DiscoveryService {
  // Singleton instance
  static final DiscoveryService _instance = DiscoveryService._internal();

  factory DiscoveryService() => _instance;

  DiscoveryService._internal();

  BonsoirDiscovery? _discovery;

  final StreamController<BonsoirDiscoveryEvent> _eventController =
      StreamController<BonsoirDiscoveryEvent>.broadcast();

  Stream<BonsoirDiscoveryEvent> get eventStream => _eventController.stream;

  Future<void> startDiscovery(String serviceType) async {
    if (_discovery == null) {
      _discovery = BonsoirDiscovery(type: serviceType);
      await _discovery!.ready;
      _discovery!.eventStream!.listen((event) {
        _eventController.add(event);
        if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
          print('Service found: ${event.service?.toJson()}');
        } else if (event.type ==
            BonsoirDiscoveryEventType.discoveryServiceLost) {
          print('Service lost: ${event.service?.toJson()}');
        }
      });
    }
    await _discovery!.start();
  }

  Future<void> dispose() async {
    await _eventController.close();
  }

  Future<void> stopDiscovery() async {
    if (_discovery != null) {
      await _discovery!.stop();
      _discovery = null;
    }
  }
}
