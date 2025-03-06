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
        _buildVisitsHeader(context),
        const SizedBox(height: 20),
        _buildFilterOptions(),
        const SizedBox(height: 20),
        _buildVisitsCalendarCard(),
        const SizedBox(height: 20),
        _buildSelectedDayVisits(),
        const SizedBox(height: 24),
        _buildRecentVisitsTable(filteredVisits),
      ],
    );
  }

  Widget _buildVisitsHeader(BuildContext context) {
    // Count stats for header section
    final allVisits = widget.visitData.length;
    final activeVisits = widget.visitData.where((v) => v['isActive'] == true).length;
    final completedVisits = allVisits - activeVisits;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visits Log & Calendar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$allVisits total visits • $activeVisits active • $completedVisits completed',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Export'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Export functionality not implemented'),
                  ),
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, 
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Filter Visits',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Provider',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedProviderId.isEmpty ? null : _selectedProviderId,
                    hint: const Text('All Providers'),
                    isExpanded: true,
                    onChanged: (newValue) {
                      setState(() {
                        _selectedProviderId = newValue ?? '';
                      });
                    },
                    items: providersList.map((provider) {
                      return DropdownMenuItem<String>(
                        value: provider == 'All Providers' ? '' : provider,
                        child: Text(provider),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
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
                        ),
                        const SizedBox(width: 8),
                        const Text('Active Visits Only'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
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
                        ),
                        const SizedBox(width: 8),
                        const Text('Completed Visits Only'),
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

  Widget _buildVisitsCalendarCard() {
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
              children: [
                Icon(
                  Icons.calendar_month,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Visit Calendar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _eventsMap.isEmpty
                        ? 'No visits recorded in the calendar'
                        : 'Dots indicate visits on that day',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayVisits() {
    final events = _getEventsForDay(_selectedDay);
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay);

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
                    Row(
                      children: [
                        Icon(
                          Icons.event,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Visits on $formattedDate',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      events.isEmpty ? 'No visits' : '${events.length} visits',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (events.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Sort'),
                    onPressed: () {
                      // Sort options would be added here
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sorting not implemented'),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const Divider(height: 24),
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
                  itemBuilder: (context, index) {
                    final visit = events[index];
                    return _buildVisitItem(visit);
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Recent Visits',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Most recent ${recentVisits.length} of ${visits.length} visits',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    // Table options would be added here
                  },
                ),
              ],
            ),
            const Divider(height: 24),

            // Header row with styled containers
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'PERSON',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'ENTRY TIME',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'EXIT / DURATION',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'STATUS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Visit rows
            recentVisits.isEmpty
                ? SizedBox(
                    height: 100,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 32,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No visit data available',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentVisits.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Person column
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Text(
                    personName.isNotEmpty ? personName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    personName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
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
                  DateFormat('MMM d, yyyy').format(entryTime),
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
                        DateFormat('MMM d, yyyy').format(exitTime),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Row(
                        children: [
                          Text(
                            DateFormat('h:mm a').format(exitTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (duration != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatDuration(duration),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  )
                : Text(
                    'Still Active',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
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
                  color: isActive ? Colors.green[700] : Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Text(
                    personName.isNotEmpty ? personName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'COMPLETED',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isActive ? Colors.green[700] : Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildVisitDetail(
                    'Entry Time',
                    '${DateFormat('MMM d, yyyy').format(entryTime)} at ${DateFormat('h:mm a').format(entryTime)}',
                    Icons.login,
                  ),
                ),
                if (exitTime != null)
                  Expanded(
                    child: _buildVisitDetail(
                      'Exit Time',
                      '${DateFormat('MMM d, yyyy').format(exitTime)} at ${DateFormat('h:mm a').format(exitTime)}',
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
                    'Camera Provider',
                    providerId,
                    Icons.camera_alt,
                  ),
                ),
                Expanded(
                  child: _buildVisitDetail(
                    'Status',
                    isActive ? 'Still Present' : 'Visit Completed',
                    isActive ? Icons.person : Icons.check_circle,
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
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
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
