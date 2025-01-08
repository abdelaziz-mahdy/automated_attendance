// broadcast_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:automated_attendance/discovery/service_info.dart';
import 'package:logging/logging.dart';

final _logger = Logger('HttpTargetDiscovery');

class BroadcastService {
  static final BroadcastService _instance = BroadcastService._internal();
  factory BroadcastService() => _instance;
  BroadcastService._internal();

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  bool _isBroadcasting = false;
  final Map<String, ServiceInfo> _activeServices = {};

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errors => _errorController.stream;

  // Helper to fetch local IP address
  Future<String?> _getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list();
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return null;
  }

  Future<void> startBroadcast({
    required String serviceName,
    required String serviceType,
    required int port,
    Map<String, dynamic>? attributes,
    Duration broadcastInterval = const Duration(seconds: 1),
  }) async {
    if (_isBroadcasting) {
      _logger.warning('Broadcasting already in progress');
      return;
    }

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
        reusePort: false,
      );
      _socket!.broadcastEnabled = true;

      // Retrieve the local IP address
      final localIp = await _getLocalIpAddress();

      final serviceInfo = ServiceInfo(
        name: serviceName,
        type: serviceType,
        address: localIp,
        attributes: attributes,
      );

      _activeServices[serviceInfo.id] = serviceInfo;

      _broadcastTimer = Timer.periodic(broadcastInterval, (timer) {
        if (!_isBroadcasting) {
          timer.cancel();
          return;
        }
        _broadcastService(serviceInfo, port);
      });

      _isBroadcasting = true;
      _logger.info('Started broadcasting service: $serviceName');
    } catch (e) {
      _errorController.add('Failed to start broadcast: $e');
      _logger.severe('Failed to start broadcast', e);
      await stopBroadcast();
    }
  }

  void _broadcastService(ServiceInfo serviceInfo, int port) {
    try {
      final data = utf8.encode(jsonEncode(serviceInfo.toJson()));
      _socket?.send(data, InternetAddress('255.255.255.255'), port);
    } catch (e) {
      _errorController.add('Failed to broadcast service: $e');
      _logger.warning('Failed to broadcast service', e);
    }
  }

  Future<void> stopBroadcast() async {
    if (_isBroadcasting) {
      _broadcastTimer?.cancel();
      _broadcastTimer = null;
      _socket?.close();
      _socket = null;
      _isBroadcasting = false;
      _activeServices.clear();
      _logger.info('Stopped broadcasting');
    }
  }

  Future<void> dispose() async {
    await stopBroadcast();
    await _errorController.close();
  }

  bool get isBroadcasting => _isBroadcasting;
}
