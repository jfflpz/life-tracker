import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/network/api_client.dart';
import '../../models/monthly_summary.dart';
import 'activity_marker.dart';
import 'monthly_summary_card.dart';

class CalendarModal extends StatefulWidget {
  final DateTime initialDate;

  const CalendarModal({super.key, required this.initialDate});

  static Future<DateTime?> show(BuildContext context, {required DateTime initialDate}) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CalendarModal(initialDate: initialDate),
    );
  }

  @override
  State<CalendarModal> createState() => _CalendarModalState();
}

class _CalendarModalState extends State<CalendarModal> {
  final ApiClient _apiClient = ApiClient();
  
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  
  MonthlySummary? _monthlySummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate;
    _selectedDay = widget.initialDate;
    _fetchSummaryForMonth(_focusedDay);
  }

  Future<void> _fetchSummaryForMonth(DateTime month) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final summary = await _apiClient.getMonthlySummary(month.year, month.month);
    
    if (!mounted) return;
    setState(() {
      _monthlySummary = summary;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'History Calendar',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    currentDay: DateTime.now(),
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month',
                    },
                    headerStyle: const HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      Navigator.of(context).pop(selectedDay);
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                      _fetchSummaryForMonth(focusedDay);
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        if (_monthlySummary == null) return null;
                        
                        final dateStr = day.toIso8601String().split('T')[0];
                        
                        // Find if this day has activity
                        ActiveDay? activeDay;
                        for (var ad in _monthlySummary!.activeDays) {
                          if (ad.date == dateStr) {
                            activeDay = ad;
                            break;
                          }
                        }
                        
                        if (activeDay != null) {
                          return Positioned(
                            bottom: 6,
                            child: ActivityMarker(activeDay: activeDay),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: MonthlySummaryCard(
                    stats: _monthlySummary?.summary,
                    isLoading: _isLoading,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
