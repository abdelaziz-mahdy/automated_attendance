import 'package:bonsoir/bonsoir.dart';
import 'package:logging/logging.dart';

final _logger = Logger('BroadcastService');

class BroadcastService {
  BonsoirBroadcast? _broadcast;
  bool _isBroadcasting = false;

  Future<void> startBroadcast({
    required String serviceName,
    required String serviceType,
    required int port,
    Map<String, String> attributes = const {},
  }) async {
    if (_isBroadcasting) {
      _logger.warning('Broadcasting already in progress');
      return;
    }

    try {
      final service = BonsoirService(
        name: serviceName,
        type: serviceType,
        port: port,
        attributes: attributes,
      );

      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.ready;
      await _broadcast!.start();

      _isBroadcasting = true;
      _logger.info('Started broadcasting service: $serviceName');
    } catch (e) {
      _logger.severe('Failed to start broadcast', e);
      await stopBroadcast();
    }
  }

  Future<void> stopBroadcast() async {
    if (_isBroadcasting) {
      await _broadcast?.stop();
      _broadcast = null;
      _isBroadcasting = false;
      _logger.info('Stopped broadcasting');
    }
  }

  bool get isBroadcasting => _isBroadcasting;
}
