// discovery_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:automated_attendance/discovery/service_info.dart';
import 'package:logging/logging.dart';

final _logger = Logger('HttpScanDiscovery');

class DiscoveryService {
  static final DiscoveryService _instance = DiscoveryService._internal();
  factory DiscoveryService() => _instance;
  DiscoveryService._internal();

  final _discoveryStreamController = StreamController<ServiceInfo>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  RawDatagramSocket? _socket;
  bool _isDiscovering = false;
  final Map<String, ServiceInfo> _discoveredServices = {};
  Timer? _cleanupTimer;

  Stream<ServiceInfo> get discoveryStream => _discoveryStreamController.stream;
  Stream<String> get errors => _errorController.stream;

  Future<void> startDiscovery({
    required String serviceType,
    required int port, // Add port parameter
    Duration timeout = const Duration(seconds: 30),
    Duration cleanupInterval = const Duration(seconds: 10),
  }) async {
    if (_isDiscovering) {
      _logger.warning('Discovery already in progress');
      return;
    }

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port, // Use the specified port instead of 0
        reuseAddress: true,
        reusePort: true,
      );

      _socket!.listen(
        _handleDatagramEvent,
        onError: (error) {
          _errorController.add('Socket error: $error');
          _logger.severe('Socket error', error);
        },
        cancelOnError: false,
      );

      _cleanupTimer = Timer.periodic(cleanupInterval, (timer) {
        _cleanupStaleServices(timeout);
      });

      _isDiscovering = true;
      _logger.info('Started discovery for service: $serviceType on port $port');
    } catch (e) {
      _errorController.add('Failed to start discovery: $e');
      _logger.severe('Failed to start discovery', e);
      await stopDiscovery();
    }
  }

  void _handleDatagramEvent(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket!.receive();
      
      if (datagram != null) {
        try {
          final data = utf8.decode(datagram.data);
          final json = jsonDecode(data) as Map<String, dynamic>;
          final serviceInfo = ServiceInfo.fromJson(json);
          
          // Update or add service to discovered services

          _discoveredServices[serviceInfo.id] = serviceInfo;

          _discoveryStreamController.add(serviceInfo);
          _logger
              .info('Discovered service: ${serviceInfo.name} with data $json');
        } catch (e) {
          _errorController.add('Failed to decode discovery message: $e');
          _logger.warning('Failed to decode discovery message', e);
        }
      }
    }
  }

  void _cleanupStaleServices(Duration timeout) {
    final now = DateTime.now();
    _discoveredServices.removeWhere((id, serviceInfo) {
      /// convert string to DateTime
      DateTime lastSeen =
          DateTime.fromMillisecondsSinceEpoch(int.parse(serviceInfo.id));
      return now.difference(lastSeen) > timeout;
    });
  }

  Future<void> stopDiscovery() async {
    if (_isDiscovering) {
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
      _socket?.close();
      _socket = null;
      _isDiscovering = false;
      _discoveredServices.clear();
      _logger.info('Stopped discovery');
    }
  }

  Future<void> dispose() async {
    await stopDiscovery();
    await _discoveryStreamController.close();
    await _errorController.close();
  }

  bool get isDiscovering => _isDiscovering;
  List<ServiceInfo> get activeServices => _discoveredServices.values.toList();
}
