// lib/services/camera_provider_server.dart
import 'dart:io';
import 'package:automated_attendance/camera_providers/i_camera_provider.dart';
import 'package:automated_attendance/camera_providers/local_camera_provider.dart';
import 'package:automated_attendance/discovery/broadcast_service.dart';
import 'package:automated_attendance/logs/request_logs.dart';

final BroadcastService _broadcastService = BroadcastService();

class CameraProviderServer {
  static final CameraProviderServer _instance =
      CameraProviderServer._internal();
  HttpServer? _server;
  ICameraProvider? localCameraProvider;
  factory CameraProviderServer() {
    return _instance;
  }

  CameraProviderServer._internal();

  Future<void> start() async {
    if (_server != null) {
      RequestLogs.add("Server is already running");
      return;
    }

    try {
      // // 1. Register (broadcast) the service on the network
      await _broadcastService.startBroadcast(
        serviceName: "MyCameraProvider",
        serviceType: "_camera._tcp",
        port: 12345,
      );
      // RequestLogs.add("BroadcastService started on port 12345");

      // Start the HTTP server
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 12345);
      RequestLogs.add(
          "HTTP server running at http://${_server!.address.address}:${_server!.port}");
      // LocalCameraProvider localCameraProvider =
      //     LocalCameraProvider(LocalCameraPicker.highestCameraIndex);
      // if (Platform.isAndroid) {
      //   localCameraProvider = AndroidCameraProvider(0);
      // } else {
      //   localCameraProvider = LocalCameraProvider(0);
      // }
      localCameraProvider = LocalCameraProvider(0);

      bool success = await localCameraProvider!.openCamera();

      _server!.listen((HttpRequest request) async {
        final start = DateTime.now();
        RequestLogs.add("Received request for path: ${request.uri.path}");
        if (request.uri.path == '/test') {
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          RequestLogs.add("Handled /test");
          return;
        }
        if (request.uri.path == '/get_image') {
          if (success) {
            final image = await localCameraProvider?.getFrame();
            if (image == null) {
              request.response.statusCode = HttpStatus.internalServerError;
              await request.response.close();

              final elapsed = DateTime.now().difference(start).inMilliseconds;
              RequestLogs.add(
                  "Handled /get_image in $elapsed ms (Error capturing frame)");
              return;
            }
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

  Future<void> stop() async {
    if (_server == null) {
      RequestLogs.add("Server is not running");
      return;
    }

    await _server!.close(force: true);
    _server = null;
    await _broadcastService.stopBroadcast();
    await localCameraProvider?.closeCamera();
    RequestLogs.add("Server stopped");
    RequestLogs.logsNotifier.clear();
  }
}

final CameraProviderServer cameraProviderServer = CameraProviderServer();
