import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum FilterTimeRange {
  today,
  yesterday,
  last7Days,
  last30Days,
  thisMonth,
  lastMonth,
  custom
}

class AnalyticsFilters extends StatefulWidget {
  final DateTimeRange dateRange;
  final String? selectedProviderId;
  final String? selectedFaceId;
  final FilterTimeRange selectedTimeRange;
  final List<Map<String, dynamic>> availableFaces;
  final Set<String> availableProviders;
  final Function(DateTimeRange) onDateRangeChanged;
  final Function(String?) onProviderChanged;
  final Function(String?) onFaceChanged;
  final Function(FilterTimeRange) onTimeRangeChanged;

  const AnalyticsFilters({
    super.key,
    required this.dateRange,
    this.selectedProviderId,
    this.selectedFaceId,
    required this.selectedTimeRange,
    required this.availableFaces,
    required this.availableProviders,
    required this.onDateRangeChanged,
    required this.onProviderChanged,
    required this.onFaceChanged,
    required this.onTimeRangeChanged,
  });

  @override
  State<AnalyticsFilters> createState() => _AnalyticsFiltersState();
}

class _AnalyticsFiltersState extends State<AnalyticsFilters> {
  String _searchQuery = '';
  bool _isSearching = false;
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterHeader(),
        if (_showFilters) ...[
          const SizedBox(height: 16),
          _buildTimeRangeSelector(),
          const SizedBox(height: 16),
          _buildDateRangeSelector(),
          const SizedBox(height: 16),
          _buildProviderSelector(),
          const SizedBox(height: 16),
          _buildFaceFilterSection(),
        ],
      ],
    );
  }

  Widget _buildFilterHeader() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showFilters = !_showFilters;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.filter_list,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analytics Filters',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _getActiveFiltersDescription(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              _showFilters
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  String _getActiveFiltersDescription() {
    final List<String> activeFilters = [];

    // Add time range
    activeFilters.add(_getTimeRangeDescription(widget.selectedTimeRange));

    // Add provider if selected
    if (widget.selectedProviderId != null) {
      activeFilters.add('Provider: ${widget.selectedProviderId}');
    }

    // Add face name if selected
    if (widget.selectedFaceId != null) {
      final faceName = _getFaceNameById(widget.selectedFaceId!);
      activeFilters.add('Face: $faceName');
    }

    return activeFilters.join(' • ');
  }

  String _getTimeRangeDescription(FilterTimeRange range) {
    switch (range) {
      case FilterTimeRange.today:
        return 'Today';
      case FilterTimeRange.yesterday:
        return 'Yesterday';
      case FilterTimeRange.last7Days:
        return 'Last 7 Days';
      case FilterTimeRange.last30Days:
        return 'Last 30 Days';
      case FilterTimeRange.thisMonth:
        return 'This Month';
      case FilterTimeRange.lastMonth:
        return 'Last Month';
      case FilterTimeRange.custom:
        return '${DateFormat('MMM dd').format(widget.dateRange.start)} - ${DateFormat('MMM dd').format(widget.dateRange.end)}';
    }
  }

  Widget _buildTimeRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time Range',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTimeRangeChip(FilterTimeRange.today, 'Today'),
              _buildTimeRangeChip(FilterTimeRange.yesterday, 'Yesterday'),
              _buildTimeRangeChip(FilterTimeRange.last7Days, 'Last 7 Days'),
              _buildTimeRangeChip(FilterTimeRange.last30Days, 'Last 30 Days'),
              _buildTimeRangeChip(FilterTimeRange.thisMonth, 'This Month'),
              _buildTimeRangeChip(FilterTimeRange.lastMonth, 'Last Month'),
              _buildTimeRangeChip(FilterTimeRange.custom, 'Custom Range'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangeChip(FilterTimeRange range, String label) {
    final isSelected = widget.selectedTimeRange == range;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (selected) {
          if (selected) {
            // Set the date range based on the selected time range
            final newRange = _getDateRangeFromTimeRange(range);
            widget.onTimeRangeChanged(range);
            widget.onDateRangeChanged(newRange);
          }
        },
      ),
    );
  }

  DateTimeRange _getDateRangeFromTimeRange(FilterTimeRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (range) {
      case FilterTimeRange.today:
        return DateTimeRange(start: today, end: now);

      case FilterTimeRange.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        return DateTimeRange(
            start: yesterday,
            end: yesterday.add(const Duration(days: 1, seconds: -1)));

      case FilterTimeRange.last7Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: now,
        );

      case FilterTimeRange.last30Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: now,
        );

      case FilterTimeRange.thisMonth:
        return DateTimeRange(
          start: DateTime(today.year, today.month, 1),
          end: now,
        );

      case FilterTimeRange.lastMonth:
        final lastMonth = today.month > 1
            ? DateTime(today.year, today.month - 1, 1)
            : DateTime(today.year - 1, 12, 1);

        final lastDayOfMonth = today.month > 1
            ? DateTime(today.year, today.month, 0)
            : DateTime(today.year, 1, 0);

        return DateTimeRange(
          start: lastMonth,
          end: lastDayOfMonth,
        );

      case FilterTimeRange.custom:
        // Keep the current custom range
        return widget.dateRange;
    }
  }

  Widget _buildDateRangeSelector() {
    return Card(
      elevation: 1,
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
                      '${DateFormat('MMM dd, yyyy').format(widget.dateRange.start)} - ${DateFormat('MMM dd, yyyy').format(widget.dateRange.end)}',
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

  Future<void> _selectDateRange() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: widget.dateRange,
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
      widget.onTimeRangeChanged(FilterTimeRange.custom);
      widget.onDateRangeChanged(pickedRange);
    }
  }

  Widget _buildProviderSelector() {
    final providersList = ['All Providers', ...widget.availableProviders];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Camera Provider',
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: widget.selectedProviderId,
              isExpanded: true,
              hint: const Text('All Providers'),
              onChanged: (value) {
                widget
                    .onProviderChanged(value == 'All Providers' ? null : value);
              },
              items: providersList
                  .map((provider) => DropdownMenuItem<String?>(
                        value: provider == 'All Providers' ? null : provider,
                        child: Text(provider),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
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
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
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
              child: const Text('Select'),
            ),
          ],
        ),
        if (widget.selectedFaceId != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Chip(
              label: Text(_getFaceNameById(widget.selectedFaceId!)),
              onDeleted: () {
                widget.onFaceChanged(null);
              },
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
      ],
    );
  }

  String _getFaceNameById(String id) {
    final face = widget.availableFaces.firstWhere(
      (face) => face['id'] == id,
      orElse: () => {'name': 'Unknown'},
    );
    return face['name'] ?? 'Unknown';
  }

  void _showFaceSelectionDialog() {
    final filteredFaces = _searchQuery.isEmpty
        ? widget.availableFaces
        : widget.availableFaces
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
                      leading: face['thumbnail'] != null
                          ? CircleAvatar(
                              backgroundImage: MemoryImage(face['thumbnail']),
                            )
                          : const CircleAvatar(child: Icon(Icons.face)),
                      title: Text(face['name'] ?? 'Unknown'),
                      subtitle: Text('ID: ${face['id'] ?? 'N/A'}'),
                      selected: widget.selectedFaceId == face['id'],
                      onTap: () {
                        widget.onFaceChanged(face['id']);
                        setState(() {
                          _searchQuery = '';
                          _isSearching = false;
                        });
                        Navigator.pop(context);
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
              widget.onFaceChanged(null);
              setState(() {
                _searchQuery = '';
                _isSearching = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear Selection'),
          ),
        ],
      ),
    );
  }
}
