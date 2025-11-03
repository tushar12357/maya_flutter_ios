import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:Maya/core/network/api_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import 'package:Maya/core/services/notification_service.dart';
import 'package:Maya/core/services/contact_service.dart';

// ---------------------------------------------------------------------------
// TaskDetail model (unchanged)
// ---------------------------------------------------------------------------
class TaskDetail {
  final String id;
  final String query;
  final String status;
  final String error;
  final String timestamp;

  TaskDetail({
    required this.id,
    required this.query,
    required this.status,
    required this.error,
    required this.timestamp,
  });

  factory TaskDetail.fromJson(Map<String, dynamic> json) {
    final toolCall = json['current_tool_call'] as Map<String, dynamic>? ?? {};
    final status =
        toolCall['status']?.toString() ?? json['status']?.toString() ?? '';
    final success =
        json['success'] as bool? ?? toolCall['success'] as bool? ?? false;
    final error =
        json['error']?.toString() ?? toolCall['error']?.toString() ?? '';
    String formattedTimestamp = 'No timestamp';
    try {
      final createdAt = DateTime.parse(json['created_at']?.toString() ?? '');
      formattedTimestamp = DateFormat('MMM dd, yyyy HH:mm').format(createdAt);
    } catch (_) {}
    return TaskDetail(
      id: json['id']?.toString() ?? 'Unknown',
      query:
          json['user_payload']?['task']?.toString() ??
          json['query']?.toString() ??
          'No query',
      status: status.isNotEmpty
          ? status
          : (success ? 'completed' : (error.isNotEmpty ? 'failed' : 'pending')),
      error: error.isNotEmpty ? error : 'None',
      timestamp: formattedTimestamp,
    );
  }
}

// ---------------------------------------------------------------------------
// HomePage
// ---------------------------------------------------------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // -----------------------------------------------------------------------
  // State
  // -----------------------------------------------------------------------
  List<Map<String, dynamic>> todos = [];
  List<Map<String, dynamic>> reminders = [];
  List<TaskDetail> tasks = [];

  bool isLoadingTodos = false;
  bool isLoadingReminders = false;
  bool isLoadingTasks = false;

  final NotificationServices _notification = NotificationServices();
  late final ApiClient _apiClient;

  String? _fcmToken;
  String? _locationStatus;
  String? _userFirstName;
  String? _userLastName;

  // -----------------------------------------------------------------------
  // initState – wiring only
  // -----------------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    final publicDio = Dio();
    final protectedDio = Dio();
    _apiClient = ApiClient(publicDio, protectedDio);

    _setupNotifications();
    _syncUserProfile();
    _initializeAndSyncContacts();
    fetchReminders();
    fetchToDos();
    fetchTasks();
  }

  // -----------------------------------------------------------------------
  // 1. Notification plumbing
  // -----------------------------------------------------------------------
  Future<void> _setupNotifications() async {
    _notification.requestNotificationPermission();
    _notification.forgroundMessage();
    _notification.firebaseInit(context);
    _notification.setupInteractMessage(context);
    _notification.isTokenRefresh();

    final token = await _notification.getDeviceToken();
    setState(() => _fcmToken = token);
  }

  // -----------------------------------------------------------------------
  // 2. Centralised profile sync (FCM + location + timezone)
  // -----------------------------------------------------------------------
  Future<void> _syncUserProfile() async {
    try {
      final userResp = await _apiClient.getCurrentUser();
      if (userResp['statusCode'] != 200) {
        _showSnack('User fetch failed: ${userResp['data']}');
        return;
      }
      final userData = userResp['data'] as Map<String, dynamic>;
      final String firstName = userData['first_name']?.toString() ?? '';
      final String lastName = userData['last_name']?.toString() ?? '';
      setState(() {
        _userFirstName = firstName;
        _userLastName = lastName;
      });

      final results = await Future.wait([
        _waitForFcmToken(),
        _obtainLocationAndTimezone(),
      ]);

      final String? token = results[0] as String?;
      final (Position position, String timezone) =
          results[1] as (Position, String);

      if (token == null) {
        _showSnack('FCM token missing – aborting profile sync');
        return;
      }

      final updateResp = await _apiClient.updateUserProfile(
        firstName: firstName,
        lastName: lastName,
        fcmToken: token,
        latitude: position.latitude,
        longitude: position.longitude,
        timezone: timezone,
      );

      if (updateResp['statusCode'] == 200) {
        _showSnack('Profile synced successfully');
      } else {
        _showSnack('Profile sync failed: ${updateResp['data']}');
      }
    } catch (e) {
      _showSnack('Sync error: $e');
    }
  }

  // -----------------------------------------------------------------------
  // Helper: wait max 5 s for FCM token
  // -----------------------------------------------------------------------
  Future<String?> _waitForFcmToken() async {
    final completer = Completer<String?>();
    const timeout = Duration(seconds: 5);
    Timer? timer;

    void check() {
      if (_fcmToken != null) {
        timer?.cancel();
        completer.complete(_fcmToken);
      }
    }

    timer = Timer.periodic(const Duration(milliseconds: 200), (_) => check());
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        timer?.cancel();
        completer.complete(null);
      }
    });
    check();
    return completer.future;
  }

  // -----------------------------------------------------------------------
  // Helper: location + timezone (with UI dialogs)
  // -----------------------------------------------------------------------
 Future<(Position, String)> _obtainLocationAndTimezone() async {
final TimezoneInfo timezoneInfo = await FlutterTimezone.getLocalTimezone();
  final String timezone = timezoneInfo.identifier;
  // 1. Check if location service is enabled
  final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    _showLocationServiceDialog();
    throw Exception('Location services are disabled.');
  }

  // 2. Check permission
  LocationPermission permission = await Geolocator.checkPermission();

  // 3. Request only foreground permission
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied) {
      _showLocationPermissionDialog();
      throw Exception('Location permission denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    _showLocationPermissionDialog(permanent: true);
    throw Exception('Location permission permanently denied');
  }

  // 4. We now have `whileInUse` or `always` — but we only need `whileInUse`
  if (permission == LocationPermission.always) {
    // Optional: downgrade to whileInUse if you don't need background
    // Not needed — `always` includes foreground
  }

  // 5. Get location
  try {
    final Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    ).timeout(const Duration(seconds: 15));

    debugPrint('Location obtained: ${position.latitude}, ${position.longitude}');
    setState(() => _locationStatus = 'granted');
    return (position, timezone);
  } on TimeoutException {
    throw Exception('Location request timed out');
  } on PermissionDeniedException {
    throw Exception('Location permission denied');
  } on LocationServiceDisabledException {
    throw Exception('Location service disabled');
  }
}
  // -----------------------------------------------------------------------
  // UI dialogs
  // -----------------------------------------------------------------------
  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text('Please enable location services to save your location.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationPermissionDialog({bool permanent = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: Text(
          permanent
              ? 'Location permissions are permanently denied. Please enable them in app settings.'
              : 'Location permission is required to save your location.',
        ),
        actions: [
          if (!permanent)
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (permanent) {
                openAppSettings();
              } else {
                Geolocator.requestPermission();
              }
            },
            child: Text(permanent ? 'Open Settings' : 'Grant Permission'),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Contacts sync – skip if empty
  // -----------------------------------------------------------------------
  Future<void> _initializeAndSyncContacts() async {
  final contacts = await ContactsPermissionService.requestAndFetch(context);
  
  if (contacts == null) {
    // User denied → UI already handled by service
    return;
  }

  if (contacts.isEmpty) {
    _showSnack('No contacts to sync');
    return;
  }

  final payload = _apiClient.prepareSyncContactsPayload(contacts);
  final response = await _apiClient.syncContacts(payload);
  
  final msg = response['statusCode'] == 200
      ? 'Contacts synced successfully'
      : 'Failed to sync contacts: ${response['data']}';
  
  _showSnack(msg);
}
  void _showContactsPermissionDialog({bool permanent = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Contacts Permission Required'),
        content: Text(
          permanent
              ? 'Contacts permissions are permanently denied. Please enable them in app settings.'
              : 'Contacts permission is required to sync your contacts.',
        ),
        actions: [
          if (!permanent)
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (permanent) {
                openAppSettings();
              } else {
                _initializeAndSyncContacts();
              }
            },
            child: Text(permanent ? 'Open Settings' : 'Grant Permission'),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Data fetchers
  // -----------------------------------------------------------------------
  Future<void> fetchReminders() async {
    setState(() => isLoadingReminders = true);
    try {
      final response = await _apiClient.getReminders();
      if (response['statusCode'] == 200) {
        setState(() {
          reminders = List<Map<String, dynamic>>.from(response['data']['data']);
        });
      }
    } catch (e) {
      _showSnack('Failed to load reminders');
    } finally {
      setState(() => isLoadingReminders = false);
    }
  }

  Future<void> fetchToDos() async {
    setState(() => isLoadingTodos = true);
    try {
      final response = await _apiClient.getToDo();
      if (response['statusCode'] == 200) {
        setState(() {
          todos = List<Map<String, dynamic>>.from(response['data']['data']);
        });
      }
    } catch (e) {
      _showSnack('Failed to load To-Dos');
    } finally {
      setState(() => isLoadingTodos = false);
    }
  }

  Future<void> fetchTasks() async {
    setState(() => isLoadingTasks = true);
    try {
      final response = await _apiClient.fetchTasks(page: 1);
      final data = response['data'];
      if (response['statusCode'] == 200 && data['success'] == true) {
        final List<dynamic> taskList =
            data['data']?['sessions'] as List<dynamic>? ?? [];
        setState(() {
          tasks = taskList.map((json) => TaskDetail.fromJson(json)).toList();
        });
      }
    } catch (e) {
      _showSnack('Failed to load tasks');
    } finally {
      setState(() => isLoadingTasks = false);
    }
  }

  // -----------------------------------------------------------------------
  // To-Do CRUD helpers
  // -----------------------------------------------------------------------
  Future<void> addToDo(String title, String description, {String? reminder}) async {
    final payload = _apiClient.prepareCreateToDoPayload(title, description, reminder);
    final response = await _apiClient.createToDo(payload);
    if (response['statusCode'] == 200) fetchToDos();
  }

  Future<void> updateToDo(Map<String, dynamic> todo) async {
    final payload = _apiClient.prepareUpdateToDoPayload(
      todo['ID'],
      title: todo['title'],
      description: todo['description'],
      status: todo['status'],
      reminder: todo['reminder'] ?? false,
      reminder_time: todo['reminder_time'],
    );
    final response = await _apiClient.updateToDo(payload);
    if (response['statusCode'] == 200) {
      fetchToDos();
      _showSnack('To-Do updated');
    }
  }

  Future<void> completeToDo(Map<String, dynamic> todo) async {
    setState(() => isLoadingTodos = true);
    try {
      final payload = _apiClient.prepareUpdateToDoPayload(
        todo['ID'],
        title: todo['title'],
        description: todo['description'],
        status: 'completed',
        reminder: todo['reminder'] ?? false,
        reminder_time: todo['reminder_time'],
      );
      final response = await _apiClient.updateToDo(payload);
      if (response['statusCode'] == 200) {
        await fetchToDos();
        _showSnack('To-Do completed');
      }
    } catch (e) {
      _showSnack('Error completing To-Do');
    } finally {
      setState(() => isLoadingTodos = false);
    }
  }

  Future<void> deleteToDo(int id) async {
    final response = await _apiClient.deleteToDo(id);
    if (response['statusCode'] == 200) fetchToDos();
  }

  // -----------------------------------------------------------------------
  // Sync & Copy Helpers
  // -----------------------------------------------------------------------
  void _forceSyncAll() async {
    final snack = SnackBar(content: Text('Syncing...'), duration: Duration(seconds: 5));
    ScaffoldMessenger.of(context).showSnackBar(snack);

    await Future.wait([
      _syncUserProfile(),
      _initializeAndSyncContacts(),
    ]);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _showSnack('Sync completed');
  }

  void copyFcmToken() {
    if (_fcmToken != null) {
      Clipboard.setData(ClipboardData(text: _fcmToken!));
      _showSnack('FCM Token copied!');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.orange),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?\n\nGoRouter will automatically redirect you to the login page.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(LogoutRequested());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 18
            ? 'Good Afternoon'
            : 'Good Evening';

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final displayName = _userFirstName?.isNotEmpty == true
            ? _userFirstName!
            : (state is AuthAuthenticated ? state.user?.firstName ?? 'User' : 'User');

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFDBEAFE),
                  Color(0xFFF3E8FF),
                  Color(0xFFFCE7F3),
                ],
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [Color(0x66BFDBFE), Colors.transparent],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        '$greeting, $displayName',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Here's what's happening today",
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),

                      // Sync Button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _forceSyncAll,
                          icon: const Icon(Icons.sync),
                          label: const Text('Sync Profile & Contacts'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // FCM Token Display
                      if (_fcmToken != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.vpn_key, size: 20, color: Colors.deepPurple),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  _fcmToken!,
                                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                tooltip: 'Copy FCM Token',
                                onPressed: copyFcmToken,
                              ),
                            ],
                          ),
                        ),
                      if (_fcmToken != null) const SizedBox(height: 24),

                      // Recent Activity
                      _buildSection(
                        title: 'Recent Activity',
                        icon: LucideIcons.clock,
                        color: Colors.purple,
                        children: [
                          _buildActivityItem({
                            'type': 'success',
                            'action': 'Completed task',
                            'detail': 'Update website design',
                            'time': '5h ago',
                          }),
                          _buildActivityItem({
                            'type': 'info',
                            'action': 'New task assigned',
                            'detail': 'Prepare quarterly report',
                            'time': '3h ago',
                          }),
                          _buildActivityItem({
                            'type': 'error',
                            'action': 'Task failed',
                            'detail': 'Book meeting with client',
                            'time': '1d ago',
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Active Tasks
                      _buildSection(
                        title: 'Active Tasks',
                        icon: LucideIcons.zap,
                        color: Colors.blue,
                        children: isLoadingTasks
                            ? [const Center(child: CircularProgressIndicator())]
                            : tasks.isEmpty
                                ? [const Text('No active tasks', style: TextStyle(color: Colors.grey))]
                                : tasks.take(3).map(_buildTaskItem).toList(),
                        trailing: TextButton(
                          onPressed: () => context.go('/tasks'),
                          child: const Text('View All', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Upcoming
                      _buildSection(
                        title: 'Upcoming',
                        icon: LucideIcons.calendar,
                        color: Colors.amber,
                        children: isLoadingReminders
                            ? [const Center(child: CircularProgressIndicator())]
                            : reminders.isEmpty
                                ? [const Text('No upcoming reminders', style: TextStyle(color: Colors.grey))]
                                : reminders.take(3).map(_buildReminderItem).toList(),
                        trailing: TextButton(
                          onPressed: () => context.go('/todos'),
                          child: const Text('View All', style: TextStyle(color: Colors.amber)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // To-Do
                      _buildSection(
                        title: 'To-Do',
                        icon: LucideIcons.checkSquare,
                        color: Colors.green,
                        children: isLoadingTodos
                            ? [const Center(child: CircularProgressIndicator())]
                            : todos.isEmpty
                                ? [const Text('No to-dos available', style: TextStyle(color: Colors.grey))]
                                : todos.take(3).map(_buildToDoItem).toList(),
                        trailing: TextButton(
                          onPressed: () => context.go('/reminders'),
                          child: const Text('View All', style: TextStyle(color: Colors.green)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // UI helpers
  // -----------------------------------------------------------------------
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Icon(icon, size: 20, color: color),
                    ),
                    const SizedBox(width: 12),
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final dotColor = activity['type'] == 'success'
        ? Colors.green
        : activity['type'] == 'error'
            ? Colors.red
            : Colors.blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${activity['action']} - ${activity['detail']}', style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
          Text(activity['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTaskItem(TaskDetail task) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (task.status.toLowerCase()) {
      case 'succeeded':
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'Completed';
        statusIcon = LucideIcons.checkCircle2;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusLabel = 'Failed';
        statusIcon = LucideIcons.xCircle;
        break;
      case 'approval_pending':
        statusColor = Colors.blue;
        statusLabel = 'Needs Approval';
        statusIcon = LucideIcons.alertCircle;
        break;
      default:
        statusColor = Colors.amber;
        statusLabel = 'In Progress';
        statusIcon = LucideIcons.clock;
    }

    return GestureDetector(
      onTap: () => context.go('/tasks/${task.id}', extra: {'query': task.query}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.35)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.zap, size: 16, color: Colors.blue.withOpacity(0.8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.query.isNotEmpty ? task.query : 'No query provided',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: statusColor)),
                    ],
                  ),
                ),
                Text(task.timestamp, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            if (task.error != 'None') ...[
              const SizedBox(height: 8),
              Text('Error: ${task.error}', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w400), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReminderItem(Map<String, dynamic> reminder) {
    final utcTime = DateTime.parse(reminder['reminder_time']);
    final localTime = utcTime.toLocal();
    final formattedTime = DateFormat('MMM d, yyyy h:mm a').format(localTime);
    return GestureDetector(
      onTap: () => context.go('/other'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reminder['title'] ?? 'Reminder', style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(formattedTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToDoItem(Map<String, dynamic> todo) {
    return GestureDetector(
      onTap: todo['status'] == 'completed' ? null : () => completeToDo(todo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: todo['status'] == 'completed' ? null : () => completeToDo(todo),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: todo['status'] == 'completed' ? Colors.green : Colors.grey, width: 2),
                  borderRadius: BorderRadius.circular(4),
                  color: todo['status'] == 'completed' ? Colors.green.withOpacity(0.2) : Colors.transparent,
                ),
                child: todo['status'] == 'completed'
                    ? const Icon(LucideIcons.checkCircle2, size: 14, color: Colors.green)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                todo['title'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  decoration: todo['status'] == 'completed' ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: Colors.grey,
                ),
              ),
            ),
            if (todo['status'] != 'completed' && todo['priority'] == 'high')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Text('High', style: TextStyle(fontSize: 12, color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}