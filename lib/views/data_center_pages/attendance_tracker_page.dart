import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:automated_attendance/controllers/ui_state_controller.dart';

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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();

    // Setup periodic refresh
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _loadAttendanceData(),
    );

    // Register for attendance updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<UIStateController>(context, listen: false);
      controller.onAttendanceUpdated = _loadAttendanceData;
    });
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
      setState(() {
        _attendanceData = data;
        _isLoading = false;
      });
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
    final attendanceRate = _attendanceData['attendance_rate'] as int;
    final presentCount = _attendanceData['presentCount'] as int;
    final expectedCount = _attendanceData['expectedCount'] as int;

    return RefreshIndicator(
      onRefresh: _loadAttendanceData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(today, attendanceRate.toString(), presentCount, expectedCount),
            const SizedBox(height: 24),
            _buildAttendanceSummaryCards(present.length, absent.length),
            const SizedBox(height: 24),
            _buildPresentSection(present),
            const SizedBox(height: 24),
            _buildAbsentSection(absent),
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

  Widget _buildAttendanceSummaryCards(int presentCount, int absentCount) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Present',
            presentCount.toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Absent',
            absentCount.toString(),
            Icons.cancel,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String count, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              count,
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
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text('Arrived at $arrivalTime'),
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
