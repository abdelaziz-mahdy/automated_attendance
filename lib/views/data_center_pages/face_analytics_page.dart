import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

class FaceAnalyticsPage extends StatefulWidget {
  const FaceAnalyticsPage({super.key});

  @override
  State<FaceAnalyticsPage> createState() => _FaceAnalyticsPageState();
}

class _FaceAnalyticsPageState extends State<FaceAnalyticsPage> {
  String? _selectedProvider;
  String? _selectedFace;
  DateTimeRange? _dateRange;
  bool _onlyNamed = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Default date range: last 7 days
    _dateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraManager>(
      builder: (context, manager, child) {
        final providers = manager.activeProviders.keys.toList();
        final trackedFaces = _filterFaces(manager.trackedFaces);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilters(providers, manager),
            const SizedBox(height: 20),
            _buildAnalyticsSummary(trackedFaces),
            const SizedBox(height: 20),
            Expanded(
              child: _buildDetailedAnalytics(trackedFaces),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilters(List<String> providers, CameraManager manager) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics Filters',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search by name',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(_dateRange != null
                    ? '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}'
                    : 'Select Date Range'),
                onPressed: () async {
                  final result = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _dateRange,
                  );
                  if (result != null) {
                    setState(() {
                      _dateRange = result;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Provider',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedProvider,
                  hint: const Text('All Providers'),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedProvider = newValue;
                    });
                  },
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Providers'),
                    ),
                    ...providers.map((provider) => DropdownMenuItem(
                          value: provider,
                          child: Text(provider),
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Person',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedFace,
                  hint: const Text('All People'),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedFace = newValue;
                    });
                  },
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All People'),
                    ),
                    ...manager.trackedFaces.entries
                        .map((entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value.name),
                            )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Show only named people'),
                  value: _onlyNamed,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setState(() {
                      _onlyNamed = value ?? false;
                    });
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedProvider = null;
                    _selectedFace = null;
                    _onlyNamed = false;
                    _searchQuery = '';
                    _dateRange = DateTimeRange(
                      start: DateTime.now().subtract(const Duration(days: 7)),
                      end: DateTime.now(),
                    );
                  });
                },
                child: const Text('Reset Filters'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSummary(Map<String, TrackedFace> filteredFaces) {
    final uniquePeople = filteredFaces.length;
    final namedPeople =
        filteredFaces.values.where((face) => face.name != face.id).length;

    // Count total appearances
    int totalAppearances = 0;
    for (var face in filteredFaces.values) {
      if (face.firstSeen != null && face.lastSeen != null) {
        totalAppearances++;

        // Add appearances from merged faces
        for (var merged in face.mergedFaces) {
          if (merged.firstSeen != null && merged.lastSeen != null) {
            totalAppearances++;
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            title: 'Unique People',
            value: uniquePeople.toString(),
            icon: Icons.people,
            color: Colors.blue,
          ),
          _buildStatCard(
            title: 'Named People',
            value: namedPeople.toString(),
            icon: Icons.badge,
            color: Colors.green,
          ),
          _buildStatCard(
            title: 'Total Appearances',
            value: totalAppearances.toString(),
            icon: Icons.visibility,
            color: Colors.purple,
          ),
          _buildStatCard(
            title: 'Active Providers',
            value: Provider.of<CameraManager>(context, listen: false)
                .activeProviders
                .length
                .toString(),
            icon: Icons.videocam,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedAnalytics(Map<String, TrackedFace> filteredFaces) {
    if (filteredFaces.isEmpty) {
      return const Center(
        child: Text('No data matches your filter criteria'),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daily visits chart
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Appearances',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildDailyVisitsChart(filteredFaces),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Detailed list of appearances
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detailed Appearances',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildDetailedList(filteredFaces),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyVisitsChart(Map<String, TrackedFace> filteredFaces) {
    // Create a map of date to number of appearances
    final Map<DateTime, int> dailyAppearances = {};

    // Ensure all days in the range are included
    if (_dateRange != null) {
      DateTime current = _dateRange!.start;
      while (current.isBefore(_dateRange!.end) ||
          current.isAtSameMomentAs(_dateRange!.end)) {
        dailyAppearances[DateTime(current.year, current.month, current.day)] =
            0;
        current = current.add(const Duration(days: 1));
      }
    }

    // Count appearances for each day
    for (var face in filteredFaces.values) {
      if (face.firstSeen != null) {
        final date = DateTime(
          face.firstSeen!.year,
          face.firstSeen!.month,
          face.firstSeen!.day,
        );
        dailyAppearances[date] = (dailyAppearances[date] ?? 0) + 1;
      }

      // Count merged faces appearances
      for (var merged in face.mergedFaces) {
        if (merged.firstSeen != null) {
          final date = DateTime(
            merged.firstSeen!.year,
            merged.firstSeen!.month,
            merged.firstSeen!.day,
          );
          dailyAppearances[date] = (dailyAppearances[date] ?? 0) + 1;
        }
      }
    }

    // Sort dates
    final sortedDates = dailyAppearances.keys.toList()..sort();

    // Create bar chart data
    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: dailyAppearances[date]!.toDouble(),
              color: Theme.of(context).primaryColor,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: dailyAppearances.values.isEmpty
            ? 5
            : dailyAppearances.values.reduce((a, b) => a > b ? a : b) * 1.2,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value >= 0 && value < sortedDates.length) {
                  final date = sortedDates[value.toInt()];
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      DateFormat('MM/dd').format(date),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == value.roundToDouble()) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 30,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xffDADADA), width: 1),
        ),
        gridData: const FlGridData(show: true),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildDetailedList(Map<String, TrackedFace> filteredFaces) {
    // Create a list of all appearances (including merged ones)
    final List<Map<String, dynamic>> appearances = [];

    for (var face in filteredFaces.values) {
      if (face.firstSeen != null) {
        appearances.add({
          'name': face.name,
          'id': face.id,
          'firstSeen': face.firstSeen,
          'lastSeen': face.lastSeen,
          'provider': face.lastSeenProvider,
          'thumbnail': face.thumbnail,
        });
      }

      // Add merged faces appearances
      for (var merged in face.mergedFaces) {
        if (merged.firstSeen != null) {
          appearances.add({
            'name': face.name, // Use parent's name
            'id': merged.id,
            'firstSeen': merged.firstSeen,
            'lastSeen': merged.lastSeen,
            'provider': merged.lastSeenProvider,
            'thumbnail': merged.thumbnail,
            'merged': true,
            'parentId': face.id,
          });
        }
      }
    }

    // Sort appearances by date (most recent first)
    appearances.sort((a, b) {
      final DateTime aTime = a['lastSeen'] ?? DateTime(1970);
      final DateTime bTime = b['lastSeen'] ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    return ListView.builder(
      itemCount: appearances.length,
      itemBuilder: (context, index) {
        final appearance = appearances[index];
        final DateTime? firstSeen = appearance['firstSeen'];
        final DateTime? lastSeen = appearance['lastSeen'];
        final duration = lastSeen != null && firstSeen != null
            ? lastSeen.difference(firstSeen)
            : null;

        return ListTile(
          leading: appearance['thumbnail'] != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(
                    appearance['thumbnail'],
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                )
              : const CircleAvatar(
                  radius: 20,
                  child: Icon(Icons.face),
                ),
          title: Row(
            children: [
              Text(appearance['name']),
              if (appearance['merged'] == true)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Tooltip(
                    message: 'Merged with another face',
                    child: Icon(
                      Icons.merge_type,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('First seen: ${_formatDateTime(firstSeen)}'),
              Text('Last seen: ${_formatDateTime(lastSeen)}'),
              if (duration != null)
                Text('Duration: ${_formatDuration(duration)}'),
            ],
          ),
          trailing: Text(
            appearance['provider'] ?? 'Unknown',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          isThreeLine: true,
          dense: true,
        );
      },
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('MMM d, yyyy HH:mm:ss').format(dateTime);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    final List<String> parts = [];
    if (hours > 0) parts.add('$hours hours');
    if (minutes > 0) parts.add('$minutes min');
    if (seconds > 0 && hours == 0) parts.add('$seconds sec');

    return parts.join(' ');
  }

  Map<String, TrackedFace> _filterFaces(Map<String, TrackedFace> allFaces) {
    final Map<String, TrackedFace> filtered = {};

    for (var entry in allFaces.entries) {
      final face = entry.value;
      bool includeThisFace = true;

      // Filter by name search
      if (_searchQuery.isNotEmpty) {
        if (!face.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
          includeThisFace = false;
        }
      }

      // Filter by only named (non-ID names)
      if (_onlyNamed && face.name == face.id) {
        includeThisFace = false;
      }

      // Filter by selected face
      if (_selectedFace != null && face.id != _selectedFace) {
        includeThisFace = false;
      }

      // Filter by provider
      if (_selectedProvider != null &&
          face.lastSeenProvider != _selectedProvider) {
        includeThisFace = false;
      }

      // Filter by date range
      if (_dateRange != null && face.lastSeen != null) {
        final lastSeenDate = DateTime(
          face.lastSeen!.year,
          face.lastSeen!.month,
          face.lastSeen!.day,
        );
        final startDate = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final endDate = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
        ).add(const Duration(days: 1)); // Include entire end day

        if (lastSeenDate.isBefore(startDate) || lastSeenDate.isAfter(endDate)) {
          includeThisFace = false;
        }
      }

      if (includeThisFace) {
        filtered[entry.key] = face;
      }
    }

    return filtered;
  }
}
