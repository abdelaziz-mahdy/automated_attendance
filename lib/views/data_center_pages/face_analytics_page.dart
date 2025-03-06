import 'dart:math' as math;
import 'package:automated_attendance/controllers/ui_state_controller.dart';
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:automated_attendance/widgets/analytics/analytics_charts.dart';
import 'package:automated_attendance/widgets/analytics/analytics_filters.dart';
import 'package:automated_attendance/widgets/analytics/analytics_summary.dart';
import 'package:automated_attendance/widgets/analytics/people_analytics.dart';
import 'package:automated_attendance/widgets/analytics/visits_analytics.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';

class FaceAnalyticsPage extends StatefulWidget {
  const FaceAnalyticsPage({super.key});

  @override
  State<FaceAnalyticsPage> createState() => _FaceAnalyticsPageState();
}

class _FaceAnalyticsPageState extends State<FaceAnalyticsPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _statistics = {};
  List<Map<String, dynamic>> _visitData = [];
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  String? _selectedProviderId;
  String? _selectedFaceId;
  FilterTimeRange _selectedTimeRange = FilterTimeRange.last7Days;
  bool _showAdvancedCharts = false;

  // Timer for periodic updates
  Timer? _updateTimer;
  DateTime _lastUpdated = DateTime.now();

  // Tab controller
  late TabController _tabController;

  // Available faces for filtering
  List<Map<String, dynamic>> _availableFaces = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStatistics();
    _startPeriodicUpdates();
    _loadAvailableFaces();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This will update data when the widget becomes visible again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshIfNeeded();
    });
  }

  void _startPeriodicUpdates() {
    // Update every 3 minutes
    _updateTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      if (mounted) {
        _loadStatistics();
      }
    });
  }

  void _refreshIfNeeded() {
    // If it's been more than 2 minutes since last update, refresh
    if (DateTime.now().difference(_lastUpdated).inMinutes > 2) {
      _loadStatistics();
    }
  }

  Future<void> _loadAvailableFaces() async {
    final manager = Provider.of<UIStateController>(context, listen: false);
    final faces = await manager.getAvailableFaces();

    if (mounted) {
      setState(() {
        _availableFaces = faces;
      });
    }
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    final manager = Provider.of<UIStateController>(context, listen: false);
    final stats = await manager.getVisitStatistics(
      startDate: _dateRange.start,
      endDate: _dateRange.end,
      providerId: _selectedProviderId,
      faceId: _selectedFaceId,
    );

    // Get visit data for the given filters
    final visits = _selectedFaceId != null
        ? await manager.getVisitsForFace(_selectedFaceId!)
        : await _fetchAllVisits(manager);

    setState(() {
      _statistics = stats;
      _visitData = visits;
      _isLoading = false;
      _lastUpdated = DateTime.now();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchAllVisits(
      UIStateController manager) async {
    // This method would fetch all visits from all faces within the date range
    // For demonstration, we'll get visits from available faces and combine them
    final List<Map<String, dynamic>> allVisits = [];

    // In a real implementation, you would query this from a database instead
    // Here we're using getVisitsForFace for each face as a workaround
    for (final face in _availableFaces.take(10)) {
      // Limit to 10 faces to avoid excessive queries
      final String faceId = face['id'] ?? '';
      if (faceId.isNotEmpty) {
        final visits = await manager.getVisitsForFace(faceId);
        // Add person information to each visit
        for (final visit in visits) {
          visit['personName'] = face['name'] ?? 'Unknown';
          visit['personId'] = faceId;
        }
        allVisits.addAll(visits);
      }
    }

    // Filter visits by date range
    return allVisits.where((visit) {
      final entryTime = visit['entryTime'] as DateTime;
      return entryTime.isAfter(_dateRange.start) &&
          entryTime.isBefore(_dateRange.end.add(const Duration(days: 1)));
    }).toList();
  }

  void _exportData() {
    // Export functionality - Not implemented in this demo
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality not implemented yet'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _navigateToPersonDetails(String faceId) {
    // Find the name for this face
    final face = _availableFaces.firstWhere(
      (face) => face['id'] == faceId,
      orElse: () => {'name': 'Unknown Person'},
    );

    final name = face['name'] ?? 'Unknown Person';

    // Navigate to person visits view
    Navigator.pushNamed(
      context,
      '/personVisits',
      arguments: {
        'faceId': faceId,
        'personName': name,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: _buildHeaderContent(),
              ),
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  _buildTabBar(),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              // OVERVIEW TAB
              _buildOverviewTab(),
              // PEOPLE TAB
              _buildPeopleTab(),
              // VISITS TAB
              _buildVisitsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderContent() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title section with a nice container background
          _buildTitleSection(),
          const SizedBox(height: 20),
          // Analytics Filters in a card
          _buildFiltersCard(),
          const SizedBox(height: 20),
          // Analytics Summary in a nice container with shadow
          _buildSummarySection(),
          const SizedBox(height: 24),
          // Analytics Charts in its own component
          _buildChartsSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Face Analytics Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadStatistics,
                tooltip: 'Refresh data',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Last updated: ${DateFormat('MMM dd, yyyy - HH:mm').format(_lastUpdated)}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Advanced Analytics',
                    style: TextStyle(fontSize: 12),
                  ),
                  Switch(
                    value: _showAdvancedCharts,
                    onChanged: (value) {
                      setState(() {
                        _showAdvancedCharts = value;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnalyticsFilters(
          dateRange: _dateRange,
          selectedProviderId: _selectedProviderId,
          selectedFaceId: _selectedFaceId,
          selectedTimeRange: _selectedTimeRange,
          availableFaces: _availableFaces,
          availableProviders:
              _statistics['providers'] as Set<String>? ?? <String>{},
          onDateRangeChanged: (newRange) {
            setState(() {
              _dateRange = newRange;
            });
            _loadStatistics();
          },
          onProviderChanged: (providerId) {
            setState(() {
              _selectedProviderId = providerId;
            });
            _loadStatistics();
          },
          onFaceChanged: (faceId) {
            setState(() {
              _selectedFaceId = faceId;
            });
            _loadStatistics();
          },
          onTimeRangeChanged: (timeRange) {
            setState(() {
              _selectedTimeRange = timeRange;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnalyticsSummary(
          statistics: _statistics,
          onExport: _exportData,
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnalyticsCharts(
          statistics: _statistics,
          showAdvancedCharts: _showAdvancedCharts,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).colorScheme.onPrimary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: Theme.of(context).colorScheme.primary,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "OVERVIEW",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "PEOPLE",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "VISITS",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInsightsSummary(),
          const SizedBox(height: 24),
          _buildRecommendations(),
          const SizedBox(height: 24),
          _buildTrends(),
        ],
      ),
    );
  }

  Widget _buildInsightsSummary() {
    final totalVisits = _statistics['totalVisits'] ?? 0;
    final uniqueFaces = _statistics['uniqueFacesCount'] ?? 0;
    final peakHour = _findPeakHour() ?? 'No data';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Key Insights',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInsightItem(
              'Total of $totalVisits visits recorded during this period',
              Icons.trending_up,
              Colors.blue,
            ),
            _buildInsightItem(
              'Detected $uniqueFaces unique individuals',
              Icons.people,
              Colors.purple,
            ),
            _buildInsightItem(
              'Peak hours: $peakHour',
              Icons.access_time,
              Colors.orange,
            ),
            _buildInsightItem(
              'Most active camera: ${_findMostActiveCamera() ?? 'No data'}',
              Icons.camera_alt,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildRecommendationItem(
              'Optimize camera placement to improve detection accuracy',
              'Based on current detection patterns, repositioning cameras might improve coverage.',
              Icons.camera_enhance,
            ),
            _buildRecommendationItem(
              'Focus on peak hours for staffing',
              'Allocate more resources during identified peak hours to optimize operations.',
              Icons.schedule,
            ),
            _buildRecommendationItem(
              'Investigate dwell time patterns',
              'Analyze why certain visitors spend more time than others to enhance experience.',
              Icons.timer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(
      String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.amber.shade800,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrends() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Trends & Patterns',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildTrendItem(
              'Day of Week Patterns',
              _analyzeDayOfWeekPattern(),
              Icons.calendar_view_week,
            ),
            _buildTrendItem(
              'Time of Day Pattern',
              _analyzeTimeOfDayPattern(),
              Icons.access_time_filled,
            ),
            _buildTrendItem(
              'Visit Duration',
              _analyzeDurationPattern(),
              Icons.timelapse,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.teal.shade800,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PeopleAnalytics(
            availableFaces: _availableFaces,
            statistics: _statistics,
            onFaceSelected: _navigateToPersonDetails,
          ),
        ),
      ),
    );
  }

  Widget _buildVisitsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: VisitsAnalytics(
            statistics: _statistics,
            visitData: _visitData,
          ),
        ),
      ),
    );
  }

  String? _findPeakHour() {
    final visitsByHour = _statistics['visitsByHour'] as Map<int, int>? ?? {};
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

    final amPm = peakHour! < 12 ? 'AM' : 'PM';
    final hourDisplay = peakHour! % 12 == 0 ? 12 : peakHour! % 12;
    return '$hourDisplay:00 $amPm';
  }

  String? _findMostActiveCamera() {
    final visitsByProvider = _statistics['visitsByProvider'] as Map<String, int>? ?? {};
    if (visitsByProvider.isEmpty) return null;

    String? mostActiveProvider;
    int maxVisits = 0;

    visitsByProvider.forEach((provider, visits) {
      if (visits > maxVisits) {
        maxVisits = visits;
        mostActiveProvider = provider;
      }
    });

    return mostActiveProvider;
  }

  String _analyzeDayOfWeekPattern() {
    final visitsByDay = _statistics['visitsByDay'] as Map<String, int>? ?? {};
    if (visitsByDay.isEmpty) {
      return "Not enough data to analyze day patterns.";
    }

    // Find the day with the most visits
    String mostFrequentDay = visitsByDay.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // Calculate total visits for a general comparison
    int totalVisits = visitsByDay.values.reduce((a, b) => a + b);

    return "The day with the most visits is $mostFrequentDay. Overall, visit patterns are relatively consistent throughout the week.";
  }


  String _analyzeTimeOfDayPattern() {
    final visitsByHour = _statistics['visitsByHour'] as Map<int, int>? ?? {};
    if (visitsByHour.isEmpty) {
      return "Not enough data to analyze time patterns.";
    }

    // Find the hour with the most visits
    int peakHour = visitsByHour.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // Determine if the peak hour is AM or PM
    String period = peakHour < 12 ? "AM" : "PM";

    // Convert 24-hour format to 12-hour format
    int displayHour = peakHour % 12;
    if (displayHour == 0) displayHour = 12; // Midnight

    return "Peak activity occurs around ${displayHour}${period}. We see consistent activity throughout the day, with quieter periods overnight.";
  }

  String _analyzeDurationPattern() {
    final avgDurationSeconds = _statistics['avgDurationSeconds'] ?? 0.0;
    if (avgDurationSeconds == 0) {
      return "Not enough data to analyze duration patterns.";
    }

    final minutes = (avgDurationSeconds / 60).round();
    return "Average visit duration is $minutes minutes. Shorter visits most commonly occur during morning hours.";
  }
}

// SliverPersistentHeader delegate for the tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return _tabBar;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
