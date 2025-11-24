import 'dart:ui';
import 'package:Maya/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:Maya/core/constants/colors.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<Map<String, dynamic>> reminders = [];
  bool isLoading = false;
  final ScrollController _scrollController = ScrollController();
  DateTime selectedDate = DateTime.now();

  // Timeline settings
  static const double pixelsPerHour = 160.0;
  static const double pixelsPerMinute = pixelsPerHour / 60.0;
  static const double cardHeight = 68.0;
  static const double fullDayHeight = 24 * pixelsPerHour;

  @override
  void initState() {
    super.initState();
    _fetchRemindersForDate();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchRemindersForDate() async {
    setState(() => isLoading = true);
    try {
      final response = await GetIt.I<ApiClient>().getReminders(
        startDate: selectedDate,
        endDate: selectedDate,
      );

      if (response['success'] == true) {
        final raw = (response['data'] as Map<String, dynamic>?)?['data'] as List<dynamic>? ?? [];
        final fetched = raw.cast<Map<String, dynamic>>();
        fetched.sort((a, b) => DateTime.parse(a['reminder_time']).compareTo(DateTime.parse(b['reminder_time'])));
        setState(() => reminders = fetched);
      }
    } catch (e) {
      debugPrint('Error fetching reminders: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  DateTime _getWeekStart(DateTime d) => d.subtract(Duration(days: d.weekday % 7));

  void _previousWeek() {
    setState(() => selectedDate = selectedDate.subtract(const Duration(days: 7)));
    _fetchRemindersForDate();
  }

  void _nextWeek() {
    setState(() => selectedDate = selectedDate.add(const Duration(days: 7)));
    _fetchRemindersForDate();
  }

  List<Widget> _buildReminderCards() {
    const double timelineLeft = 70.0;
    final double availableWidth = MediaQuery.of(context).size.width - timelineLeft - 40;

    final Map<int, List<_ReminderBlock>> groups = {};
    for (var r in reminders) {
      final dt = DateTime.parse(r['reminder_time']).toLocal();
      final totalMinutes = dt.hour * 60 + dt.minute;
      final block = _ReminderBlock(
        reminder: r,
        totalMinutes: totalMinutes,
        isPast: dt.isBefore(DateTime.now()),
        timeText: DateFormat('h:mm a').format(dt),
      );
      groups.putIfAbsent(totalMinutes, () => []).add(block);
    }

    final List<Widget> cards = [];
    groups.forEach((minute, list) {
      final double top = minute * pixelsPerMinute - (cardHeight / 2);
      final int count = list.length;
      final double cardWidth = (availableWidth / count) - 10;

      for (int i = 0; i < list.length; i++) {
        final block = list[i];
        final double left = timelineLeft + 16 + (i * (cardWidth + 10));

        cards.add(
          Positioned(
            top: top,
            left: left,
            height: cardHeight,
            width: cardWidth,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.whiteClr,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _showReminderDetail(block.reminder),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: block.isPast ? Colors.grey.shade400 : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            block.reminder['title'] ?? 'Reminder',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          block.timeText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    });

    return cards;
  }

  void _showReminderDetail(Map<String, dynamic> reminder) {
    final dt = DateTime.parse(reminder['reminder_time']).toLocal();
    final isPast = dt.isBefore(DateTime.now());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.whiteClr,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.greyColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(LucideIcons.bell, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      reminder['title'] ?? 'Reminder',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                reminder['description'] ?? 'No description provided.',
                style: const TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.calendar, color: AppColors.primary, size: 22),
                    const SizedBox(width: 14),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(dt),
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              if (isPast)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    "This reminder has passed",
                    style: TextStyle(color: AppColors.redColor, fontStyle: FontStyle.italic, fontSize: 15),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = _getWeekStart(selectedDate);
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final headerDate = DateFormat('EEEE, d MMMM yyyy').format(selectedDate);

    return Scaffold(
      backgroundColor: AppColors.bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteClr,
        elevation: 0,
        leading: InkWell(
          onTap: () => context.go('/other'),
          child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("Reminders", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            Text("Manage all reminders", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(headerDate, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.whiteClr,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 22),
                ),
              ],
            ),
          ),

          // Week Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final day = weekDays[index];
                final isSelected = day.year == selectedDate.year && day.month == selectedDate.month && day.day == selectedDate.day;

                return GestureDetector(
                  onTap: () {
                    if (!isSelected) {
                      setState(() => selectedDate = day);
                      _fetchRemindersForDate();
                    }
                  },
                  child: Column(
                    children: [
                      Text(
                        dayNames[index],
                        style: TextStyle(
                          color: isSelected ? AppColors.secondary : Colors.black54,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.secondary.withOpacity(0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppColors.secondary : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 16),

          // Timeline Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.whiteClr,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : reminders.isEmpty
                        ? Center(
                            child: Text("No reminders today", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                          )
                        : SingleChildScrollView(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            child: SizedBox(
                              height: fullDayHeight,
                              child: Stack(
                                children: [
                                  // Hour Labels
                                  ...List.generate(25, (h) {
                                    final top = h * pixelsPerHour;
                                    final label = h == 0
                                        ? '12 AM'
                                        : h == 12
                                            ? '12 PM'
                                            : h > 12
                                                ? '${h - 12} PM'
                                                : '$h AM';
                                    return Positioned(
                                      top: top + 12,
                                      left: 16,
                                      child: Text(label, style: TextStyle(fontSize: 12, color: Colors.black54)),
                                    );
                                  }),
                                  // Vertical Timeline Line
                                  Positioned(
                                    left: 64,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(width: 3, color: AppColors.primary),
                                  ),
                                  // Horizontal Lines
                                  ...List.generate(24, (h) => Positioned(
                                        top: h * pixelsPerHour,
                                        left: 70,
                                        right: 0,
                                        child: Container(height: 0.5, color: AppColors.borderColor),
                                      )),
                                  // Reminder Cards
                                  ..._buildReminderCards(),
                                ],
                              ),
                            ),
                          ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ReminderBlock {
  final Map<String, dynamic> reminder;
  final int totalMinutes;
  final bool isPast;
  final String timeText;

  _ReminderBlock({
    required this.reminder,
    required this.totalMinutes,
    required this.isPast,
    required this.timeText,
  });
}

extension DateTimeExtension on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
}