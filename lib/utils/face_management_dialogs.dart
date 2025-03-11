import 'package:automated_attendance/models/tracked_face.dart';
import 'package:flutter/material.dart';

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
              'Choose which face to keep:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Source face column with keep button
                Expanded(
                  child: Column(
                    children: [
                      // Source face thumbnail
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
                      const SizedBox(height: 12),
                      // Keep this face button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade800,
                          side: BorderSide(color: Colors.blue.shade300),
                        ),
                        onPressed: () => Navigator.pop(context, sourceFace.id),
                        icon: Icon(Icons.check_circle_outline,
                            color: Colors.blue.shade700),
                        label: const Text('KEEP THIS'),
                      ),
                    ],
                  ),
                ),

                // Arrow and similarity score
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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

                // Target face column with keep button
                Expanded(
                  child: Column(
                    children: [
                      // Target face thumbnail
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
                      const SizedBox(height: 12),
                      // Keep this face button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          foregroundColor: Colors.green.shade800,
                          side: BorderSide(color: Colors.green.shade300),
                        ),
                        onPressed: () => Navigator.pop(context, targetFace.id),
                        icon: Icon(Icons.check_circle_outline,
                            color: Colors.green.shade700),
                        label: const Text('KEEP THIS'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                'The selected face will be kept, and the other face will be merged into it.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
                textAlign: TextAlign.center,
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
