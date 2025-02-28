import 'dart:math' as Math;

import 'package:automated_attendance/services/camera_manager.dart';
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
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  Map<String, dynamic> _statistics = {};
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  String? _selectedProviderId;
  bool _ignoreTouch = false;

  // Timer for periodic updates
  Timer? _updateTimer;
  DateTime _lastUpdated = DateTime.now();

  // Face filtering variables
  String? _selectedFaceId;
  String _searchQuery = '';
  List<Map<String, dynamic>> _availableFaces = [];
  bool _isSearching = false;

  // Calendar view related variables
  bool _showCalendarView = false;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<dynamic>> _eventsMap = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    _startPeriodicUpdates();

    // Load available faces
    _loadAvailableFaces();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
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
    final manager = Provider.of<CameraManager>(context, listen: false);
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

    final manager = Provider.of<CameraManager>(context, listen: false);
    final stats = await manager.getVisitStatistics(
      startDate: _dateRange.start,
      endDate: _dateRange.end,
      providerId: _selectedProviderId,
      faceId: _selectedFaceId,
    );

    setState(() {
      _statistics = stats;
      _isLoading = false;
      _lastUpdated = DateTime.now();
      _generateEventsMap();
    });
  }

  // Generate events map for the calendar view
  void _generateEventsMap() {
    final visitsByDay = _statistics['visitsByDay'] as Map<String, int>? ?? {};
    final eventsMap = <DateTime, List<dynamic>>{};

    for (var entry in visitsByDay.entries) {
      final dateString = entry.key;
      final count = entry.value;

      final parts = dateString.split('-');
      if (parts.length >= 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);

        final date = DateTime(year, month, day);
        eventsMap[date] = List.generate(count, (index) => 'Visit ${index + 1}');
      }
    }

    setState(() {
      _eventsMap = eventsMap;
    });
  }

  // Get events for a specific day
  List<dynamic> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _eventsMap[normalizedDay] ?? [];
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
                  _buildLastUpdatedInfo(),
                  const SizedBox(height: 16),
                  _buildFaceFilterSection(),
                  const SizedBox(height: 16),
                  _buildViewToggle(),
                  const SizedBox(height: 16),
                  _buildProviderSelector(),
                  const SizedBox(height: 24),
                  _buildStatCards(),
                  const SizedBox(height: 24),
                  _buildDailyVisitsChart(),
                  const SizedBox(height: 24),
                  _buildHourlyDistributionChart(),
                  const SizedBox(height: 32),
                  _buildCalendarViewSection(),
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
      automaticallyImplyLeading: false,
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

  Widget _buildLastUpdatedInfo() {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        'Last updated: ${DateFormat('MMM dd, yyyy - HH:mm').format(_lastUpdated)}',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildFaceFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter by Face',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search faces by name',
                    prefixIcon: const Icon(Icons.search),
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
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                _showFaceSelectionDialog();
              },
              child: const Text('Select Face'),
            ),
          ],
        ),
        if (_selectedFaceId != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Chip(
              label: Text(_getFaceNameById(_selectedFaceId!)),
              onDeleted: () {
                setState(() {
                  _selectedFaceId = null;
                });
                _loadStatistics();
              },
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
      ],
    );
  }

  String _getFaceNameById(String id) {
    final face = _availableFaces.firstWhere(
      (face) => face['id'] == id,
      orElse: () => {'name': 'Unknown'},
    );
    return face['name'] ?? 'Unknown';
  }

  void _showFaceSelectionDialog() {
    final filteredFaces = _searchQuery.isEmpty
        ? _availableFaces
        : _availableFaces
            .where((face) => face['name']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select a Face'),
        content: SizedBox(
          width: double.maxFinite,
          child: filteredFaces.isEmpty
              ? const Center(child: Text('No faces found'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredFaces.length,
                  itemBuilder: (context, index) {
                    final face = filteredFaces[index];
                    return ListTile(
                      leading: face['imageUrl'] != null
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(face['imageUrl']),
                            )
                          : const CircleAvatar(child: Icon(Icons.face)),
                      title: Text(face['name'] ?? 'Unknown'),
                      subtitle: Text('ID: ${face['id'] ?? 'N/A'}'),
                      selected: _selectedFaceId == face['id'],
                      onTap: () {
                        setState(() {
                          _selectedFaceId = face['id'];
                          _searchQuery = '';
                          _isSearching = false;
                        });
                        Navigator.pop(context);
                        _loadStatistics();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedFaceId = null;
                _searchQuery = '';
                _isSearching = false;
              });
              Navigator.pop(context);
              _loadStatistics();
            },
            child: const Text('Clear Selection'),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          'Show Calendar Details',
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: _showCalendarView,
          onChanged: (value) {
            setState(() {
              _showCalendarView = value;
            });
          },
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

  Widget _buildCalendarViewSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Visit Calendar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              IconButton(
                icon: Icon(_showCalendarView
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down),
                onPressed: () {
                  setState(() {
                    _showCalendarView = !_showCalendarView;
                  });
                },
              ),
            ],
          ),
          if (_showCalendarView) ...[
            const SizedBox(height: 16),
            _buildEnhancedCalendarView(),
          ],
        ],
      ),
    );
  }

  Widget _buildEnhancedCalendarView() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildCalendarHeader(),
            const SizedBox(height: 8),
            TableCalendar(
              firstDay: _dateRange.start.subtract(const Duration(days: 30)),
              lastDay: _dateRange.end.add(const Duration(days: 30)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                markersMaxCount: 4,
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                markerSize: 8,
                markersAnchor: 0.7,
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                tableBorder: TableBorder(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                  horizontalInside:
                      BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                formatButtonShowsNext: false,
                titleCentered: true,
                formatButtonDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
            ),
            const Divider(height: 32),
            _buildSelectedDayVisits(),
            if (_eventsMap.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDailyVisitsList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Calendar shows visits from ${DateFormat('MMM dd').format(_dateRange.start)} to ${DateFormat('MMM dd').format(_dateRange.end)}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyVisitsList() {
    final visitDays = _eventsMap.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Sort by most recent

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Visit Days',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 100,
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: Math.min(10, visitDays.length),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemBuilder: (context, index) {
              final day = visitDays[index];
              final events = _eventsMap[day] ?? [];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDay = day;
                    _focusedDay = day;
                  });
                },
                child: Container(
                  width: 100,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSameDay(_selectedDay, day)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSameDay(_selectedDay, day)
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('MMM dd').format(day),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSameDay(_selectedDay, day)
                              ? Colors.white
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${events.length} visits',
                        style: TextStyle(
                          color: isSameDay(_selectedDay, day)
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: isSameDay(_selectedDay, day)
                            ? Colors.white
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDayVisits() {
    final events = _getEventsForDay(_selectedDay);
    final dateString =
        '${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}';
    final visitCount = _statistics['visitsByDay']?[dateString] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildDetailCard(
                'Total Visits',
                '$visitCount',
                Icons.remove_red_eye,
                Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildDetailCard(
                'Unique Faces',
                '${events.length}',
                Icons.face,
                Colors.purple,
              ),
            ],
          ),
          if (events.isEmpty && visitCount == 0)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(
                child: Text(
                  'No visits recorded on this day',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
