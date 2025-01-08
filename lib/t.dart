import 'package:flutter/material.dart';
import 'dart:io';
import 'package:opencv_dart/opencv_dart.dart' as cv;

void startCameraProviderServer() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 12345);
  print('Server running on ${server.address.address}:${server.port}');

  server.listen((HttpRequest request) async {
    if (request.uri.path == '/get_image') {
      final vc = cv.VideoCapture.fromDevice(0);
      final (success, frame) = vc.read();
      vc.release();

      if (success) {
        final (_, image) = cv.imencode('.jpg', frame);
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add(image);
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      }
    }
  });
}
