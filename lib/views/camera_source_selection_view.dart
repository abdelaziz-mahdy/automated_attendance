import 'package:flutter/material.dart';

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
      appBar: AppBar(
        title: const Text("Select Mode"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Intro / instructions
            Text(
              "Choose how you'd like to run the application.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "You can either broadcast your camera (Provider) or discover and view other cameras (Data Center).",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const Spacer(),

            // Button: Camera Provider
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/requestLogsPage');
              },
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text("Start as Camera Provider"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                textStyle: const TextStyle(fontSize: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Button: Data Center
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/dataCenter');
              },
              icon: const Icon(Icons.cloud_outlined),
              label: const Text("Start as Data Center"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                textStyle: const TextStyle(fontSize: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const Spacer(),
            // Optional branding or version info at bottom
            Text(
              "v1.0.0",
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
