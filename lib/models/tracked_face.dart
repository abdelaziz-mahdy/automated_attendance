// camera_manager.dart

import 'package:flutter/foundation.dart';

class TrackedFace {
  final String id;
  final List<double> features;
  String name; // Name is now mutable
  DateTime? firstSeen;
  DateTime? lastSeen;
  String? lastSeenProvider;
  Uint8List? thumbnail;
  List<TrackedFace> mergedFaces = [];

  TrackedFace({
    required this.id,
    required this.features,
    required this.name,
    this.firstSeen,
    this.lastSeen,
    this.lastSeenProvider,
    this.thumbnail,
  });

  void setName(String newName) {
    name = newName;
  }

  List<Uint8List> get allThumbnails {
    final thumbnails = <Uint8List>[];
    if (thumbnail != null) thumbnails.add(thumbnail!);
    for (var face in mergedFaces) {
      if (face.thumbnail != null) thumbnails.add(face.thumbnail!);
    }
    return thumbnails;
  }
}
