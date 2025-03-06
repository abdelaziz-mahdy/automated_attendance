import 'package:flutter/material.dart';
import 'dart:math' as math;

class PeopleAnalytics extends StatefulWidget {
  final List<Map<String, dynamic>> availableFaces;
  final Map<String, dynamic> statistics;
  final Function(String) onFaceSelected;

  const PeopleAnalytics({
    super.key,
    required this.availableFaces,
    required this.statistics,
    required this.onFaceSelected,
  });

  @override
  State<PeopleAnalytics> createState() => _PeopleAnalyticsState();
}

class _PeopleAnalyticsState extends State<PeopleAnalytics> {
  String _searchQuery = '';
  bool _isSearching = false;
  final Set<String> _selectedTags = <String>{};
  String _sortBy = 'visits'; // Default sort by visits

  @override
  Widget build(BuildContext context) {
    final filteredFaces = _getFilteredFaces();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        _buildSearchAndFilters(),
        const SizedBox(height: 16),
        _buildPeopleTable(filteredFaces),
        const SizedBox(height: 16),
        _buildFrequencyDistribution(),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'People Analytics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Export'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Export functionality not implemented')),
                );
              },
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Sort by',
              icon: const Icon(Icons.sort),
              onSelected: (value) {
                setState(() {
                  _sortBy = value;
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'visits',
                  child: Text('Sort by Visits'),
                ),
                const PopupMenuItem(
                  value: 'duration',
                  child: Text('Sort by Duration'),
                ),
                const PopupMenuItem(
                  value: 'name',
                  child: Text('Sort by Name'),
                ),
                const PopupMenuItem(
                  value: 'recent',
                  child: Text('Sort by Recent Activity'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or ID',
                prefixIcon: const Icon(Icons.search),
                border: InputBorder.none,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _isSearching = false;
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _isSearching = value.isNotEmpty;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            _buildFilterChip('Frequent Visitors', 'frequent'),
            _buildFilterChip('New Faces', 'new'),
            _buildFilterChip('Active Now', 'active'),
            _buildFilterChip('Long Duration', 'long'),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String tagValue) {
    final isSelected = _selectedTags.contains(tagValue);

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedTags.add(tagValue);
          } else {
            _selectedTags.remove(tagValue);
          }
        });
      },
    );
  }

  Widget _buildPeopleTable(List<Map<String, dynamic>> faces) {
    if (faces.isEmpty) {
      return _buildEmptyState();
    }

    return SizedBox(
      height: 400,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'People (${faces.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: faces.length,
                itemBuilder: (context, index) {
                  final face = faces[index];
                  return _buildPersonListItem(face);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonListItem(Map<String, dynamic> face) {
    final name = face['name'] ?? 'Unknown';
    final faceId = face['id'] ?? '';
    final visitsCount = _getVisitsForFace(faceId);
    final lastSeen = _getLastSeenForFace(faceId);
    final avgDuration = _getAvgDurationForFace(faceId);
    final isActive = _isPersonActive(faceId);

    return ListTile(
      leading: face['thumbnail'] != null
          ? CircleAvatar(
              backgroundImage: MemoryImage(face['thumbnail']),
            )
          : CircleAvatar(
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
              backgroundColor: Colors.blue.shade200,
            ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ACTIVE',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              _buildMetricChip(
                Icons.visibility,
                '$visitsCount visits',
                Colors.blue,
              ),
              const SizedBox(width: 8),
              if (avgDuration != null)
                _buildMetricChip(
                  Icons.timer,
                  avgDuration,
                  Colors.orange,
                ),
              const SizedBox(width: 8),
              if (lastSeen != null)
                _buildMetricChip(
                  Icons.access_time,
                  lastSeen,
                  Colors.purple,
                ),
            ],
          ),
        ],
      ),
      onTap: () {
        widget.onFaceSelected(faceId);
      },
    );
  }

  Widget _buildMetricChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyDistribution() {
    // Extract frequency distribution data
    final Map<String, int> frequencyMap = _generateFrequencyDistribution();

    if (frequencyMap.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visit Frequency Distribution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: frequencyMap.entries
                    .map((entry) => _buildFrequencyBar(entry.key, entry.value))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: frequencyMap.keys
                  .map((label) => Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyBar(String label, int count) {
    final maxHeight = 80.0;
    final maxCount = widget.availableFaces.length;
    final height = maxCount > 0 ? (count / maxCount) * maxHeight : 0.0;

    // Set a minimum height for visibility if there's at least one
    final barHeight = count > 0 ? math.max(10.0, height) : 0.0;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: _getColorForLabel(label),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForLabel(String label) {
    switch (label) {
      case '1 visit':
        return Colors.blue.shade300;
      case '2-5 visits':
        return Colors.blue.shade500;
      case '6-10 visits':
        return Colors.blue.shade700;
      case '10+ visits':
        return Colors.blue.shade900;
      default:
        return Colors.blue;
    }
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.face,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No people found matching your criteria',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _isSearching = false;
                  _selectedTags.clear();
                });
              },
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredFaces() {
    List<Map<String, dynamic>> filteredFaces = List.from(widget.availableFaces);

    // Apply search query filter
    if (_searchQuery.isNotEmpty) {
      filteredFaces = filteredFaces
          .where((face) => (face['name'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply tag filters
    if (_selectedTags.isNotEmpty) {
      filteredFaces = filteredFaces.where((face) {
        final String id = face['id'] ?? '';

        for (final tag in _selectedTags) {
          switch (tag) {
            case 'frequent':
              if (_getVisitsForFace(id) < 5) return false;
              break;
            case 'new':
              if (_getVisitsForFace(id) > 3) return false;
              break;
            case 'active':
              if (!_isPersonActive(id)) return false;
              break;
            case 'long':
              final duration = _getAvgDurationInMinutes(id);
              if (duration < 15) return false;
              break;
          }
        }

        return true;
      }).toList();
    }

    // Sort filtered faces
    switch (_sortBy) {
      case 'visits':
        filteredFaces.sort((a, b) {
          final visitsA = _getVisitsForFace(a['id'] ?? '');
          final visitsB = _getVisitsForFace(b['id'] ?? '');
          return visitsB.compareTo(visitsA);
        });
        break;
      case 'duration':
        filteredFaces.sort((a, b) {
          final durationA = _getAvgDurationInMinutes(a['id'] ?? '');
          final durationB = _getAvgDurationInMinutes(b['id'] ?? '');
          return durationB.compareTo(durationA);
        });
        break;
      case 'name':
        filteredFaces.sort((a, b) {
          final nameA = (a['name'] ?? '').toString().toLowerCase();
          final nameB = (b['name'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });
        break;
      case 'recent':
        filteredFaces.sort((a, b) {
          final lastSeenA = _getLastSeenDateTime(a['id'] ?? '');
          final lastSeenB = _getLastSeenDateTime(b['id'] ?? '');
          if (lastSeenA == null || lastSeenB == null) {
            return lastSeenA == null ? 1 : -1;
          }
          return lastSeenB.compareTo(lastSeenA);
        });
        break;
    }

    return filteredFaces;
  }

  int _getVisitsForFace(String faceId) {
    final visitsByFace =
        widget.statistics['visitsByFace'] as Map<String, int>? ?? {};
    return visitsByFace[faceId] ?? 0;
  }

  String? _getLastSeenForFace(String faceId) {
    final lastSeenByFace =
        widget.statistics['lastSeenByFace'] as Map<String, DateTime>? ?? {};
    final lastSeen = lastSeenByFace[faceId];

    if (lastSeen == null) return null;

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hrs ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  DateTime? _getLastSeenDateTime(String faceId) {
    final lastSeenByFace =
        widget.statistics['lastSeenByFace'] as Map<String, DateTime>? ?? {};
    return lastSeenByFace[faceId];
  }

  double _getAvgDurationInMinutes(String faceId) {
    final avgDurationByFace =
        widget.statistics['avgDurationByFace'] as Map<String, double>? ?? {};
    final durationSeconds = avgDurationByFace[faceId] ?? 0.0;
    return durationSeconds / 60.0; // Convert to minutes
  }

  String? _getAvgDurationForFace(String faceId) {
    final avgDurationByFace =
        widget.statistics['avgDurationByFace'] as Map<String, double>? ?? {};
    final durationSeconds = avgDurationByFace[faceId];

    if (durationSeconds == null) return null;

    final minutes = (durationSeconds / 60).round();

    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      return '$hours hr${remainingMinutes > 0 ? ' $remainingMinutes min' : ''}';
    }
  }

  bool _isPersonActive(String faceId) {
    final activeVisitsByFace =
        widget.statistics['activeVisitsByFace'] as Map<String, bool>? ?? {};
    return activeVisitsByFace[faceId] ?? false;
  }

  Map<String, int> _generateFrequencyDistribution() {
    final Map<String, int> distribution = {
      '1 visit': 0,
      '2-5 visits': 0,
      '6-10 visits': 0,
      '10+ visits': 0,
    };

    final visitsByFace =
        widget.statistics['visitsByFace'] as Map<String, int>? ?? {};

    visitsByFace.forEach((_, visits) {
      if (visits == 1) {
        distribution['1 visit'] = (distribution['1 visit'] ?? 0) + 1;
      } else if (visits >= 2 && visits <= 5) {
        distribution['2-5 visits'] = (distribution['2-5 visits'] ?? 0) + 1;
      } else if (visits >= 6 && visits <= 10) {
        distribution['6-10 visits'] = (distribution['6-10 visits'] ?? 0) + 1;
      } else {
        distribution['10+ visits'] = (distribution['10+ visits'] ?? 0) + 1;
      }
    });

    return distribution;
  }
}
