import 'package:bonsoir/bonsoir.dart';

class BroadcastService {
  // Singleton instance
  static final BroadcastService _instance = BroadcastService._internal();

  factory BroadcastService() => _instance;

  BroadcastService._internal();

  BonsoirBroadcast? _broadcast;

  Future<void> startBroadcast(String name, String type, int port) async {
    if (_broadcast == null) {
      final service = BonsoirService(name: name, type: type, port: port);
      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.ready;
    }
    await _broadcast!.start();
  }

  Future<void> stopBroadcast() async {
    if (_broadcast != null) {
      await _broadcast!.stop();
      _broadcast = null;
    }
  }
}
