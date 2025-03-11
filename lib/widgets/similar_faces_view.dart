import 'package:automated_attendance/controllers/ui_state_controller.dart';
import 'package:automated_attendance/models/face_match.dart';
import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/utils/face_management_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SimilarFacesView extends StatefulWidget {
  final String faceId;
  final VoidCallback? onMergeComplete;

  const SimilarFacesView({
    super.key,
    required this.faceId,
    this.onMergeComplete,
  });

  @override
  State<SimilarFacesView> createState() => _SimilarFacesViewState();
}

class _SimilarFacesViewState extends State<SimilarFacesView> {
  List<FaceMatch> _similarFaces = [];
  bool _isLoading = true;
  final int _matchLimit = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSimilarFaces());
  }

  void _loadSimilarFaces() async {
    setState(() {
      _isLoading = true;
    });

    final cameraManager =
        Provider.of<UIStateController>(context, listen: false);
    _similarFaces =
        await cameraManager.findSimilarFaces(widget.faceId, limit: _matchLimit);
    debugPrint('Found ${_similarFaces.length} similar faces');
    setState(() {
      _isLoading = false;
    });
  }

  void _mergeFaces(String targetId, String sourceId) {
    final cameraManager =
        Provider.of<UIStateController>(context, listen: false);
    cameraManager.mergeFaces(targetId, sourceId);

    if (widget.onMergeComplete != null) {
      widget.onMergeComplete!();
    }
  }

  String _formatSimilarityPercentage(double score) {
    return "${score.toStringAsFixed(1)}%";
  }

  @override
  Widget build(BuildContext context) {
    final trackedFace =
        Provider.of<UIStateController>(context).trackedFaces[widget.faceId];

    if (trackedFace == null) {
      return const Center(child: Text('Face not found'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(trackedFace),
        const Divider(),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_similarFaces.isEmpty)
          _buildEmptyState()
        else
          Expanded(child: _buildSimilarFacesList()),
      ],
    );
  }

  Widget _buildHeader(TrackedFace face) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Current face thumbnail
          Hero(
            tag: 'face_${face.id}',
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.shade300,
                  width: 2,
                ),
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
                          size: 30,
                          color: Colors.grey.shade500,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Similar Face Matches',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  face.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Showing potential matches with similarity scores',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadSimilarFaces,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh matches',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No similar faces found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no faces that match the similarity threshold.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimilarFacesList() {
    return ListView.builder(
      itemCount: _similarFaces.length,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final match = _similarFaces[index];
        final similarityColor = _getSimilarityColor(match.similarityScore);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: similarityColor.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showMergeConfirmation(match),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Face thumbnail
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: match.face.allThumbnails.isNotEmpty
                          ? Image.memory(
                              match.face.allThumbnails.first,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.grey.shade500,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Face details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.face.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Similarity score with visual indicator
                        Row(
                          children: [
                            Text(
                              'Match: ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: similarityColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: similarityColor.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _formatSimilarityPercentage(
                                    match.similarityScore),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: similarityColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Merge button with clearer label
                            OutlinedButton.icon(
                              icon: const Icon(Icons.merge_type, size: 16),
                              label: const Text('Choose Merge Direction'),
                              onPressed: () => _showMergeConfirmation(match),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Similarity percentage in circle
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: similarityColor.withOpacity(0.1),
                      border: Border.all(
                        color: similarityColor.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _formatSimilarityPercentage(match.similarityScore),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: similarityColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getSimilarityColor(double score) {
    if (score >= 90) return Colors.green.shade700; // Very high similarity
    if (score >= 80) return Colors.lightGreen.shade700; // High similarity
    if (score >= 70) return Colors.amber.shade700; // Moderate similarity
    if (score >= 60) return Colors.orange.shade700; // Low similarity
    return Colors.red.shade700; // Very low similarity
  }

  void _showMergeConfirmation(FaceMatch match) async {
    final cameraManager =
        Provider.of<UIStateController>(context, listen: false);
    final currentFace = cameraManager.trackedFaces[widget.faceId]!;
    final matchFace = match.face;

    final keepFaceId = await FaceManagementDialogs.showMergeConfirmation(
      context,
      currentFace,
      matchFace,
      similarityScore: match.similarityScore,
    );

    if (keepFaceId != null) {
      final sourceId =
          keepFaceId == currentFace.id ? matchFace.id : currentFace.id;

      _mergeFaces(keepFaceId, sourceId);
    }
  }
}
