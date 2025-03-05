import 'dart:io';

import 'package:automated_attendance/controllers/ui_state_controller.dart';
import 'package:automated_attendance/services/camera_manager_service.dart';
import 'package:automated_attendance/services/face_comparison_service.dart';
import 'package:automated_attendance/services/face_extraction_service.dart';
import 'package:automated_attendance/services/face_features_extraction_service.dart';
import 'package:automated_attendance/services/face_management_service.dart';
import 'package:automated_attendance/views/camera_source_selection_view.dart';
import 'package:automated_attendance/views/data_center_view.dart';
import 'package:automated_attendance/views/request_logs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeServices();
  await initializeSharedPreferences(); // Initialize SharedPreferences
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) print('Error: ${record.error}');
    if (record.stackTrace != null) print('Stack: ${record.stackTrace}');
  });
  runApp(MyApp());
}

Future<String> copyAssetFileToTmp(String assetPath) async {
  final tmpDir = await getTemporaryDirectory();
  final tmpPath = '${tmpDir.path}/${assetPath.split('/').last}';
  final byteData = await rootBundle.load(assetPath);
  final file = File(tmpPath);
  await file.writeAsBytes(byteData.buffer.asUint8List());
  return tmpPath;
}

Future<void> initializeServices() async {
  final faceExtractionService = FaceExtractionService();
  final faceFeaturesExtractionService = FaceFeaturesExtractionService();
  final faceComparisonService = FaceComparisonService();

  final faceDetectionModelPath =
      await copyAssetFileToTmp("assets/face_detection_yunet_2023mar.onnx");
  final faceFeaturesExtractionModelPath =
      await copyAssetFileToTmp("assets/face_recognition_sface_2021dec.onnx");

  // Initialize services
  faceExtractionService.initialize(faceDetectionModelPath);
  faceFeaturesExtractionService.initialize(faceFeaturesExtractionModelPath);
  faceComparisonService.initialize(faceFeaturesExtractionModelPath);
}

// Initialize shared preferences with default values
Future<void> initializeSharedPreferences() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Set default FPS if not already set
  if (!prefs.containsKey('fps')) {
    await prefs.setInt('fps', 10); // Default FPS
  }

  // Set default max faces if not already set
  if (!prefs.containsKey('maxFaces')) {
    await prefs.setInt('maxFaces', 10); // Default max faces
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Create the service providers
        ChangeNotifierProvider(
          create: (context) => FaceManagementService(),
        ),
        ChangeNotifierProxyProvider<FaceManagementService,
            CameraManagerService>(
          create: (context) => CameraManagerService(
            Provider.of<FaceManagementService>(context, listen: false),
          ),
          update: (context, faceManagementService, previous) =>
              previous ?? CameraManagerService(faceManagementService),
        ),
        ChangeNotifierProxyProvider2<FaceManagementService,
            CameraManagerService, UIStateController>(
          create: (context) => UIStateController(
            Provider.of<FaceManagementService>(context, listen: false),
            Provider.of<CameraManagerService>(context, listen: false),
          ),
          update: (context, faceManagementService, cameraManagerService,
                  previous) =>
              previous ??
              UIStateController(faceManagementService, cameraManagerService),
        ),
      ],
      child: MaterialApp(
        title: 'Automated Attendance',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        routes: {
          '/': (context) => CameraSourceSelectionView(),
          '/dataCenter': (context) => Consumer<UIStateController>(
                builder: (context, controller, child) {
                  // Start the controller's services when this route is accessed
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    controller.start();
                  });
                  return DataCenterView();
                },
              ),
          '/requestLogsPage': (context) => RequestLogsPage(),
        },
      ),
    );
  }
}
