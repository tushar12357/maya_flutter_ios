import 'package:Maya/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  _RemindersPageState createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<Map<String, dynamic>> reminders = [];
  bool isLoadingReminders = false;
  bool isLoadingMore = false;
  int currentPage = 1;
  bool hasMore = true;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _timelineScrollController = ScrollController();
  String selectedFilter = 'All';

  final List<String> filterOptions = ['All', 'AM', 'PM'];

  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetchReminders();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _timelineScrollController.dispose();
    super.dispose();
  }

  Future<void> fetchReminders({int page = 1}) async {
    if (page == 1) {
      setState(() => isLoadingReminders = true);
    } else {
      setState(() => isLoadingMore = true);
    }

    try {
      print('=== Fetching reminders page $page ===');
      final response = await GetIt.I<ApiClient>().getReminders(page: page);
      
      print('Response success: ${response['success']}');
      print('Response data type: ${response['data'].runtimeType}');
      
      if (response['success']) {
        final newReminders = List<Map<String, dynamic>>.from(response['data']);
        print('New reminders count: ${newReminders.length}');
        
        // Print each reminder for debugging
        for (var reminder in newReminders) {
          print('Reminder: ${reminder['title']} - ${reminder['reminder_time']} - reminded: ${reminder['reminded']}');
        }
        
        setState(() {
          if (page == 1) {
            reminders = newReminders;
            hasMore = newReminders.isNotEmpty;
          } else {
            reminders.addAll(newReminders);
          }
          currentPage = page;
          print('Total reminders after update: ${reminders.length}');
        });
      } else {
        print('API error: ${response['message']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch reminders: ${response['message'] ?? 'Unknown error'}')),
        );
      }
    } catch (e) {
      print('Exception fetching reminders: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching reminders: $e')),
      );
    } finally {
      setState(() {
        isLoadingReminders = false;
        isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMore) {
      fetchReminders(page: currentPage + 1);
    }
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  void _previousWeek() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 7));
    });
  }

  List<Map<String, dynamic>> _getSelectedDateReminders() {
    print('=== Getting reminders for selected date ===');
    print('Selected date: $selectedDate');
    print('Total reminders in list: ${reminders.length}');
    
    final selectedStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    print('Selected date string: $selectedStr');
    
    final filtered = reminders.where((r) {
      try {
        print('\nChecking reminder: ${r['title']}');
        print('Reminder time from API: ${r['reminder_time']}');
        
        // Parse the UTC time from the API
        final reminderTime = DateTime.parse(r['reminder_time']);
        print('Parsed UTC time: $reminderTime');
        
        // Convert to local time for comparison
        final localReminderTime = reminderTime.toLocal();
        print('Local time: $localReminderTime');
        
        final rDateStr = DateFormat('yyyy-MM-dd').format(localReminderTime);
        print('Reminder date string: $rDateStr');
        
        final matches = rDateStr == selectedStr;
        print('Matches selected date: $matches');
        
        return matches;
      } catch (e) {
        print('Error parsing reminder time: $e');
        return false;
      }
    }).toList();
    
    print('\nFiltered reminders count: ${filtered.length}');
    
    filtered.sort((a, b) {
      final timeA = DateTime.parse(a['reminder_time']).toLocal();
      final timeB = DateTime.parse(b['reminder_time']).toLocal();
      return timeA.compareTo(timeB);
    });
    
    return filtered;
  }

  List<Map<String, dynamic>> _getFilteredReminders(List<Map<String, dynamic>> selected) {
    if (selectedFilter == 'All') return selected;
    return selected.where((r) {
      try {
        final reminderTime = DateTime.parse(r['reminder_time']).toLocal();
        final hour = reminderTime.hour;
        if (selectedFilter == 'AM') return hour < 12;
        if (selectedFilter == 'PM') return hour >= 12;
        return true;
      } catch (e) {
        print('Error filtering reminder: $e');
        return false;
      }
    }).toList();
  }

  // Generate time slots for the day (00:00 to 23:00)
  List<String> _generateTimeSlots() {
    List<String> slots = [];
    for (int hour = 0; hour < 24; hour++) {
      slots.add('${hour.toString().padLeft(2, '0')}:00');
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final selectedReminders = _getSelectedDateReminders();
    final displayedReminders = _getFilteredReminders(selectedReminders);

    final weekStart = _getWeekStart(selectedDate);
    List<DateTime> weekDays = [];
    DateTime temp = weekStart;
    for (int i = 0; i < 7; i++) {
      weekDays.add(temp);
      temp = temp.add(const Duration(days: 1));
    }
    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    final dateStr = DateFormat('EEEE, dd MMM yyyy').format(selectedDate);
    final headerText = selectedDate.isToday ? "Today's reminders" : "${DateFormat('MMM dd').format(selectedDate)} reminders";

    final timeSlots = _generateTimeSlots();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2A57E8),
        onPressed: () => context.go('/add-reminder'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          // Background color
          Container(color: const Color(0xFF111827)),
          // Gradient overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x992A57E8), Colors.transparent],
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: isLoadingReminders
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Column(
                    children: [
                      // Custom Header with Back Button
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111827).withOpacity(0.8),
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
                      // Header row
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
                      // Date
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Weekly calendar with navigation
                      Row(
                        children: [
                          IconButton(
                            onPressed: _previousWeek,
                            icon: const Icon(Icons.chevron_left, color: Colors.white),
                          ),
                          Expanded(
                            child: SizedBox(
                              height: 60,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: 7,
                                itemBuilder: (context, index) {
                                  final day = weekDays[index];
                                  final isCurrent = day.year == selectedDate.year &&
                                                    day.month == selectedDate.month &&
                                                    day.day == selectedDate.day;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedDate = day;
                                      });
                                    },
                                    child: Container(
                                      width: 40,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      decoration: BoxDecoration(
                                        color: isCurrent ? const Color(0xFF2A57E8).withOpacity(0.1) : null,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            dayNames[index],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withOpacity(0.7),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${day.day}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                              color: isCurrent ? const Color(0xFF2A57E8) : Colors.white.withOpacity(0.7),
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
                            icon: const Icon(Icons.chevron_right, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Filter row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Text(
                              'Time',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D4A6F).withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedFilter,
                                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                                  style: const TextStyle(color: Colors.white),
                                  dropdownColor: const Color(0xFF2D4A6F),
                                  borderRadius: BorderRadius.circular(12),
                                  items: filterOptions.map((String filter) {
                                    return DropdownMenuItem<String>(
                                      value: filter,
                                      child: Text(filter),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        selectedFilter = newValue;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Timeline View
                      Expanded(
                        child: displayedReminders.isEmpty
                            ? Center(
                                child: Text(
                                  'No reminders for this day',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Time labels column
                                  Container(
                                    width: 60,
                                    child: ListView.builder(
                                      controller: _timelineScrollController,
                                      itemCount: timeSlots.length,
                                      itemBuilder: (context, index) {
                                        final timeSlot = timeSlots[index];
                                        final hour = int.parse(timeSlot.split(':')[0]);
                                        final period = hour < 12 ? 'AM' : 'PM';
                                        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                                        
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
                                      },
                                    ),
                                  ),
                                  // Vertical timeline bar
                                  Container(
                                    width: 3,
                                    height: timeSlots.length * 100.0,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          const Color(0xFF2A57E8).withOpacity(0.8),
                                          const Color(0xFF2A57E8).withOpacity(0.3),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Reminders column
                                  Expanded(
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.only(left: 12, right: 16),
                                      itemCount: displayedReminders.length + (isLoadingMore ? 1 : 0),
                                      itemBuilder: (context, index) {
                                        if (index == displayedReminders.length) {
                                          return const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(16.0),
                                              child: CircularProgressIndicator(color: Color(0xFF2A57E8)),
                                            ),
                                          );
                                        }
                                        
                                        final reminder = displayedReminders[index];
                                        final reminderTime = DateTime.parse(reminder['reminder_time']).toLocal();
                                        final timeStr = DateFormat('h:mm').format(reminderTime);
                                        final periodStr = DateFormat('a').format(reminderTime);
                                        
                                        // Safely check reminded field - treat null and false as not completed
                                        bool completed = false;
                                        if (reminder['reminded'] != null && reminder['reminded'] is bool) {
                                          completed = reminder['reminded'] as bool;
                                        }
                                        
                                        print('Reminder ${reminder['title']}: reminded=${reminder['reminded']}, completed=$completed');
                                        
                                        // Calculate position based on time
                                        final hour = reminderTime.hour;
                                        final minute = reminderTime.minute;
                                        final topPosition = (hour * 100.0) + (minute / 60.0 * 100.0);
                                        
                                        return Container(
                                          margin: EdgeInsets.only(
                                            top: index == 0 ? topPosition : 12,
                                            bottom: 12,
                                          ),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: completed 
                                                ? const Color(0xFF2D4A6F).withOpacity(0.3)
                                                : const Color(0xFF2D4A6F).withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: completed 
                                                  ? Colors.white.withOpacity(0.05)
                                                  : Colors.white.withOpacity(0.1),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // Time badge
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: completed 
                                                          ? Colors.grey.withOpacity(0.2)
                                                          : const Color(0xFF2A57E8).withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      timeStr,
                                                      style: TextStyle(
                                                        color: completed ? Colors.grey : const Color(0xFF2A57E8),
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    periodStr.toUpperCase(),
                                                    style: TextStyle(
                                                      color: completed 
                                                          ? Colors.grey.withOpacity(0.7)
                                                          : const Color(0xFF2A57E8).withOpacity(0.7),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      reminder['title'] ?? 'Untitled Reminder',
                                                      style: TextStyle(
                                                        color: completed ? Colors.grey : Colors.white,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w500,
                                                        decoration: completed 
                                                            ? TextDecoration.lineThrough
                                                            : TextDecoration.none,
                                                        decorationColor: Colors.grey,
                                                        decorationThickness: 2,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (reminder['description'] != null && 
                                                        reminder['description'].toString().isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        reminder['description'],
                                                        style: TextStyle(
                                                          color: completed 
                                                              ? Colors.grey.withOpacity(0.7)
                                                              : Colors.white.withOpacity(0.7),
                                                          fontSize: 13,
                                                          decoration: completed 
                                                              ? TextDecoration.lineThrough
                                                              : TextDecoration.none,
                                                          decorationColor: Colors.grey,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(
                                                Icons.shopping_bag_outlined,
                                                color: completed 
                                                    ? Colors.grey.withOpacity(0.5)
                                                    : Colors.white.withOpacity(0.7),
                                                size: 24,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
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

extension DateTimeExtension on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
}