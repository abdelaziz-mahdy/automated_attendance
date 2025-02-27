import 'package:automated_attendance/models/tracked_face.dart';
import 'package:automated_attendance/services/camera_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

class PersonVisitsView extends StatefulWidget {
  final String faceId;
  final String personName;

  const PersonVisitsView({
    super.key,
    required this.faceId,
    required this.personName,
  });

  @override
  State<PersonVisitsView> createState() => _PersonVisitsViewState();
}

class _PersonVisitsViewState extends State<PersonVisitsView> {
  List<Map<String, dynamic>> _visits = [];
  bool _isLoading = true;
  ViewMode _currentViewMode = ViewMode.list;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Create a map of dates to events for the calendar
  late Map<DateTime, List<Map<String, dynamic>>> _eventsMap;

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    setState(() {
      _isLoading = true;
    });

    final manager = Provider.of<CameraManager>(context, listen: false);
    final visits = await manager.getVisitsForFace(widget.faceId);

    setState(() {
      _visits = visits;
      _isLoading = false;

      // Initialize events map for calendar
      _eventsMap = _generateEventsMap(visits);
    });
  }

  // Generate events map from visits for the table calendar
  Map<DateTime, List<Map<String, dynamic>>> _generateEventsMap(
      List<Map<String, dynamic>> visits) {
    final eventsMap = <DateTime, List<Map<String, dynamic>>>{};

    for (final visit in visits) {
      final entryTime = visit['entryTime'] as DateTime;
      // Convert to date without time
      final visitDate =
          DateTime(entryTime.year, entryTime.month, entryTime.day);

      if (eventsMap.containsKey(visitDate)) {
        eventsMap[visitDate]!.add(visit);
      } else {
        eventsMap[visitDate] = [visit];
      }
    }

    return eventsMap;
  }

  // Get events for a specific day
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _eventsMap[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.personName} - Visit History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVisits,
            tooltip: 'Refresh Data',
          ),
          // View mode toggle
          PopupMenuButton<ViewMode>(
            tooltip: 'Change View',
            icon: Icon(_currentViewMode == ViewMode.list
                ? Icons.view_list
                : Icons.calendar_month),
            onSelected: (ViewMode mode) {
              setState(() {
                _currentViewMode = mode;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<ViewMode>>[
              const PopupMenuItem<ViewMode>(
                value: ViewMode.list,
                child: Text('List View'),
              ),
              const PopupMenuItem<ViewMode>(
                value: ViewMode.calendar,
                child: Text('Calendar View'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_visits.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildVisitsSummary(),
        const Divider(),
        Expanded(
          child: _currentViewMode == ViewMode.list
              ? _buildVisitsList()
              : _buildCalendarView(),
        ),
      ],
    );
  }

  Widget _buildVisitsSummary() {
    // Calculate summary statistics
    final totalVisits = _visits.length;
    final completedVisits = _visits.where((v) => v['exitTime'] != null).length;
    final activeVisits = _visits.where((v) => v['exitTime'] == null).length;

    // Calculate average duration for completed visits
    Duration? avgDuration;
    final completedVisitsList =
        _visits.where((v) => v['duration'] != null).toList();
    if (completedVisitsList.isNotEmpty) {
      final totalDuration = completedVisitsList.fold<Duration>(
          Duration.zero, (sum, visit) => sum + (visit['duration'] as Duration));
      avgDuration = Duration(
          seconds: totalDuration.inSeconds ~/ completedVisitsList.length);
    }

    // Get date of first and last visit
    DateTime? firstVisitDate;
    DateTime? lastVisitDate;
    if (_visits.isNotEmpty) {
      _visits.sort((a, b) =>
          (a['entryTime'] as DateTime).compareTo(b['entryTime'] as DateTime));
      firstVisitDate = _visits.first['entryTime'] as DateTime;
      lastVisitDate = _visits.last['entryTime'] as DateTime;
    }

    // Get unique providers
    final providers = _visits.map((v) => v['providerId'] as String).toSet();

    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visit Statistics for ${widget.personName}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildStatCard(
                  'Total Visits', '$totalVisits', Icons.analytics, Colors.blue),
              _buildStatCard('Completed', '$completedVisits', Icons.task_alt,
                  Colors.green),
              if (activeVisits > 0)
                _buildStatCard('Active', '$activeVisits', Icons.brightness_1,
                    Colors.orange),
              if (avgDuration != null)
                _buildStatCard(
                    'Avg Duration',
                    '${avgDuration.inHours}h ${avgDuration.inMinutes % 60}m',
                    Icons.timer,
                    Colors.purple),
              if (firstVisitDate != null)
                _buildStatCard(
                    'First Visit',
                    DateFormat('MM/dd/yyyy').format(firstVisitDate),
                    Icons.first_page,
                    Colors.teal),
              if (lastVisitDate != null)
                _buildStatCard(
                    'Last Visit',
                    DateFormat('MM/dd/yyyy').format(lastVisitDate),
                    Icons.last_page,
                    Colors.indigo),
              _buildStatCard('Providers', providers.length.toString(),
                  Icons.camera_alt, Colors.brown),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: color,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitsList() {
    // Sort visits by entry time (latest first)
    final sortedVisits = List<Map<String, dynamic>>.from(_visits);
    sortedVisits.sort((a, b) =>
        (b['entryTime'] as DateTime).compareTo(a['entryTime'] as DateTime));

    return ListView.builder(
      itemCount: sortedVisits.length,
      itemBuilder: (context, index) {
        final visit = sortedVisits[index];
        final entryTime = visit['entryTime'] as DateTime;
        final exitTime = visit['exitTime'] as DateTime?;
        final duration = visit['duration'] as Duration?;
        final isActive = visit['isActive'] as bool;
        final providerId = visit['providerId'] as String;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isActive ? Colors.green : Colors.blue,
              child: Icon(
                isActive ? Icons.brightness_1 : Icons.check,
                color: Colors.white,
              ),
            ),
            title: Row(
              children: [
                Text(DateFormat('MMM d, yyyy').format(entryTime)),
                const SizedBox(width: 8),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Entry: ${DateFormat('HH:mm:ss').format(entryTime)}'),
                if (exitTime != null)
                  Text('Exit: ${DateFormat('HH:mm:ss').format(exitTime)}'),
                if (duration != null)
                  Text('Duration: ${_formatDuration(duration)}'),
                Text('Provider: $providerId'),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        // Calendar header
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) {
            return isSameDay(_selectedDay, day);
          },
          eventLoader: _getEventsForDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarStyle: CalendarStyle(
            markersMaxCount: 3,
            markerDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
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
        const SizedBox(height: 8),
        Expanded(
          child: _buildEventsForSelectedDay(),
        ),
      ],
    );
  }

  Widget _buildEventsForSelectedDay() {
    final events = _getEventsForDay(_selectedDay);

    if (events.isEmpty) {
      return Center(
        child: Text(
          'No visits on ${DateFormat('MMM d, yyyy').format(_selectedDay)}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
      );
    }

    // Sort by entry time
    events.sort((a, b) =>
        (a['entryTime'] as DateTime).compareTo(b['entryTime'] as DateTime));

    return ListView.builder(
      itemCount: events.length,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemBuilder: (context, index) {
        final event = events[index];
        final entryTime = event['entryTime'] as DateTime;
        final exitTime = event['exitTime'] as DateTime?;
        final duration = event['duration'] as Duration?;
        final isActive = event['isActive'] as bool;
        final providerId = event['providerId'] as String;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        isActive ? Icons.circle : Icons.check_circle,
                        color: isActive ? Colors.green : Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('HH:mm:ss').format(entryTime),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isActive ? 'Active visit' : 'Completed visit',
                            style: TextStyle(
                              color: isActive ? Colors.green : Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.5)),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    _buildIconWithText(
                      Icons.login,
                      'Entry',
                      DateFormat('HH:mm:ss').format(entryTime),
                    ),
                    const SizedBox(width: 16),
                    if (exitTime != null)
                      _buildIconWithText(
                        Icons.logout,
                        'Exit',
                        DateFormat('HH:mm:ss').format(exitTime),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (duration != null)
                      _buildIconWithText(
                        Icons.timer,
                        'Duration',
                        _formatDuration(duration),
                      ),
                    const SizedBox(width: 16),
                    _buildIconWithText(
                      Icons.camera,
                      'Provider',
                      providerId,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconWithText(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No Visits Recorded',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This person has not been detected by any cameras yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
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
}

// Enum for view modes
enum ViewMode {
  list,
  calendar,
}
