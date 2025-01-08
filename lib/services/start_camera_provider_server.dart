// lib/services/camera_provider_server.dart
import 'dart:io';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:automated_attendance/discovery/broadcast_service.dart';
import 'package:automated_attendance/logs/request_logs.dart';

final BroadcastService _broadcastService = BroadcastService();

Future<void> startCameraProviderServer() async {
  try {
    // 1. Register (broadcast) the service on the network
    await _broadcastService.startBroadcast(
      serviceName: "MyCameraProvider",
      serviceType: "_camera._tcp",
      port: 12345,
    );
    RequestLogs.add("BroadcastService started on port 12345");

    // 2. Start the HTTP server
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 12345);
    RequestLogs.add(
        "HTTP server running at http://${server.address.address}:${server.port}");

    server.listen((HttpRequest request) async {
      final start = DateTime.now();
      if (request.uri.path == '/get_image') {
        // Local camera capture
        final vc = cv.VideoCapture.fromDevice(0);
        final (success, frame) = vc.read();
        vc.release();

        if (success) {
          final (_, image) = cv.imencode('.jpg', frame);
          request.response.headers.contentType = ContentType('image', 'jpeg');
          request.response.add(image);
          await request.response.close();

          final elapsed = DateTime.now().difference(start).inMilliseconds;
          RequestLogs.add("Handled /get_image in $elapsed ms (Success)");
        } else {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();

          final elapsed = DateTime.now().difference(start).inMilliseconds;
          RequestLogs.add(
              "Handled /get_image in $elapsed ms (Error capturing frame)");
        }
      } else {
        // Not found or other endpoints
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        RequestLogs.add("404 for path: ${request.uri.path}");
      }
    });
  } catch (e, st) {
    RequestLogs.add("Error starting camera provider server: $e\n$st");
    rethrow;
  }
}
