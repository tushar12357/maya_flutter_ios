import 'package:Maya/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  _RemindersPageState createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<Map<String, dynamic>> reminders = [];
  bool isLoading = false;
  final ScrollController _scrollController = ScrollController();
  DateTime selectedDate = DateTime.now();

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

  // -----------------------------------------------------------------
  // Fetch reminders for selectedDate only
  // -----------------------------------------------------------------
  Future<void> _fetchRemindersForDate() async {
    setState(() => isLoading = true);
    try {
      final response = await GetIt.I<ApiClient>().getReminders(
        startDate: selectedDate,
        endDate: selectedDate,
      );

      if (response['success'] == true) {
        final dataMap = response['data'] as Map<String, dynamic>?;
        final List<dynamic> raw = dataMap?['data'] as List<dynamic>? ?? [];
        final List<Map<String, dynamic>> fetched = raw
            .cast<Map<String, dynamic>>();

        // Sort by reminder_time (UTC → local)
        fetched.sort((a, b) {
          final ta = DateTime.parse(a['reminder_time'] as String).toLocal();
          final tb = DateTime.parse(b['reminder_time'] as String).toLocal();
          return ta.compareTo(tb);
        });

        setState(() => reminders = fetched);
      }
    } catch (e) {
      debugPrint('Error fetching reminders: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // -----------------------------------------------------------------
  // Week Navigation
  // -----------------------------------------------------------------
  DateTime _getWeekStart(DateTime date) =>
      date.subtract(Duration(days: date.weekday % 7));

  void _previousWeek() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 7));
    });
    _fetchRemindersForDate();
  }

  void _nextWeek() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 7));
    });
    _fetchRemindersForDate();
  }

  // -----------------------------------------------------------------
  // Timeline Helpers
  // -----------------------------------------------------------------
  List<String> _generateTimeSlots() =>
      List.generate(24, (h) => '${h.toString().padLeft(2, '0')}:00');

  // -----------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final weekStart = _getWeekStart(selectedDate);
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    final dateStr = DateFormat('EEEE, dd MMM yyyy').format(selectedDate);
    final headerText = selectedDate.isToday
        ? "Today's reminders"
        : "${DateFormat('MMM dd').format(selectedDate)} reminders";

    final timeSlots = _generateTimeSlots();
    const double timelineHeight = 24 * 100;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(color: const Color(0xFF111827)),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x992A57E8), Colors.transparent],
              ),
            ),
          ),
          SafeArea(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.push('/other'),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF111827,
                                  ).withOpacity(0.8),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Reminders',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),

                      // Title + Date
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              headerText,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Week Picker
                      Row(
                        children: [
                          IconButton(
                            onPressed: _previousWeek,
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: SizedBox(
                              height: 60,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: 7,
                                itemBuilder: (context, i) {
                                  final day = weekDays[i];
                                  final isCurrent =
                                      day.year == selectedDate.year &&
                                      day.month == selectedDate.month &&
                                      day.day == selectedDate.day;
                                  return GestureDetector(
                                    onTap: () {
                                      if (!isCurrent) {
                                        setState(() => selectedDate = day);
                                        _fetchRemindersForDate();
                                      }
                                    },
                                    child: Container(
                                      width: 40,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isCurrent
                                            ? const Color(
                                                0xFF2A57E8,
                                              ).withOpacity(0.1)
                                            : null,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            dayNames[i],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withOpacity(
                                                0.7,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${day.day}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: isCurrent
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isCurrent
                                                  ? const Color(0xFF2A57E8)
                                                  : Colors.white.withOpacity(
                                                      0.7,
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _nextWeek,
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Timeline
               // Timeline
Expanded(
  child: reminders.isEmpty
      ? const Center(
          child: Text(
            'No reminders for this day',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        )
      : SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            height: timelineHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Labels (scrolls together because inside same scroll view)
                SizedBox(
                  width: 60,
                  child: Column(
                    children: timeSlots.map((slot) {
                      final hour = int.parse(slot.split(':')[0]);
                      final period = hour < 12 ? 'AM' : 'PM';
                      final displayHour =
                          hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                      return Container(
                        height: 100,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 8, top: 4),
                        child: Text(
                          '${displayHour.toString().padLeft(2, '0')}:00\n$period',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.6),
                            height: 1.2,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Vertical Line
                Container(
                  width: 3,
                  height: timelineHeight,
                  color: const Color(0xFF2A57E8),
                ),

                // Reminder cards positioned on timeline
                Expanded(
                  child: Stack(
                    children: reminders.map((reminder) {
                      final reminderTime = DateTime.parse(
                        reminder['reminder_time'],
                      ).toLocal();

                      final hour = reminderTime.hour;
                      final minute = reminderTime.minute;
                      final topPosition =
                          (hour * 100.0) + (minute / 60.0 * 100.0);

                      final isPast = reminderTime.isBefore(DateTime.now());
                      final timeText =
                          DateFormat('h:mm a').format(reminderTime);

                      final dateLabel = reminderTime.isToday
                          ? 'Today'
                          : reminderTime.isTomorrow
                              ? 'Tomorrow'
                              : DateFormat('MMM d').format(reminderTime);

                      final fullDateTime = '$dateLabel, $timeText';

                      return Positioned(
                        top: topPosition,
                        left: 0,
                        right: 0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isPast
                                ? const Color(0xFF2D4A6F).withOpacity(0.4)
                                : const Color(0xFF2D4A6F).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isPast
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title + Bell
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      reminder['title'] ?? 'Reminder',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isPast
                                            ? Colors.white.withOpacity(0.6)
                                            : Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: isPast
                                          ? Colors.grey.withOpacity(0.2)
                                          : const Color(0xFFF59E0B).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      LucideIcons.bell,
                                      size: 14,
                                      color: isPast
                                          ? Colors.grey
                                          : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Description
                              Text(
                                reminder['description'] ?? 'No description',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(
                                      isPast ? 0.4 : 0.6),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),

                              // Time + Actions
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        LucideIcons.clock,
                                        size: 14,
                                        color: Colors.white.withOpacity(
                                            isPast ? 0.3 : 0.5),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        fullDateTime,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(
                                              isPast ? 0.3 : 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        LucideIcons.copy,
                                        size: 16,
                                        color: Colors.white.withOpacity(
                                            isPast ? 0.3 : 0.5),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        LucideIcons.trash2,
                                        size: 16,
                                        color: Colors.white.withOpacity(
                                            isPast ? 0.3 : 0.5),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        LucideIcons.moreVertical,
                                        size: 16,
                                        color: Colors.white.withOpacity(
                                            isPast ? 0.3 : 0.5),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
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

// -----------------------------------------------------------------
// Extensions
// -----------------------------------------------------------------
extension DateTimeExtension on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }
}