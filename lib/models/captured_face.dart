import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class CapturedFace {
  final Uint8List thumbnail;
  String? name; // Not final so we can update it when recognition occurs
  final DateTime timestamp;
  final String providerAddress;
  final String? faceId; // Track the ID for face management

  CapturedFace({
    required this.thumbnail,
    this.name,
    required this.timestamp,
    required this.providerAddress,
    this.faceId,
  });
}
