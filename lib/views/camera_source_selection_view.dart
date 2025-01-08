import 'package:automated_attendance/services/start_camera_provider_server.dart';
import 'package:flutter/material.dart';
// Contains startCameraProviderServer()
// or you can move it to a dedicated file

class CameraSourceSelectionView extends StatefulWidget {
  const CameraSourceSelectionView({super.key});

  @override
  State<CameraSourceSelectionView> createState() =>
      _CameraSourceSelectionViewState();
}

class _CameraSourceSelectionViewState extends State<CameraSourceSelectionView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Select Mode")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {
              // 2. Navigate to logs page
              Navigator.pushNamed(context, '/requestLogsPage');
            },
            child: Text("Start As Camera Provider"),
          ),
          ElevatedButton(
            onPressed: () {
              // Start as data center (discover other camera providers)
              Navigator.pushNamed(context, '/dataCenter');
            },
            child: Text("Start As Data Center"),
          ),
        ],
      ),
    );
  }
}
