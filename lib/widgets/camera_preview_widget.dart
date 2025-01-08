import 'dart:async';
import 'dart:io';

import 'package:automated_attendance/discovery/service_info.dart';
import 'package:automated_attendance/services/face_extraction_service.dart';
import 'package:automated_attendance/services/face_features_extraction_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class CameraPreviewWidget extends StatefulWidget {
  final int? cameraIndex;
  final ServiceInfo? serverInfo;

  const CameraPreviewWidget({Key? key, this.cameraIndex, this.serverInfo})
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
    if (widget.cameraIndex != null) {
      _initCamera();
    } else if (widget.serverInfo != null) {
      _initRemoteCamera();
    }
  }

  Future<void> _initRemoteCamera() async {
    final url = 'http://${widget.serverInfo!.address}:12345/get_image';
    timer = Timer.periodic(Duration(milliseconds: 100), (_) async {
      try {
        final response = await HttpClient()
            .getUrl(Uri.parse(url))
            .then((req) => req.close());
        final bytes = await consolidateHttpClientResponseBytes(response);
        setState(() {
          _image = Image.memory(bytes, gaplessPlayback: true);
        });
      } catch (e) {
        print('Failed to fetch image from server: $e');
      }
    });
  }

  Future<void> _initCamera() async {
    try {
      _vc = cv.VideoCapture.fromDevice(widget.cameraIndex!);
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
