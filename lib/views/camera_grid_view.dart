import 'package:automated_attendance/discovery/service_info.dart';
import 'package:automated_attendance/models/camera_model.dart';
import 'package:automated_attendance/widgets/camera_preview_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CameraGridView extends StatefulWidget {
  const CameraGridView({super.key});

  @override
  State<CameraGridView> createState() => _CameraGridViewState();
}

class _CameraGridViewState extends State<CameraGridView> {
  late CameraModel cameraModel;
  late String source;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    cameraModel = Provider.of<CameraModel>(context, listen: false);
    source = ModalRoute.of(context)!.settings.arguments as String;
    cameraModel.fetchCameras(source);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Camera Grid')),
      body: Consumer<CameraModel>(
        builder: (context, model, child) {
          if (model.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          final cameras =
              source == 'local' ? model.cameraIndices : model.serverCameras;

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.0,
            ),
            itemCount: cameras.length,
            itemBuilder: (context, index) {
              final camera = cameras[index];
              return CameraPreviewWidget(
                cameraIndex: (source == 'local' ? camera : null) as int,
                serverInfo: (source == 'server' ? camera : null) as ServiceInfo,
              );
            },
          );
        },
      ),
    );
  }
}
