import 'package:cameras_viewer/services/face_comparison_service.dart';
import 'package:cameras_viewer/services/face_extraction_service.dart';
import 'package:cameras_viewer/services/face_features_extraction_service.dart';
import 'package:cameras_viewer/views/camera_grid_view.dart';
import 'package:cameras_viewer/models/camera_model.dart';
import 'package:cameras_viewer/services/camera_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  final faceExtractionService = FaceExtractionService();
  final faceFeaturesExtractionService = FaceFeaturesExtractionService();
  final faceComparisonService = FaceComparisonService();

  final faceDetectionModelPath = 'assets/face_detection_yunet_2023mar.onnx';
  final faceRecognitionModelPath = 'assets/face_recognition_sface_2021dec.onnx';

  // Initialize services
  faceExtractionService.initialize(faceDetectionModelPath);
  faceFeaturesExtractionService.initialize(faceRecognitionModelPath);
  faceComparisonService.initialize(faceRecognitionModelPath);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CameraModel(CameraService()),
        ),
      ],
      child: MaterialApp(
        title: 'Camera Grid',
        home: CameraGridView(),
      ),
    );
  }
}
