import 'package:automated_attendance/camera_providers/i_camera_provider.dart';
import 'package:automated_attendance/camera_providers/remote_camera_provider.dart';
import 'package:automated_attendance/discovery/discovery_service.dart';
import 'package:automated_attendance/discovery/service_info.dart';
import 'package:automated_attendance/widgets/data_center_camera_preview.dart';
import 'package:flutter/material.dart';

class DataCenterView extends StatefulWidget {
  const DataCenterView({super.key});

  @override
  State<DataCenterView> createState() => _DataCenterViewState();
}

class _DataCenterViewState extends State<DataCenterView> {
  final DiscoveryService _discoveryService = DiscoveryService();
  List<ServiceInfo> _discoveredProviders = [];
  final Map<String, ICameraProvider> _activeProviders = {};

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  void _startDiscovery() async {
    // You might want to provide correct arguments for your service type & port
    await _discoveryService.startDiscovery(
      serviceType: '_camera._tcp',
      port: 12345, // or the known broadcast port
    );

    // Listen to new discovered services
    _discoveryService.discoveryStream.listen((serviceInfo) async {
      if (serviceInfo.address == null) return;
      if (!_activeProviders.containsKey(serviceInfo.address)) {
        // Create a remote camera provider for each discovered service
        final provider = RemoteCameraProvider(
          serverAddress: serviceInfo.address!,
          serverPort: 12345,
        );
        final opened = await provider.openCamera();
        print("Opened remote camera: to ${serviceInfo.toJson()}: $opened");
        if (opened) {
          if (mounted) {
            setState(() {
              _activeProviders[serviceInfo.address!] = provider;
              _discoveredProviders = _discoveryService.activeServices;
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _stopDiscovery();
  }

  void _stopDiscovery() async {
    await _discoveryService.stopDiscovery();
    for (var provider in _activeProviders.values) {
      await provider.closeCamera();
    }
    _activeProviders.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Data Center: Discovered Providers"),
      ),
      body: ListView.builder(
        itemCount: _discoveredProviders.length,
        itemBuilder: (context, index) {
          final service = _discoveredProviders[index];
          final provider = _activeProviders[service.id];
          return ListTile(
            title: Text(service.name ?? "Unknown Name"),
            subtitle: Text("Address: ${service.address}"),
            onTap: provider != null
                ? () {
                    // Navigate to a screen that shows frames from this provider
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DataCenterCameraPreview(
                          provider: provider,
                          providerName: service.name ?? "Unknown Provider",
                        ),
                      ),
                    );
                  }
                : null,
          );
        },
      ),
    );
  }
}
