import 'package:cameras_viewer/views/camera_grid_view.dart';
import 'package:cameras_viewer/models/camera_model.dart';
import 'package:cameras_viewer/services/camera_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
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
