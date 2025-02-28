import 'package:automated_attendance/models/tracked_face.dart';
import 'package:flutter/material.dart';
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:provider/provider.dart';

class FaceManagementDialogs {
  /// Shows a confirmation dialog for deleting a face
  static Future<bool> showDeleteConfirmation(
    BuildContext context,
    TrackedFace face,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Face'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Face thumbnail
            Container(
              width: 100,
              height: 100,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: face.allThumbnails.isNotEmpty
                    ? Image.memory(
                        face.allThumbnails.first,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.grey.shade500,
                        ),
                      ),
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Are you sure you want to delete ',
                  ),
                  TextSpan(
                    text: face.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(
                    text: '? This action cannot be undone.',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Shows a confirmation dialog for merging two faces
  static Future<String?> showMergeConfirmation(
    BuildContext context,
    TrackedFace sourceFace,
    TrackedFace targetFace, {
    double? similarityScore,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge Faces'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose merge direction:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Source face thumbnail
                Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.shade300,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: sourceFace.allThumbnails.isNotEmpty
                            ? Image.memory(
                                sourceFace.allThumbnails.first,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey.shade200,
                                child: Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sourceFace.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                // Arrow
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.compare_arrows,
                        color: Colors.blue.shade700,
                        size: 32,
                      ),
                      if (similarityScore != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getSimilarityColor(similarityScore)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getSimilarityColor(similarityScore)
                                  .withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            "${similarityScore.toStringAsFixed(1)}%",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getSimilarityColor(similarityScore),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Target face thumbnail
                Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.shade300,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: targetFace.allThumbnails.isNotEmpty
                            ? Image.memory(
                                targetFace.allThumbnails.first,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey.shade200,
                                child: Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      targetFace.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Select direction:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            // Option 1: Source → Target (keep target)
            InkWell(
              onTap: () => Navigator.pop(context, targetFace.id),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                  color: Colors.green.shade50,
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_forward, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "KEEP \"${targetFace.name}\"",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                          Text(
                            "Move all data from \"${sourceFace.name}\" to \"${targetFace.name}\", then delete \"${sourceFace.name}\"",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Option 2: Target → Source (keep source)
            InkWell(
              onTap: () => Navigator.pop(context, sourceFace.id),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                  color: Colors.blue.shade50,
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "KEEP \"${sourceFace.name}\"",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          Text(
                            "Move all data from \"${targetFace.name}\" to \"${sourceFace.name}\", then delete \"${targetFace.name}\"",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  static Color _getSimilarityColor(double score) {
    if (score >= 90) return Colors.green.shade700; // Very high similarity
    if (score >= 80) return Colors.lightGreen.shade700; // High similarity
    if (score >= 70) return Colors.amber.shade700; // Moderate similarity
    if (score >= 60) return Colors.orange.shade700; // Low similarity
    return Colors.red.shade700; // Very low similarity
  }
}
