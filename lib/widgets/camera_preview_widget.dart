import 'dart:async';

import 'package:cameras_viewer/services/face_extraction_service.dart';
import 'package:cameras_viewer/services/face_features_extraction_service.dart';
import 'package:flutter/material.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class CameraPreviewWidget extends StatefulWidget {
  final int cameraIndex;

  const CameraPreviewWidget({Key? key, required this.cameraIndex})
      : super(key: key);

  @override
  _CameraPreviewWidgetState createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  late cv.VideoCapture _vc;
  late cv.Mat _frame;
  bool _isCameraOpen = false;
  Image? _image;
  double fps = 30;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _vc = cv.VideoCapture.fromDevice(widget.cameraIndex);
      if (_vc.isOpened) {
        _isCameraOpen = true;
        _frame = cv.Mat.empty();
        _updateFrame();
      }
    } catch (e) {
      _isCameraOpen = false;
    }
  }

  void _updateFrame() {
    if (!_isCameraOpen) return;

    timer = Timer.periodic(Duration(milliseconds: (1000 / fps).round()),
        (timer) async {
      if (!_isCameraOpen) {
        timer.cancel();
        return;
      }

      final (success, frame) = await _vc.readAsync();
      if (success) {
        _frame = frame;
        final faces = FaceExtractionService().extractFacesBoundaries(_frame);
        _frame =
            FaceFeaturesExtractionService().visualizeFaceDetect(_frame, faces);
        // print(_frame.sum().toString());
        final (success, image) = (await cv.imencodeAsync('.jpg', _frame));
        if (success == false) {
          // print('failed to encode image');
          return;
        }
        setState(() {
          _image = Image.memory(
            image,
            gaplessPlayback: true,
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraOpen) {
      return Center(child: Text('Unable to open camera ${widget.cameraIndex}'));
    }
    if (_image == null) {
      return Center(child: CircularProgressIndicator());
    }

    // print('camera index ${widget.cameraIndex} is open, with image $_image');
    return _image!;
  }

  @override
  void dispose() {
    _vc.release();
    _frame.dispose();
    timer?.cancel();
    super.dispose();
  }
}
