import 'dart:async';
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

  // Timer to periodically refresh service list
  Timer? _refreshTimer;

  List<ServiceInfo> _discoveredProviders = [];
  // key: address (or service.id), value: ICameraProvider
  final Map<String, ICameraProvider> _activeProviders = {};

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  void _startDiscovery() async {
    // Start discovering services
    await _discoveryService.startDiscovery(
      serviceType: '_camera._tcp',
    );

    // Listen for newly discovered services
    _discoveryService.discoveryStream.listen((serviceInfo) async {
      _discoveredProviders = _discoveryService.activeServices;

      final address = serviceInfo.address;
      final port = serviceInfo.port;
      if (address == null) return;
      if (port == null) return;

      // If not already active, open a new RemoteCameraProvider
      if (!_activeProviders.containsKey(address)) {
        final provider = RemoteCameraProvider(
          serverAddress: address,
          serverPort: port,
        );

        final opened = await provider.openCamera();
        debugPrint("Opened remote camera: ${serviceInfo.toJson()}: $opened");

        if (opened && mounted) {
          setState(() {
            _activeProviders[address] = provider;
          });
        }
      }
    });
    _discoveryService.removeStream.listen((serviceInfo) {
      _discoveredProviders = _discoveryService.activeServices;

      final address = serviceInfo.address;
      if (address == null) return;

      final provider = _activeProviders[address];
      if (provider != null) {
        provider.closeCamera();
        _activeProviders.remove(address);
      }
      print("Removed service: ${serviceInfo.toJson()}");
      if (mounted){
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _stopDiscovery();
    super.dispose();
  }

  void _stopDiscovery() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    // Stop discovering
    await _discoveryService.stopDiscovery();

    // Close all active camera providers
    for (var provider in _activeProviders.values) {
      await provider.closeCamera();
    }
    _activeProviders.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Center: Discovered Providers"),
      ),
      body: _discoveredProviders.isEmpty
          ? const Center(child: Text("No active services found."))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _discoveredProviders.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // You can adjust how many columns you want
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.7, // Adjust to taste (width/height)
              ),
              itemBuilder: (context, index) {
                final service = _discoveredProviders[index];
                final address = service.address ?? '';
                final provider = _activeProviders[address];

                return Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Text(
                          service.name ?? "Unknown Service",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text("Address: $address"),
                        const SizedBox(height: 8),
                        Expanded(
                          // If provider is null, show a placeholder or loader
                          child: provider == null
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : DataCenterCameraPreview(
                                  provider: provider,
                                  providerName:
                                      service.name ?? "Unknown Provider",
                                  // Optionally pass a different 'fps' if you want
                                  // to poll each preview at a different rate
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
