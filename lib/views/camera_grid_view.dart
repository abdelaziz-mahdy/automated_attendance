import 'package:cameras_viewer/models/camera_model.dart';
import 'package:cameras_viewer/widgets/camera_preview_widget.dart';
import 'package:cameras_viewer/services/camera_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CameraGridView extends StatefulWidget {
  const CameraGridView({super.key});

  @override
  State<CameraGridView> createState() => _CameraGridViewState();
}

class _CameraGridViewState extends State<CameraGridView> {
  late CameraModel cameraModel = Provider.of<CameraModel>(context);
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cameraModel.fetchCameras();
    });
    // TODO: implement initState
    super.initState();
  }

  @override
  void didChangeDependencies() {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Camera Grid')),
      body: cameraModel.isLoading
          ? Center(child: CircularProgressIndicator())
          : GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Adjust the number of columns
                childAspectRatio: 1.0,
              ),
              itemCount: cameraModel.cameraIndices.length,
              itemBuilder: (context, index) {
                final cameraIndex = cameraModel.cameraIndices[index];
                return CameraPreviewWidget(cameraIndex: cameraIndex);
              },
            ),
    );
  }
}
