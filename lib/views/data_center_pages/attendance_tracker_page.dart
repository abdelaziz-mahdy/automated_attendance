import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:automated_attendance/controllers/ui_state_controller.dart';
import 'package:automated_attendance/widgets/dialogs/expected_attendees_dialog.dart';

// Enum for categorizing arrivals - moved to top level
enum ArrivalCategory { early, onTime, late }

class AttendanceTrackerPage extends StatefulWidget {
  const AttendanceTrackerPage({super.key});

  @override
  State<AttendanceTrackerPage> createState() => _AttendanceTrackerPageState();
}

class _AttendanceTrackerPageState extends State<AttendanceTrackerPage>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  Map<String, dynamic> _attendanceData = {};
  Timer? _refreshTimer;
  TimeOfDay _scheduleTime = const TimeOfDay(hour: 9, minute: 0); // Default 9:00 AM
  int _earlyMinutes = 15; // Early is 15 minutes before schedule
  int _lateMinutes = 5; // Late is 5 minutes after schedule
  
  // State to track counts in each category
  int _earlyCount = 0;
  int _onTimeCount = 0;
  int _lateCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAttendanceData();

    // Setup periodic refresh
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _loadAttendanceData(),
    );

    // Register for attendance updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<UIStateController>(context, listen: false);
      controller.onAttendanceUpdated = _loadAttendanceData;
    });
  }
  
  // Load saved attendance settings
  Future<void> _loadSettings() async {
    // In a real app, these would be loaded from SharedPreferences
    // For now, we'll use defaults defined in the class
  }
  
  // Save attendance settings
  Future<void> _saveSettings() async {
    // In a real app, these would be saved to SharedPreferences
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();

    // Remove callback when disposed
    if (context.mounted) {
      Provider.of<UIStateController>(context, listen: false)
          .onAttendanceUpdated = null;
    }

    super.dispose();
  }

  Future<void> _loadAttendanceData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final controller = Provider.of<UIStateController>(context, listen: false);
    final data = await controller.getTodayAttendance();
    
    if (mounted) {
      // Reset attendance category counts
      _earlyCount = 0;
      _onTimeCount = 0;
      _lateCount = 0;
      
      // Process present attendees to categorize by arrival time
      final presentList = data['present'] as List<Map<String, dynamic>>;
      
      // Categorize each present person based on arrival time
      for (var person in presentList) {
        final arrivalTime = person['arrivalTime'] as DateTime;
        final category = _categorizeArrival(arrivalTime);
        
        // Increment the appropriate counter
        switch (category) {
          case ArrivalCategory.early:
            _earlyCount++;
            person['arrivalCategory'] = 'early';
            break;
          case ArrivalCategory.onTime:
            _onTimeCount++;
            person['arrivalCategory'] = 'on-time';
            break;
          case ArrivalCategory.late:
            _lateCount++;
            person['arrivalCategory'] = 'late';
            break;
        }
      }
      
      // Sort present list by arrival time
      presentList.sort((a, b) => (a['arrivalTime'] as DateTime).compareTo(b['arrivalTime'] as DateTime));
      
      setState(() {
        _attendanceData = data;
        _isLoading = false;
      });
    }
  }
  
  // Categorize an arrival time based on schedule settings
  ArrivalCategory _categorizeArrival(DateTime arrivalTime) {
    // Convert schedule time to a DateTime for comparison
    final now = DateTime.now();
    final scheduleDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _scheduleTime.hour,
      _scheduleTime.minute,
    );
    
    // Calculate early and late thresholds
    final earlyThreshold = scheduleDateTime.subtract(Duration(minutes: _earlyMinutes));
    final lateThreshold = scheduleDateTime.add(Duration(minutes: _lateMinutes));
    
    if (arrivalTime.isBefore(earlyThreshold)) {
      return ArrivalCategory.early;
    } else if (arrivalTime.isAfter(lateThreshold)) {
      return ArrivalCategory.late;
    } else {
      return ArrivalCategory.onTime;
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
    final today = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    final present = _attendanceData['present'] as List<Map<String, dynamic>>;
    final absent = _attendanceData['absent'] as List<Map<String, dynamic>>;
    
    // Fix the attendance rate calculation - use the values directly from the data
    final presentCount = _attendanceData['presentCount'] as int;
    final expectedCount = _attendanceData['expectedCount'] as int;
    
    // Calculate the actual attendance rate
    final attendanceRate = expectedCount > 0 
        ? (presentCount / expectedCount * 100).toStringAsFixed(1)
        : '0.0';

    return RefreshIndicator(
      onRefresh: _loadAttendanceData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
                today, attendanceRate, presentCount, expectedCount),
            const SizedBox(height: 16),
            _buildScheduleSettings(),
            const SizedBox(height: 24),
            _buildAttendanceStatusCards(),
            const SizedBox(height: 24),
            _buildPresentSection(present),
            const SizedBox(height: 24),
            _buildAbsentSection(absent),
          ],
        ),
      ),
    );
  }
  
  Widget _buildScheduleSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Schedule Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Schedule Time'),
                    subtitle: Text(
                      _scheduleTime.format(context),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () async {
                        final TimeOfDay? newTime = await showTimePicker(
                          context: context,
                          initialTime: _scheduleTime,
                        );
                        if (newTime != null && mounted) {
                          setState(() {
                            _scheduleTime = newTime;
                          });
                          _saveSettings();
                          _loadAttendanceData(); // Recategorize attendees
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text('Early: '),
                          Expanded(
                            child: Slider(
                              min: 5,
                              max: 60,
                              divisions: 11,
                              value: _earlyMinutes.toDouble(),
                              label: '$_earlyMinutes min',
                              onChanged: (value) {
                                setState(() {
                                  _earlyMinutes = value.round();
                                });
                                _saveSettings();
                                _loadAttendanceData(); // Recategorize attendees
                              },
                            ),
                          ),
                          Text('$_earlyMinutes min'),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Late: '),
                          Expanded(
                            child: Slider(
                              min: 1,
                              max: 30,
                              divisions: 29,
                              value: _lateMinutes.toDouble(),
                              label: '$_lateMinutes min',
                              onChanged: (value) {
                                setState(() {
                                  _lateMinutes = value.round();
                                });
                                _saveSettings();
                                _loadAttendanceData(); // Recategorize attendees
                              },
                            ),
                          ),
                          Text('$_lateMinutes min'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String today, String attendanceRate, int presentCount,
      int expectedCount) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        today,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const ExpectedAttendeesDialog(),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Manage Expected'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadAttendanceData,
                  tooltip: 'Refresh attendance data',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance rate',
                      style: TextStyle(fontSize: 16),
                    ),
                    Row(
                      children: [
                        Text(
                          '$attendanceRate%',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '($presentCount of $expectedCount)',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(
                  height: 60,
                  width: 60,
                  child: CircularProgressIndicator(
                    value: expectedCount > 0 ? presentCount / expectedCount : 0,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getAttendanceColor(
                          expectedCount > 0 ? presentCount / expectedCount : 0),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getAttendanceColor(double rate) {
    if (rate >= 0.8) return Colors.green;
    if (rate >= 0.5) return Colors.orange;
    return Colors.red;
  }
  
  Widget _buildAttendanceStatusCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            'Attendance Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                'Early',
                _earlyCount.toString(),
                Icons.arrow_upward,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatusCard(
                'On Time',
                _onTimeCount.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatusCard(
                'Late',
                _lateCount.toString(),
                Icons.warning,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(
      String title, String count, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresentSection(List<Map<String, dynamic>> present) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'Present Today',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: present.isEmpty
              ? const ListTile(
                  leading: Icon(Icons.info),
                  title: Text('No attendance recorded yet today'),
                )
              : ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: present.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final person = present[index];
                    final arrivalTime = DateFormat('h:mm a')
                        .format(person['arrivalTime'] as DateTime);
                    final category = person['arrivalCategory'] as String? ?? 'unknown';
                    
                    Color statusColor;
                    IconData statusIcon;
                    
                    // Set icon and color based on arrival category
                    switch (category) {
                      case 'early':
                        statusColor = Colors.blue;
                        statusIcon = Icons.arrow_upward;
                        break;
                      case 'on-time':
                        statusColor = Colors.green;
                        statusIcon = Icons.check_circle;
                        break;
                      case 'late':
                        statusColor = Colors.orange;
                        statusIcon = Icons.warning;
                        break;
                      default:
                        statusColor = Colors.grey;
                        statusIcon = Icons.help_outline;
                        break;
                    }
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: person['thumbnail'] != null
                            ? MemoryImage(person['thumbnail'])
                            : null,
                        child: person['thumbnail'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        person['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Row(
                        children: [
                          Icon(
                            statusIcon,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text('Arrived at $arrivalTime (${category.toUpperCase()})'),
                        ],
                      ),
                      trailing: _buildAttendanceActions(person),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAbsentSection(List<Map<String, dynamic>> absent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'Expected But Absent',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: absent.isEmpty
              ? const ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('All expected people are present!'),
                )
              : ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: absent.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final person = absent[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: person['thumbnail'] != null
                            ? MemoryImage(person['thumbnail'])
                            : null,
                        backgroundColor: Colors.grey[300],
                        child: person['thumbnail'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        person['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 4),
                          const Text('Not seen today'),
                        ],
                      ),
                      trailing: _buildAttendanceActions(person),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAttendanceActions(Map<String, dynamic> person) {
    final controller = Provider.of<UIStateController>(context, listen: false);
    final faceId = person['id'] as String;
    final isExpected = controller.isPersonExpected(faceId);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionChip(
          avatar: Icon(
            isExpected ? Icons.person_remove : Icons.person_add,
            size: 18,
          ),
          label: Text(isExpected ? 'Remove' : 'Add to Expected'),
          onPressed: () async {
            if (isExpected) {
              await controller.unmarkPersonAsExpected(faceId);
            } else {
              await controller.markPersonAsExpected(faceId);
            }
            if (mounted) {
              setState(() {
                // Update UI after toggling expected status
              });
            }
          },
        ),
      ],
    );
  }
}
