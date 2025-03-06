import 'package:flutter/material.dart';

class AnalyticsSummary extends StatelessWidget {
  final Map<String, dynamic> statistics;
  final VoidCallback onExport;

  const AnalyticsSummary({
    super.key,
    required this.statistics,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final totalVisits = statistics['totalVisits'] ?? 0;
    final activeVisits = statistics['activeVisits'] ?? 0;
    final completedVisits = statistics['completedVisits'] ?? 0;
    final uniqueFacesCount = statistics['uniqueFacesCount'] ?? 0;
    final avgDurationSeconds = statistics['avgDurationSeconds'] ?? 0.0;
    final avgDuration = Duration(seconds: avgDurationSeconds.toInt());
    final peakHour = statistics['peakHour'] ?? '';
    final maxFrequencyProviders = statistics['maxFrequencyProviders'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildStatCard(
              context: context,
              title: 'Total Visits',
              value: '$totalVisits',
              icon: Icons.remove_red_eye,
              color: Colors.blue,
            ),
            _buildStatCard(
              context: context,
              title: 'Unique Faces',
              value: '$uniqueFacesCount',
              icon: Icons.face,
              color: Colors.purple,
              subtitle: 'Detected people',
            ),
            _buildStatCard(
              context: context,
              title: 'Active Visits',
              value: '$activeVisits',
              icon: Icons.visibility,
              color: Colors.green,
              subtitle: 'Currently present',
            ),
            _buildStatCard(
              context: context,
              title: 'Avg. Duration',
              value: _formatDuration(avgDuration),
              icon: Icons.timer,
              color: Colors.orange,
              subtitle: 'Stay time',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildAdditionalMetrics(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Analytics Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          onPressed: onExport,
          icon: const Icon(Icons.download),
          label: const Text('Export'),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalMetrics(BuildContext context) {
    final providers = statistics['providers'] as Set<String>? ?? <String>{};
    final peakHour = _findPeakHour();
    final completionRate = _calculateCompletionRate();

    if (peakHour == null && providers.isEmpty && completionRate == null) {
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
              'Advanced Metrics',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            if (peakHour != null)
              _buildInfoRow(
                Icons.access_time,
                'Peak Hours',
                peakHour,
                Colors.indigo,
              ),
            if (completionRate != null)
              _buildInfoRow(
                Icons.check_circle_outline,
                'Visit Completion Rate',
                '$completionRate%',
                Colors.teal,
              ),
            Row(
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: Colors.brown,
                ),
                const SizedBox(width: 8),
                Text(
                  'Active Providers:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.brown,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${providers.length}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }

  String? _findPeakHour() {
    final visitsByHour = statistics['visitsByHour'] as Map<int, int>? ?? {};
    if (visitsByHour.isEmpty) return null;

    int? peakHour;
    int maxVisits = 0;

    visitsByHour.forEach((hour, visits) {
      if (visits > maxVisits) {
        maxVisits = visits;
        peakHour = hour;
      }
    });

    if (peakHour == null) return null;

    final hourFormatted = peakHour! < 12
        ? '${peakHour!} AM'
        : '${peakHour! == 12 ? 12 : peakHour! - 12} PM';

    return '$hourFormatted ($maxVisits visits)';
  }

  int? _calculateCompletionRate() {
    final totalVisits = statistics['totalVisits'] ?? 0;
    final completedVisits = statistics['completedVisits'] ?? 0;

    if (totalVisits == 0) return null;
    return ((completedVisits / totalVisits) * 100).round();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}';
    } else {
      return '$minutes min';
    }
  }
}
