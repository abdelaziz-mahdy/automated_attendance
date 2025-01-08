import 'dart:io';

import 'package:automated_attendance/services/face_comparison_service.dart';
import 'package:automated_attendance/services/face_extraction_service.dart';
import 'package:automated_attendance/services/face_features_extraction_service.dart';
import 'package:automated_attendance/views/camera_source_selection_view.dart';
import 'package:automated_attendance/views/data_center_view.dart';
import 'package:automated_attendance/views/request_logs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeServices();

  runApp(MyApp());
}

Future<String> _copyAssetFileToTmp(String assetPath) async {
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
      await _copyAssetFileToTmp("assets/face_detection_yunet_2023mar.onnx");
  final faceFeaturesExtractionModelPath =
      await _copyAssetFileToTmp("assets/face_recognition_sface_2021dec.onnx");
  // Initialize services
  faceExtractionService.initialize(faceDetectionModelPath);
  faceFeaturesExtractionService.initialize(faceFeaturesExtractionModelPath);
  faceComparisonService.initialize(faceFeaturesExtractionModelPath);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Grid',
      initialRoute: '/',
      routes: {
        '/': (context) => CameraSourceSelectionView(),
        '/dataCenter': (context) => DataCenterView(),
        '/requestLogsPage': (context) => RequestLogsPage(),
      },
    );
  }
}
