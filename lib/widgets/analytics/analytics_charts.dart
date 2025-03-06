import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsCharts extends StatefulWidget {
  final Map<String, dynamic> statistics;
  final bool showAdvancedCharts;
  final String? comparisonPeriodData;

  const AnalyticsCharts({
    super.key,
    required this.statistics,
    this.showAdvancedCharts = false,
    this.comparisonPeriodData,
  });

  @override
  State<AnalyticsCharts> createState() => _AnalyticsChartsState();
}

class _AnalyticsChartsState extends State<AnalyticsCharts>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final bool _ignoreTouch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 8),
        _buildTabBar(),
        const SizedBox(height: 16),
        SizedBox(
          height: 350,
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildDailyVisitsChart(),
              _buildHourlyDistributionChart(),
              _buildFaceTrafficChart(),
            ],
          ),
        ),
        if (widget.showAdvancedCharts) ...[
          const SizedBox(height: 24),
          _buildComparisonCharts(),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Visit Patterns',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        IconButton(
          tooltip: 'Chart Options',
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            _showChartOptionsMenu();
          },
        ),
      ],
    );
  }

  void _showChartOptionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Export Chart as PNG'),
                onTap: () {
                  Navigator.pop(context);
                  // Export chart functionality would be implemented here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Chart export is not implemented yet')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.compare_arrows),
                title: const Text('Compare with Previous Period'),
                onTap: () {
                  Navigator.pop(context);
                  // Comparison functionality would be implemented here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Comparison is not implemented yet')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Chart Settings'),
                onTap: () {
                  Navigator.pop(context);
                  // Chart settings would be implemented here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Chart settings is not implemented yet')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.3),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Theme.of(context).colorScheme.primary,
        ),
        labelColor: Theme.of(context).colorScheme.onPrimary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        tabs: const [
          Tab(text: 'Daily'),
          Tab(text: 'Hourly'),
          Tab(text: 'Face Traffic'),
        ],
      ),
    );
  }

  Widget _buildDailyVisitsChart() {
    final visitsByDay =
        widget.statistics['visitsByDay'] as Map<String, int>? ?? {};

    if (visitsByDay.isEmpty) {
      return _buildEmptyChartState('No daily visit data available');
    }

    // Sort dates
    final sortedDates = visitsByDay.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    final spots = <FlSpot>[];
    final renderedDates = {};
    // /// if there is only one date, improve it by adding dates before and after
    // if (sortedDates.length == 1) {
    //   final date = DateTime.parse(sortedDates[0]);
    //   final previousDate = date.subtract(const Duration(days: 1));
    //   final nextDate = date.add(const Duration(days: 1));
    //   sortedDates.insert(0, previousDate.toIso8601String());
    //   sortedDates.add(nextDate.toIso8601String());
    // }
    // Create spots for the chart
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final dateTime = DateTime.parse(date);
      final visits = visitsByDay[date] ?? 0;
      print("date: $date, visits: $visits");
      spots.add(FlSpot(
          dateTime.microsecondsSinceEpoch.toDouble(), visits.toDouble()));
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: spots.isEmpty
            ? _buildEmptyChartState('No data available')
            : LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
                  ),
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
                        maxIncluded: false,
                        minIncluded: false,
                        getTitlesWidget: (value, meta) {
                          final date = DateTime.fromMicrosecondsSinceEpoch(
                              value.toInt());
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              '${date.month}/${date.day}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );

                          // return const SizedBox();
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
                  // minX: -0.5,
                  // maxX: sortedDates.length - 0.5,
                  minY: 0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: Theme.of(context).colorScheme.primary,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Theme.of(context).colorScheme.primary,
                            strokeWidth: 1,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.2),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: !_ignoreTouch,
                    touchTooltipData: LineTouchTooltipData(
                      // tooltipBgColor:
                      //     Theme.of(context).colorScheme.primaryContainer,
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((touchedSpot) {
                          final date = sortedDates[touchedSpot.x.toInt()];
                          return LineTooltipItem(
                            '${touchedSpot.y.toInt()} visits\n$date',
                            TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHourlyDistributionChart() {
    final visitsByHour =
        widget.statistics['visitsByHour'] as Map<int, int>? ?? {};

    if (visitsByHour.isEmpty) {
      return _buildEmptyChartState('No hourly distribution data available');
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
              color: _getHourColor(hour, context),
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawHorizontalLine: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.shade300,
                  strokeWidth: 1,
                );
              },
            ),
            alignment: BarChartAlignment.spaceAround,
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  getTitlesWidget: (value, meta) {
                    if (value % 1 == 0) {
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }
                    return const SizedBox();
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
                // tooltipBgColor: Theme.of(context).colorScheme.primaryContainer,
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final hour = group.x;
                  final amPm = hour < 12 ? 'AM' : 'PM';
                  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
                  return BarTooltipItem(
                    '$displayHour:00 $amPm\n${rod.toY.toInt()} visits',
                    TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getHourColor(int hour, BuildContext context) {
    // Morning (6-11): Blue
    if (hour >= 6 && hour < 12) {
      return Colors.blue;
    }
    // Afternoon (12-17): Green
    else if (hour >= 12 && hour < 18) {
      return Colors.green;
    }
    // Evening (18-22): Purple
    else if (hour >= 18 && hour < 23) {
      return Colors.purple;
    }
    // Night (23-5): Indigo
    else {
      return Colors.indigo;
    }
  }

  Widget _buildFaceTrafficChart() {
    // This chart shows number of unique faces detected throughout the day
    final faceTrafficData = _extractFaceTrafficData();

    if (faceTrafficData.isEmpty) {
      return _buildEmptyChartState('No face traffic data available');
    }

    // Create line spots from the data
    final List<FlSpot> spots = [];
    for (int i = 0; i < faceTrafficData.length; i++) {
      spots.add(FlSpot(i.toDouble(), faceTrafficData[i].toDouble()));
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: spots.isEmpty
            ? _buildEmptyChartState('No face traffic data available')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
                    child: Text(
                      'Unique faces detected by time of day',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade300,
                              strokeWidth: 1,
                            );
                          },
                        ),
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

                                /// Show only every 2nd hour
                                if (index % 2 == 0 && index < 24) {
                                  final amPm = index < 12 ? 'AM' : 'PM';
                                  final hour =
                                      index % 12 == 0 ? 12 : index % 12;
                                  return SideTitleWidget(
                                    meta: meta,
                                    child: Text(
                                      '$hour$amPm',
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
                        minX: 0,
                        maxX: 23,
                        minY: 0,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            barWidth: 3,
                            color: Colors.orange,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.orange,
                                  strokeWidth: 1,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.orange.withOpacity(0.2),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          enabled: !_ignoreTouch,
                          touchTooltipData: LineTouchTooltipData(
                            // tooltipBgColor:
                            //     Theme.of(context).colorScheme.primaryContainer,
                            tooltipRoundedRadius: 8,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((touchedSpot) {
                                final hour = touchedSpot.x.toInt();
                                final amPm = hour < 12 ? 'AM' : 'PM';
                                final displayHour =
                                    hour % 12 == 0 ? 12 : hour % 12;
                                return LineTooltipItem(
                                  '$displayHour:00 $amPm\n${touchedSpot.y.toInt()} unique faces',
                                  TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<int> _extractFaceTrafficData() {
    final uniqueFacesByHour =
        widget.statistics['uniqueFacesByHour'] as Map<int, int>? ?? {};
    final List<int> result = List.filled(24, 0);

    for (int i = 0; i < 24; i++) {
      result[i] = uniqueFacesByHour[i] ?? 0;
    }

    return result;
  }

  Widget _buildComparisonCharts() {
    // Mock comparison data if real data isn't provided
    final Map<String, dynamic> currentData = widget.statistics;
    final Map<String, dynamic> previousData =
        widget.comparisonPeriodData != null
            ? {'totalVisits': (currentData['totalVisits'] ?? 0) * 0.8}
            : {};

    if (previousData.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentTotal = currentData['totalVisits'] ?? 0;
    final previousTotal = previousData['totalVisits'] ?? 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Comparison',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildComparisonMetric(
                  'Total Visits',
                  currentTotal,
                  previousTotal,
                  Icons.trending_up,
                ),
                const SizedBox(width: 16),
                _buildComparisonMetric(
                  'Unique Faces',
                  currentData['uniqueFacesCount'] ?? 0,
                  (currentData['uniqueFacesCount'] ?? 0) * 0.9,
                  Icons.face,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: Comparison data is simulated for demonstration purposes',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonMetric(
    String label,
    num current,
    num previous,
    IconData icon,
  ) {
    final difference = current - previous;
    final percentChange =
        previous != 0 ? (difference / previous * 100).toStringAsFixed(1) : '∞';

    final isPositive = difference >= 0;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${current.toInt()}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: isPositive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  '$percentChange%',
                  style: TextStyle(
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'vs previous',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChartState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
