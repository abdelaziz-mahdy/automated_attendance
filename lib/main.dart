import 'dart:io';
import 'package:automated_attendance/controllers/ui_state_controller.dart';
import 'package:automated_attendance/services/face_comparison_service.dart';
import 'package:automated_attendance/services/face_extraction_service.dart';
import 'package:automated_attendance/services/face_features_extraction_service.dart';
import 'package:automated_attendance/views/camera_source_selection_view.dart';
import 'package:automated_attendance/views/data_center_view.dart';
import 'package:automated_attendance/views/data_center_pages/person_visits_view.dart';
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
  await initializeSharedPreferences();
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

  faceExtractionService.initialize(faceDetectionModelPath);
  faceFeaturesExtractionService.initialize(faceFeaturesExtractionModelPath);
  faceComparisonService.initialize(faceFeaturesExtractionModelPath);
}

Future<void> initializeSharedPreferences() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  if (!prefs.containsKey('fps')) {
    await prefs.setInt('fps', 10);
  }

  if (!prefs.containsKey('maxFaces')) {
    await prefs.setInt('maxFaces', 10);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => UIStateController(),
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
                  controller.start();
                  return DataCenterView();
                },
              ),
          '/requestLogsPage': (context) => RequestLogsPage(),
        },
        // Add onGenerateRoute to handle routes with arguments
        onGenerateRoute: (settings) {
          if (settings.name == '/personVisits') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => PersonVisitsView(
                faceId: args['faceId'],
                personName: args['personName'],
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
