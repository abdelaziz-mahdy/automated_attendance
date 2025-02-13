import 'dart:typed_data';

import 'package:automated_attendance/isolate/frame_processor_async.dart';
import 'package:automated_attendance/isolate/frame_processor_manager.dart';

// Define an interface for frame processing.
abstract class IFrameProcessor {
  Future<Map<String, dynamic>?> processFrame(Uint8List frame);
}

// Isolate-based implementation.
class IsolateFrameProcessor implements IFrameProcessor {
  @override
  Future<Map<String, dynamic>?> processFrame(Uint8List frame) async {
    return await FrameProcessorManagerIsolate().processFrame(frame);
  }
}

// Main isolate implementation.
class MainIsolateFrameProcessor implements IFrameProcessor {
  @override
  Future<Map<String, dynamic>?> processFrame(Uint8List frame) async {
    return await processFrameAsync(frame);
  }
}
