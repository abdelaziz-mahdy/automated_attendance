import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class VisitsAnalytics extends StatefulWidget {
  final Map<String, dynamic> statistics;
  final List<Map<String, dynamic>> visitData;

  const VisitsAnalytics({
    super.key,
    required this.statistics,
    required this.visitData,
  });

  @override
  State<VisitsAnalytics> createState() => _VisitsAnalyticsState();
}

class _VisitsAnalyticsState extends State<VisitsAnalytics> {
  // Calendar view related variables
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  late Map<DateTime, List<Map<String, dynamic>>> _eventsMap;

  // Visit filtering variables
  bool _showOnlyActive = false;
  bool _showOnlyCompleted = false;
  String _selectedProviderId = '';

  @override
  void initState() {
    super.initState();
    _generateEventsMap();
  }

  @override
  void didUpdateWidget(VisitsAnalytics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visitData != oldWidget.visitData) {
      _generateEventsMap();
    }
  }

  void _generateEventsMap() {
    final eventsMap = <DateTime, List<Map<String, dynamic>>>{};

    for (final visit in widget.visitData) {
      final entryTime = visit['entryTime'] as DateTime?;
      if (entryTime != null) {
        // Convert to date without time
        final visitDate =
            DateTime(entryTime.year, entryTime.month, entryTime.day);

        if (eventsMap.containsKey(visitDate)) {
          eventsMap[visitDate]!.add(visit);
        } else {
          eventsMap[visitDate] = [visit];
        }
      }
    }

    setState(() {
      _eventsMap = eventsMap;
    });
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final List<Map<String, dynamic>> events = _eventsMap[normalizedDay] ?? [];

    return _applyVisitFilters(events);
  }

  List<Map<String, dynamic>> _applyVisitFilters(
      List<Map<String, dynamic>> visits) {
    if (visits.isEmpty) return [];

    return visits.where((visit) {
      // Apply active/completed filter
      if (_showOnlyActive && !(visit['isActive'] ?? false)) {
        return false;
      }

      if (_showOnlyCompleted && (visit['isActive'] ?? false)) {
        return false;
      }

      // Apply provider filter
      if (_selectedProviderId.isNotEmpty &&
          visit['providerId'] != _selectedProviderId) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredVisits = _applyVisitFilters(widget.visitData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        _buildFilterOptions(),
        const SizedBox(height: 16),
        _buildVisitsCalendar(),
        const SizedBox(height: 16),
        _buildSelectedDayVisits(),
        const SizedBox(height: 24),
        _buildRecentVisitsTable(filteredVisits),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Visits Analytics',
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
            IconButton(
              tooltip: 'Refresh Data',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _generateEventsMap();
                setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterOptions() {
    final providers =
        widget.statistics['providers'] as Set<String>? ?? <String>{};
    final providersList = ['All Providers', ...providers];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Visits',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Provider',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    value: _selectedProviderId.isEmpty
                        ? null
                        : _selectedProviderId,
                    hint: const Text('All Providers'),
                    isExpanded: true,
                    items: providersList.map((provider) {
                      return DropdownMenuItem<String>(
                        value: provider == 'All Providers' ? '' : provider,
                        child: Text(provider),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedProviderId = value ?? '';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _showOnlyActive,
                          onChanged: (value) {
                            setState(() {
                              _showOnlyActive = value ?? false;
                              if (_showOnlyActive) {
                                _showOnlyCompleted = false;
                              }
                            });
                          },
                        ),
                        const Text('Active Only'),
                      ],
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: _showOnlyCompleted,
                          onChanged: (value) {
                            setState(() {
                              _showOnlyCompleted = value ?? false;
                              if (_showOnlyCompleted) {
                                _showOnlyActive = false;
                              }
                            });
                          },
                        ),
                        const Text('Completed Only'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitsCalendar() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visit Calendar',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
                CalendarFormat.twoWeeks: '2 Weeks',
                CalendarFormat.week: 'Week',
              },
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                markersMaxCount: 3,
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                markerSize: 8,
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: true,
                formatButtonShowsNext: false,
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
            Center(
              child: Text(
                _eventsMap.isEmpty
                    ? 'No visits recorded in the calendar'
                    : 'Dot indicates visits on that day',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayVisits() {
    final events = _getEventsForDay(_selectedDay);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visits on ${DateFormat('MMMM d, yyyy').format(_selectedDay)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      events.isEmpty
                          ? 'No visits on this day'
                          : '${events.length} visits',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (events.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Share functionality not implemented')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
              ],
            ),
            if (events.isEmpty)
              SizedBox(
                height: 100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 32,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No visits recorded on this day',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 250,
                child: ListView.builder(
                  itemCount: events.length,
                  padding: const EdgeInsets.only(top: 16),
                  itemBuilder: (context, index) {
                    return _buildVisitItem(events[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentVisitsTable(List<Map<String, dynamic>> visits) {
    // Sort visits by entry time (latest first)
    final sortedVisits = List<Map<String, dynamic>>.from(visits);
    sortedVisits.sort((a, b) =>
        (b['entryTime'] as DateTime).compareTo(a['entryTime'] as DateTime));

    // Limit to most recent 10 visits
    final recentVisits = sortedVisits.take(10).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Visits',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Showing ${recentVisits.length} of ${visits.length} visits',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Person',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Entry Time',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Exit / Duration',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // Visit rows
            recentVisits.isEmpty
                ? SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        'No visits matched the filter criteria',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentVisits.length,
                    itemBuilder: (context, index) {
                      final visit = recentVisits[index];
                      return _buildVisitTableRow(visit);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitTableRow(Map<String, dynamic> visit) {
    final entryTime = visit['entryTime'] as DateTime;
    final exitTime = visit['exitTime'] as DateTime?;
    final duration = visit['duration'] as Duration?;
    final isActive = visit['isActive'] as bool? ?? false;
    final personName = visit['personName'] as String? ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Person column
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    personName.isNotEmpty ? personName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    personName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // Entry time column
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM d').format(entryTime),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  DateFormat('h:mm a').format(entryTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Exit/Duration column
          Expanded(
            flex: 2,
            child: exitTime != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('h:mm a').format(exitTime),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatDuration(duration ?? Duration.zero),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Still Active',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
          ),

          // Status column
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? 'Active' : 'Complete',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.green : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitItem(Map<String, dynamic> visit) {
    final entryTime = visit['entryTime'] as DateTime;
    final exitTime = visit['exitTime'] as DateTime?;
    final duration = visit['duration'] as Duration?;
    final isActive = visit['isActive'] as bool? ?? false;
    final providerId = visit['providerId'] as String? ?? 'Unknown';
    final personName = visit['personName'] as String? ?? 'Unknown';
    final personId = visit['personId'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isActive
                      ? Colors.green.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.2),
                  child: Icon(
                    isActive ? Icons.person : Icons.how_to_reg,
                    color: isActive ? Colors.green : Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        personName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (personId.isNotEmpty)
                        Text(
                          'ID: $personId',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'COMPLETED',
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? Colors.green : Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildVisitDetail(
                    'Entry Time',
                    DateFormat('h:mm a').format(entryTime),
                    Icons.login,
                  ),
                ),
                if (exitTime != null)
                  Expanded(
                    child: _buildVisitDetail(
                      'Exit Time',
                      DateFormat('h:mm a').format(exitTime),
                      Icons.logout,
                    ),
                  ),
                if (duration != null)
                  Expanded(
                    child: _buildVisitDetail(
                      'Duration',
                      _formatDuration(duration),
                      Icons.timer,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildVisitDetail(
                    'Provider',
                    providerId,
                    Icons.videocam,
                  ),
                ),
                Expanded(
                  child: _buildVisitDetail(
                    'Date',
                    DateFormat('MMM d, yyyy').format(entryTime),
                    Icons.calendar_today,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitDetail(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
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
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    final List<String> parts = [];
    if (hours > 0) parts.add('$hours h');
    if (minutes > 0) parts.add('$minutes m');
    if (hours == 0 && seconds > 0) parts.add('$seconds s');

    return parts.join(' ');
  }
}
