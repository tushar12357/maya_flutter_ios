import 'package:Maya/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

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

  // 24 hours = 2400px → 1 hour = 100px → 1 minute = 100/60 = 1.6667px
// NEW — TALLER & MORE SPACIOUS (recommended)
static const double pixelsPerHour = 160.0;        // was 100 → now 60% taller
static const double pixelsPerMinute = pixelsPerHour / 60.0; // auto = 2.666px per minute
static const double cardHeight = 64.0;            // was 48 → now 33% taller
static const double fullDayHeight = 24 * pixelsPerHour; // auto = 3840px (taller day)
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

        fetched.sort((a, b) {
          return DateTime.parse(a['reminder_time'])
              .compareTo(DateTime.parse(b['reminder_time']));
        });

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

  // PERFECT MINUTE-LEVEL MAPPING + AUTO SIDE-BY-SIDE
  List<Widget> _buildReminderCards() {
    final double timelineLeft = 63.0; // 60px labels + 3px blue line
    final double availableWidth = MediaQuery.of(context).size.width - timelineLeft - 20;

    // Group reminders by exact minute
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
      final double exactTop = minute * pixelsPerMinute;
      final double centeredTop = exactTop - (cardHeight / 2);

      final int count = list.length;
      final double cardWidth = (availableWidth / count) - 12;

      for (int i = 0; i < list.length; i++) {
        final block = list[i];
        final double left = timelineLeft + 10 + (i * (cardWidth + 12));

        cards.add(
          Positioned(
            top: centeredTop,
            left: left,
            height: cardHeight,
            width: cardWidth,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _showReminderDetail(block.reminder),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: block.isPast
                          ? [const Color(0xFF2D4A6F), const Color(0xFF1e3a5f)]
                          : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.bell, size: 18, color: Colors.amber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          block.reminder['title'] ?? 'Reminder',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        block.timeText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A2333),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(LucideIcons.bell, color: Colors.amber, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      reminder['title'] ?? 'Reminder',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                reminder['description'] ?? 'No description provided.',
                style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8), height: 1.5),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D4A6F).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.calendar, color: Colors.white70, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(dt),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ),
              if (isPast)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    "This reminder has passed",
                    style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 40),
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
    final headerText = selectedDate.isToday ? "Today's reminders" : DateFormat('MMM dd').format(selectedDate);

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
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                                  color: const Color(0xFF111827).withOpacity(0.8),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Reminders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            const Spacer(),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(headerText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      const SizedBox(height: 20),

                      // Week Picker
                      Row(
                        children: [
                          IconButton(onPressed: _previousWeek, icon: const Icon(Icons.chevron_left, color: Colors.white)),
                          Expanded(
                            child: SizedBox(
                              height: 60,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: 7,
                                itemBuilder: (_, i) {
                                  final day = weekDays[i];
                                  final isCurrent = day.year == selectedDate.year && day.month == selectedDate.month && day.day == selectedDate.day;
                                  return GestureDetector(
                                    onTap: () {
                                      if (!isCurrent) {
                                        setState(() => selectedDate = day);
                                        _fetchRemindersForDate();
                                      }
                                    },
                                    child: Container(
                                      width: 46,
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isCurrent ? const Color(0xFF2A57E8).withOpacity(0.2) : null,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(dayNames[i], style: TextStyle(fontSize: 11, color: Colors.white70)),
                                          const SizedBox(height: 4),
                                          Text('${day.day}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                                color: isCurrent ? const Color(0xFF2A57E8) : Colors.white,
                                              )),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          IconButton(onPressed: _nextWeek, icon: const Icon(Icons.chevron_right, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Timeline — Perfect 1440-minute mapping
                      Expanded(
                        child: reminders.isEmpty
                            ? const Center(child: Text('No reminders today', style: TextStyle(color: Colors.white70, fontSize: 16)))
                            : SingleChildScrollView(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(),
                                child: SizedBox(
                                  height: fullDayHeight,
                                  child: Stack(
                                    children: [
                                      // Hour labels
                                      ...List.generate(25, (h) {
                                        final top = h * pixelsPerHour;
                                        final label = h == 0
                                            ? '12 AM'
                                            : (h == 12
                                                ? '12 PM'
                                                : (h > 12 ? '${h - 12} PM' : '$h AM'));
                                        return Positioned(
                                          top: top,
                                          left: 0,
                                          child: SizedBox(
                                            width: 60,
                                            height: pixelsPerHour,
                                            child: Align(
                                              alignment: Alignment.topRight,
                                              child: Padding(
                                                padding: const EdgeInsets.only(right: 8, top: 4),
                                                child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),

                                      // Blue timeline
                                      Positioned(left: 60, top: 0, bottom: 0, child: Container(width: 3, color: const Color(0xFF2A57E8))),

                                      // Subtle hour lines
                                      ...List.generate(24, (h) => Positioned(
                                            top: h * pixelsPerHour,
                                            left: 63,
                                            right: 0,
                                            child: Container(height: 0.5, color: Colors.white.withOpacity(0.1)),
                                          )),

                                      // ONE-LINE CARDS — PERFECTLY MAPPED
                                      ..._buildReminderCards(),
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