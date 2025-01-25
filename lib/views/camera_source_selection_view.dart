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
      body: Center(
        // Center the content on the screen
        child: Container(
          // Limit width for larger screens
          constraints:
              const BoxConstraints(maxWidth: 600), // Adjust max width as needed
          padding:
              const EdgeInsets.all(40.0), // Increased padding around content
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center, // Center content vertically
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Stretch buttons horizontally
            children: [
              // Intro / instructions - More prominent title
              Text(
                "Welcome!",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24), // Increased spacing
              Text(
                "Choose how you'd like to run the application.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 12), // Increased spacing
              Text(
                "You can either broadcast your camera as a Provider, making it discoverable on the network, or start as a Data Center to discover and view cameras from other Providers.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      // bodyLarge for better readability
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 48), // Even more spacing before buttons

              // Button: Camera Provider - No more Card
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/requestLogsPage');
                },
                icon: const Icon(Icons.videocam,
                    size: 28, color: Colors.white), // Larger icon
                label: const Text("Start as Camera Provider",
                    style: TextStyle(fontSize: 18)), // Larger text
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  backgroundColor:
                      Theme.of(context).primaryColor, // Use primary color
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24, // Increased horizontal padding
                    vertical: 16, // Increased vertical padding
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                  elevation: 4, // Still keep a bit of elevation for visual lift
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12), // Keep rounded corners
                  ),
                ),
              ),
              const SizedBox(height: 24), // Spacing between buttons

              // Button: Data Center - No more Card
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/dataCenter');
                },
                icon: const Icon(
                  Icons.cloud,
                  size: 28,
                  color: Colors.white,
                ), // Larger icon
                label: const Text("Start as Data Center",
                    style: TextStyle(fontSize: 18)), // Larger text
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  backgroundColor:
                      Theme.of(context).primaryColor, // Use primary color
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24, // Increased horizontal padding
                    vertical: 16, // Increased vertical padding
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                  elevation: 4, // Still keep a bit of elevation for visual lift
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12), // Keep rounded corners
                  ),
                ),
              ),

              const Spacer(),
              // Optional branding or version info at bottom - Slightly larger and more visible
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Version 1.0.0",
                  style: TextStyle(
                    color:
                        Colors.grey[600], // Darker grey for better visibility
                    fontSize: 14, // Slightly larger font size
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
