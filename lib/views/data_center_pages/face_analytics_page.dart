import 'package:automated_attendance/services/camera_manager.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class FaceAnalyticsPage extends StatefulWidget {
  const FaceAnalyticsPage({super.key});

  @override
  State<FaceAnalyticsPage> createState() => _FaceAnalyticsPageState();
}

class _FaceAnalyticsPageState extends State<FaceAnalyticsPage> {
  bool _isLoading = true;
  Map<String, dynamic> _statistics = {};
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  String? _selectedProviderId;
  bool _ignoreTouch = false;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    final manager = Provider.of<CameraManager>(context, listen: false);
    final stats = await manager.getVisitStatistics(
      startDate: _dateRange.start,
      endDate: _dateRange.end,
      providerId: _selectedProviderId,
    );

    setState(() {
      _statistics = stats;
      _isLoading = false;
    });
  }

  Future<void> _selectDateRange() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _dateRange = pickedRange;
      });
      await _loadStatistics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateRangeSelector(),
                  const SizedBox(height: 16),
                  _buildProviderSelector(),
                  const SizedBox(height: 24),
                  _buildStatCards(),
                  const SizedBox(height: 24),
                  _buildDailyVisitsChart(),
                  const SizedBox(height: 24),
                  _buildHourlyDistributionChart(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      title: const Text('Face Analytics'),
      floating: true,
      snap: true,
      expandedHeight: 60,
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: 1,
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadStatistics,
          tooltip: 'Refresh data',
        ),
      ],
    );
  }

  Widget _buildDateRangeSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: _selectDateRange,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.calendar_today),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date Range',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${DateFormat('MMM dd, yyyy').format(_dateRange.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange.end)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderSelector() {
    final providers = _statistics['providers'] as Set<String>? ?? <String>{};
    final providersList = ['All Providers', ...providers];

    return Row(
      children: [
        const Text(
          'Provider: ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<String?>(
            value: _selectedProviderId,
            isExpanded: true,
            hint: const Text('All Providers'),
            onChanged: (value) {
              setState(() {
                _selectedProviderId = value == 'All Providers' ? null : value;
              });
              _loadStatistics();
            },
            items: providersList
                .map((provider) => DropdownMenuItem<String?>(
                      value: provider == 'All Providers' ? null : provider,
                      child: Text(provider),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards() {
    final totalVisits = _statistics['totalVisits'] ?? 0;
    final activeVisits = _statistics['activeVisits'] ?? 0;
    final completedVisits = _statistics['completedVisits'] ?? 0;
    final uniqueFacesCount = _statistics['uniqueFacesCount'] ?? 0;
    final avgDurationSeconds = _statistics['avgDurationSeconds'] ?? 0.0;
    final avgDuration = Duration(seconds: avgDurationSeconds.toInt());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
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
              title: 'Total Visits',
              value: '$totalVisits',
              icon: Icons.remove_red_eye,
              color: Colors.blue,
            ),
            _buildStatCard(
              title: 'Unique Faces',
              value: '$uniqueFacesCount',
              icon: Icons.face,
              color: Colors.purple,
            ),
            _buildStatCard(
              title: 'Active Visits',
              value: '$activeVisits',
              icon: Icons.visibility,
              color: Colors.green,
            ),
            _buildStatCard(
              title: 'Avg. Duration',
              value: _formatDuration(avgDuration),
              icon: Icons.timer,
              color: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
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
          ],
        ),
      ),
    );
  }

  Widget _buildDailyVisitsChart() {
    final visitsByDay = _statistics['visitsByDay'] as Map<String, int>? ?? {};

    if (visitsByDay.isEmpty) {
      return const SizedBox();
    }

    // Sort dates
    final sortedDates = visitsByDay.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    final spots = <FlSpot>[];

    // Create spots for the chart
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final visits = visitsByDay[date] ?? 0;
      spots.add(FlSpot(i.toDouble(), visits.toDouble()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Visits',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              height: 250,
              child: spots.isEmpty
                  ? const Center(child: Text('No data available'))
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) {
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < sortedDates.length) {
                                  final date = sortedDates[index];
                                  final parts = date.split('-');
                                  if (parts.length >= 3) {
                                    return SideTitleWidget(
                                      meta: meta,
                                      child: Text(
                                        '${parts[1]}/${parts[2]}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  }
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        minX: -0.5,
                        maxX: sortedDates.length - 0.5,
                        minY: 0,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            barWidth: 3,
                            color: Colors.blue,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.withOpacity(0.2),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          enabled: !_ignoreTouch,
                          touchTooltipData: LineTouchTooltipData(
                            // tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((touchedSpot) {
                                final date = sortedDates[touchedSpot.x.toInt()];
                                return LineTooltipItem(
                                  '${touchedSpot.y.toInt()} visits\n$date',
                                  const TextStyle(color: Colors.white),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyDistributionChart() {
    final visitsByHour = _statistics['visitsByHour'] as Map<int, int>? ?? {};

    if (visitsByHour.isEmpty) {
      return const SizedBox();
    }

    final spots = <BarChartGroupData>[];

    // Create bar groups for each hour from 0-23
    for (int hour = 0; hour < 24; hour++) {
      final visits = visitsByHour[hour] ?? 0;
      spots.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: visits.toDouble(),
              color: Colors.blue,
              width: 12,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visits by Hour of Day',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: true),
                  alignment: BarChartAlignment.spaceAround,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final hour = value.toInt();
                          if (hour % 3 == 0) {
                            final amPm = hour < 12 ? 'AM' : 'PM';
                            final displayHour = hour % 12 == 0 ? 12 : hour % 12;
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                '$displayHour$amPm',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  barGroups: spots,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      // tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final hour = group.x;
                        final amPm = hour < 12 ? 'AM' : 'PM';
                        final displayHour = hour % 12 == 0 ? 12 : hour % 12;
                        return BarTooltipItem(
                          '$displayHour:00 $amPm\n${rod.toY.toInt()} visits',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
