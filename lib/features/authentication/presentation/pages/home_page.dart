import 'dart:async';
import 'dart:ui';
import 'package:Maya/core/constants/colors.dart';
import 'package:Maya/core/network/query_client.dart';
import 'package:Maya/core/services/thunder_service.dart';
import 'package:Maya/features/widgets/voice_chat_card_interactive.dart';
import 'package:Maya/utils/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:Maya/core/network/api_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultravox_client/ultravox_client.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import 'package:Maya/core/services/notification_service.dart';
import 'package:Maya/core/services/contact_service.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';// ---------------------------------------------------------------------------
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
  String? _userProfileImageUrl;
StreamSubscription<Position>? _locationSubscription;
Position? _lastSentPosition;
bool _isSendingLocation = false;
final SharedPreferences _prefs = getIt<SharedPreferences>();
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
bool alreadySynced = _prefs.getBool('contacts_synced_once') ?? false;

if (!alreadySynced) {
  _initializeAndSyncContacts();
}      Future.wait([
  fetchReminders(),
  fetchToDos(),
  fetchTasks(),
]);
    _startLiveLocationTracking();

  }

  @override
void dispose() {
  _locationSubscription?.cancel();
  super.dispose();
}



void _startLiveLocationTracking() async {
  // Ensure permissions first
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return; // You already handle dialogs elsewhere
  }

  _locationSubscription = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // meters — triggers on slight movement
    ),
  ).listen((Position newPos) async {
    // If it's the first reading
    if (_lastSentPosition == null) {
      _lastSentPosition = newPos;
      await _sendLocationUpdate(newPos);
      return;
    }

    // Check if changed even slightly (>= 5 meters)
    final distance = Geolocator.distanceBetween(
      _lastSentPosition!.latitude,
      _lastSentPosition!.longitude,
      newPos.latitude,
      newPos.longitude,
    );

    if (distance >= 5) {
      _lastSentPosition = newPos;
      await _sendLocationUpdate(newPos);
    }
  });
}


Future<void> _sendLocationUpdate(Position pos) async {
  if (_isSendingLocation) return;
  _isSendingLocation = true;

  try {
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    final country = _getUserCountry();

    final payload = {
      "latitude": pos.latitude,
      "longitude": pos.longitude,
      "timezone": timezoneInfo.identifier,
      "country": country,
    };

await _apiClient.updateUserProfile(
  
  // dynamic fields:
  latitude: pos.latitude,
  longitude: pos.longitude,
  timezone: timezoneInfo.identifier,
  country: country,
);
    debugPrint("📍 Live location updated: $payload");

  } catch (e) {
    debugPrint("Live location update error: $e");
  } finally {
    _isSendingLocation = false;
  }
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


String _getUserCountry() {
  final locale = PlatformDispatcher.instance.locale;
  return locale.countryCode ?? 'Unknown';
}

  // -----------------------------------------------------------------------
  // 2. Centralised profile sync (FCM + location + timezone)
  // -----------------------------------------------------------------------
 Future<void> _syncUserProfile() async {
    try {
      final userResp = await _apiClient.getCurrentUser();
      if (userResp['statusCode'] != 200) {
        _showSnack('User fetch failed: ${userResp['data']['message']}');
        return;
      }

      final userData = userResp['data'] as Map<String, dynamic>;
      final String firstName = userData['first_name']?.toString() ?? '';
      final String lastName = userData['last_name']?.toString() ?? '';
      final String phoneNumber = userData['phone_number']?.toString() ?? '';
      final String profileImageUrl = userData['profile_image_url']?.toString() ?? '';
final userCountry = _getUserCountry();

      setState(() {
        _userFirstName = firstName;
        _userLastName = lastName;
        _userProfileImageUrl = profileImageUrl;
      });

      // Wait for FCM + Location/Timezone
      final String? token = await _waitForFcmToken();
      if (token != null) {
        await _apiClient.updateUserProfile(fcmToken: token);
        debugPrint("🔥 FCM synced immediately");
 } else {
        debugPrint("⚠️ FCM token missing");
      }

      // 2️⃣ Location is OPTIONAL and non-blocking
      (Position, String)? locData;
      try {
        locData = await _obtainLocationAndTimezone();
      } catch (_) {
        debugPrint("⛔ Location not available, skipping");
      }

      if (locData != null) {
        final (Position position, String timezone) = locData;
        await _apiClient.updateUserProfile(
          latitude: position.latitude,
          longitude: position.longitude,
          timezone: timezone,
          country: userCountry,
        );
      }
    } catch (e) {
      debugPrint('Sync error: $e');
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

    // 4. Get location
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
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text('Please enable location services to save your location.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
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
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: Text(
          permanent
              ? 'Location permissions are permanently denied. Please enable them in app settings.'
              : 'Location permission is required to save your location.',
        ),
        actions: [
          if (!permanent)
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
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
        : 'Failed to sync contacts: ${response['data']['message']}';
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
      final response = await _apiClient.getRemindersHome(); // no params → latest
      if (response['success'] == true) {
        final List<dynamic> data = response['data']['data'] as List<dynamic>;
        setState(() {
          reminders = data
              .cast<Map<String, dynamic>>()
              .take(3) // only top 3
              .toList();
        });
      } else {
        _showSnack('Failed to load reminders');
      }
    } catch (e) {
      debugPrint('fetchReminders error: $e');
      _showSnack('Failed to load reminders');
    } finally {
      setState(() => isLoadingReminders = false);
    }
  }


  Future<void> fetchToDos() async {
    setState(() => isLoadingTodos = true);
    try {
      final response = await _apiClient.getToDoHome();
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
      final response = await _apiClient.fetchTasksHome();
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

  // Pull-to-refresh method
  Future<void> _onRefresh() async {
    await Future.wait([
      fetchReminders(),
      fetchToDos(),
      fetchTasks(),
    ]);
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

static const double navBarMarginBottom = 12.0;
  static const double navBarHeight = 80.0;
  static const double curveSpace = 70.0;
  final double totalNavBarHeight = navBarHeight + navBarMarginBottom;

   @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final displayName = _userFirstName?.isNotEmpty == true
            ? _userFirstName!
            : (state is AuthAuthenticated
                  ? state.user.firstName ?? 'User'
                  : 'User');

        return Scaffold(
          extendBody: true,
          backgroundColor: AppColors.bgColor,
          body: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    // PROFILE HEADER
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Image
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: _userProfileImageUrl != null && _userProfileImageUrl!.isNotEmpty
                                  ? Image.network(
                                _userProfileImageUrl!,
                                fit: BoxFit.cover,
                                width: 70,
                                height: 70,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    "assets/maya_logo.png",
                                    fit: BoxFit.cover,
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  );
                                },
                              )
                                  : Image.asset(
                                "assets/maya_logo.png",
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          const SizedBox(height: 5),

                          // Text Section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, $displayName!',
                                style:  TextStyle(
                                  color: Color(0xff374957),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Let's explore the way in which \nI can assist you.",
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  color: AppColors.textClr,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ORANGE VOICE CHAT CARD
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: VoiceChatCard(),
                    ),
                    const SizedBox(height: 10),

                    // ACTIVE TASKS
                    _buildSectionHeader(
                      'Active Tasks',
                      () => context.go('/tasks'),
                    ),
                    if (isLoadingTasks)
                      ...List.generate(3, (_) => const TaskCardSkeleton())
                    else if (tasks.isEmpty)
                      _buildEmptySection('No active tasks')
                    else
                      ...tasks
                          .take(3)
                          .map((task) => _buildActiveTaskCard(task)),

                    // REMINDERS
                    // REMINDERS
                    _buildSectionHeader(
                      'Reminders',
                      () => context.push('/reminders'),
                    ),
                    if (isLoadingReminders)
                      ...List.generate(3, (_) => const ReminderCardSkeleton())
                    else if (reminders.isEmpty)
                      _buildEmptySection('No reminders')
                    else
                      ...reminders.map(
                        (r) => _buildReminderCard(r),
                      ), // ← FIXED: added (
                    // TO-DO
                    _buildSectionHeader('To-Do', () => context.push('/todos')),
                    if (isLoadingTodos)
                      ...List.generate(3, (_) => const TodoCardSkeleton())
                    else if (todos.isEmpty)
                      _buildEmptySection('No to-dos')
                    else
                      ...todos.take(3).map((todo) => Padding(
                        padding: const EdgeInsets.only(left: 10, right: 10),
                        child: Container(
                          height: 120,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(0)),

                            child: _buildTodoCard(todo)),
                      )),

                    const SizedBox(height: 120),
                  ],
                ),
              ),

              // ORANGE-THEMED BOTTOM BAR
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.balckClr,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextButton(
            onPressed: onPressed,
            child: Text(
              'View all',
              style: TextStyle(color: Color(0xff6D6D6D), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(16),
          // border: Border.all(color: AppColors.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.0),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTaskCard(TaskDetail task) {
    Color statusColor;
    String statusText;
    switch (task.status.toLowerCase()) {
      case 'succeeded':
      case 'completed':
        statusColor = Colors.green.shade600;
        statusText = 'Completed';
        break;
      case 'failed':
        statusColor = AppColors.redColor;
        statusText = 'Failed';
        break;
      case 'approval_pending':
      case 'in_progress':
        statusColor = AppColors.primary; // Orange for in progress
        statusText = 'In Progress';
        break;
      default:
        statusColor = Colors.orange.shade700;
        statusText = 'Pending';
    }
    return TaskCard(
      title: task.query.isEmpty ? 'Untitled Task' : task.query,
      date: task.timestamp,
      status: statusText,
      color: statusColor,
      onTap: () =>
          context.go('/tasks/${task.id}', extra: {'query': task.query}),
    );
  }

  Widget _buildTodoCard(Map<String, dynamic> todo) {
    final int progress = switch (todo['progress']) {
      int v => v,
      double v => v.round(),
      String s => int.tryParse(s) ?? 0,
      _ => 0,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: TodoCard(
        title: todo['title'] ?? 'Untitled',
        subtitle: todo['description'] ?? 'No description',
        progress: progress.clamp(0, 100),
        onTap: () => context.go('/todos'),
      ),
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> reminder) {
    return ReminderCard(reminder: reminder, onTap: () => context.go('/reminders'));
  }
}

// ←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←
// EXACT ORIGINAL UI — ZERO CHANGES — BUT NOW WITH ULTRAVOX TEXT CHAT
// ←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←

class VoiceChatCard extends StatefulWidget {
  const VoiceChatCard({super.key});

  @override
  State<VoiceChatCard> createState() => _VoiceChatCardState();
}

class _VoiceChatCardState extends State<VoiceChatCard> {
  final ThunderSessionService _shared = ThunderSessionService();
  final ApiClient _apiClient = GetIt.instance<ApiClient>();

  UltravoxSession? _session;
  final TextEditingController _textController = TextEditingController();

  bool _isConnected = false;
  bool _isConnecting = false;
  String _liveTranscript = ''; // ← THIS SHOWS WHAT MAYA IS CURRENTLY SAYING

  @override
  void initState() {
    super.initState();
    _shared.init();
    _session = _shared.session;
    _isConnected = _shared.isSessionActive;
    _liveTranscript = _shared.currentTranscript;
    _setupListeners();
  }

  void _setupListeners() {
    _session?.statusNotifier.addListener(_onStatusChange);
    _session?.dataMessageNotifier.addListener(_onDataMessage);
    _session?.experimentalMessageNotifier.addListener(_onDebugMessage);
  }

  void _removeListeners() {
    try {
      _session?.statusNotifier.removeListener(_onStatusChange);
      _session?.dataMessageNotifier.removeListener(_onDataMessage);
      _session?.experimentalMessageNotifier.removeListener(_onDebugMessage);
    } catch (_) {}
  }

  void _onStatusChange() {
    final active = _shared.isSessionActive;
    if (_isConnected != active) {
      setState(() => _isConnected = active);
    }
  }

  void _onDataMessage() {
    if (!mounted || _session == null) return;

    final transcripts = _session!.transcripts;
    if (transcripts.isEmpty) return;

    final latest = transcripts.last;
    final text = latest.text.trim();

    // Real-time partial transcript (Maya typing)
    if (!latest.isFinal && latest.speaker == Role.agent) {
      setState(() {
        _liveTranscript = text;
        _shared.currentTranscript = text;
      });
      return;
    }

    // Final message from Maya → clear live transcript
    if (latest.isFinal && latest.speaker == Role.agent && text.isNotEmpty) {
      setState(() {
        _liveTranscript = '';
        _shared.currentTranscript = '';
      });
    }
  }

  void _onDebugMessage() {
    final msg = _session?.experimentalMessageNotifier.value;
    if (msg is Map<String, dynamic> && msg.toString().contains('hangUp')) {
      _shared.resetSession();
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _liveTranscript = '';
      });
    }
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      await _shared.resetSession();
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _liveTranscript = '';
      });
      return;
    }

    setState(() => _isConnecting = true);

    try {
      final payload = _apiClient.prepareStartThunderPayload('main');
      final res = await _apiClient.startThunder(payload['agent_type']);

      if (res['statusCode'] != 200) throw Exception("Failed");

      final joinUrl = res['data']['data']['joinUrl'];

      _shared.init();
      _session = _shared.session;
      _removeListeners();
      _setupListeners();

      await _session!.joinCall(joinUrl);

      // FORCE MUTE — 100% GUARANTEED NO AUDIO
      _session!.micMuted = true;
      _session!.speakerMuted = true;
      _session!.micMuted = true; // double tap
      _session!.speakerMuted = true; // double tap
      _shared.isMicMuted = true;
      _shared.isSpeakerMuted = true;

      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
    } catch (e) {
      debugPrint("Connect failed: $e");
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to Maya')),
      );
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty || !_isConnected) return;

    _session?.sendText(text);
    _shared.addMessage('user', text);
    _textController.clear();
  }

  @override
  void dispose() {
    _textController.dispose();
    _removeListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 35,
                width: 35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.3),
                ),
                child: Image.asset(
                  "assets/maya_logo.png",
                  fit: BoxFit.cover,
                )
              ),
              const SizedBox(width: 8),
              const Text(
                'Chat With Maya',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Chat with Maya for quick responses!',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w400,),
          ),
          const SizedBox(height: 16),

          // LIVE TRANSCRIPT BUBBLE (appears when Maya is typing)
          if (_liveTranscript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/maya_logo.png',
                        width: 28,
                        height: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _liveTranscript,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // INPUT + SEND + MIC/END BUTTON
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: _isConnected,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _isConnected
                          ? 'Ask maya...'
                          : 'Tap mic to start',
                      hintStyle: TextStyle(color: Colors.white60),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                // Send Button
                if (_isConnected)
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        // color: Colors.white30,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30,)
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),

                // Mic / End Call Button
                GestureDetector(
                  onTap: _isConnecting ? null : _toggleConnection,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.red : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isConnected ? Icons.call_end : Icons.mic,
                      color: _isConnected ? Colors.white : AppColors.primary,
                      size: 22,
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

class TaskCard extends StatelessWidget {
  final String title;
  final String date;
  final String status;
  final Color color;
  final VoidCallback? onTap;
  const TaskCard({
    super.key,
    required this.title,
    required this.date,
    required this.status,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(13),
        // border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.0),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),  // Light background
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: AppColors.balckClr,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Divider(color: Colors.black26),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.black54, size: 14),
                const SizedBox(width: 4),
                Text(
                  date,
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward,
                  color: Color(0xff374957),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// TodoCard, ReminderCard, Skeletons, FabNotchClipper, CustomBottomAppBar remain unchanged
// (They now use AppColors.primary for accent and are fully orange-themed)

class TodoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int progress;
  final VoidCallback? onTap;
  const TodoCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progressBarColor = progress > 50
        ? AppColors.primary
        : AppColors.redColor;
    return Container(
      margin: const EdgeInsets.only(left: 15, right: 15, bottom: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(13),
        // border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.0),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people,
                  color: AppColors.balckClr,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.balckClr,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            const Divider(color: Colors.black26),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.black54, size: 14),
                const SizedBox(width: 4),
                const Text(
                  'Today',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const Spacer(),
                if (progress > 0)
                  Text(
                    '$progress%',
                    style: TextStyle(
                      color: progressBarColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            if (progress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: AppColors.borderColor,
                  valueColor: AlwaysStoppedAnimation(progressBarColor),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ReminderCard extends StatelessWidget {
  final Map<String, dynamic> reminder;
  final VoidCallback? onTap;
  const ReminderCard({super.key, required this.reminder, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateText = reminder['reminder_time'] != null
        ? DateFormat(
            'MMM dd, yyyy HH:mm',
          ).format(DateTime.parse(reminder['reminder_time']).toLocal())
        : 'No date';
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(13),
        // border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.0),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reminder['title'] ?? 'Reminder',
            style: TextStyle(
              color: AppColors.balckClr,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reminder['description'] ?? 'No description',
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.black26),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.black54, size: 14),
              const SizedBox(width: 4),
              Text(
                dateText,
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

// Skeletons, FabNotchClipper, CustomBottomAppBar – unchanged, fully compatible with orange theme

class TaskCardSkeleton extends StatelessWidget {
  const TaskCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => _skeletonCard();
}

class TodoCardSkeleton extends StatelessWidget {
  const TodoCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => _skeletonCard();
}

class ReminderCardSkeleton extends StatelessWidget {
  const ReminderCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => _skeletonCard();
}

Widget _skeletonCard() {
  return Container(
    margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.cardColor,
      borderRadius: BorderRadius.circular(16),
      // border: Border.all(color: AppColors.borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.0),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 80, height: 12, color: Colors.grey[300]),
          ],
        ),
        const SizedBox(height: 12),
        Container(width: double.infinity, height: 16, color: Colors.grey[300]),
        const SizedBox(height: 8),
        Container(width: 120, height: 12, color: Colors.grey[300]),
      ],
    ),
  );
}

class FabNotchClipper extends CustomClipper<Path> {
  final double notchRadius;
  final double cornerRadius;
  final double fabSize;
  FabNotchClipper({
    required this.notchRadius,
    required this.cornerRadius,
    required this.fabSize,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final center = size.width / 2;
    final halfCutout = fabSize * 0.7;
    path.moveTo(0, cornerRadius);
    path.arcToPoint(
      Offset(cornerRadius, 0),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(center - halfCutout, 0);
    path.cubicTo(
      center - halfCutout * 0.8,
      0,
      center - halfCutout * 0.5,
      -20,
      center,
      -20,
    );
    path.cubicTo(
      center + halfCutout * 0.5,
      -20,
      center + halfCutout * 0.8,
      0,
      center + halfCutout,
      0,
    );
    path.lineTo(size.width - cornerRadius, 0);
    path.arcToPoint(
      Offset(size.width, cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class CustomBottomAppBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final double height;
  final double marginBottom;
  final double curveSpace;
  final Color navBarColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color accentBlue;

  const CustomBottomAppBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.height,
    required this.marginBottom,
    required this.curveSpace,
    required this.navBarColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.accentBlue,
  });

  static const double borderRadius = 28.0;
  static const double fabSize = 65.0;
  static const List<Map<String, dynamic>> items = [
    {'icon': Icons.home, 'label': "Home", 'index': 0},
    {'icon': Icons.list_alt, 'label': "Tasks", 'index': 1},
    {'icon': Icons.menu, 'label': "Setup", 'index': 3},
    {'icon': Icons.more_horiz, 'label': "Others", 'index': 4},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: marginBottom),
      child: ClipPath(
        clipper: FabNotchClipper(
          notchRadius: curveSpace,
          cornerRadius: borderRadius,
          fabSize: fabSize,
        ),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: navBarColor,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 0,
                offset: const Offset(0, -5),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              final index = item['index'] as int;
              final actualIndex = index > 2 ? index - 1 : index;
              if (index == 2) return SizedBox(width: curveSpace);
              final isSelected = selectedIndex == actualIndex;
              final color = isSelected || actualIndex == 0
                  ? accentBlue
                  : secondaryTextColor;
              return GestureDetector(
                onTap: () => onItemSelected(index),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: isSelected && actualIndex != 0
                          ? BoxDecoration(
                              color: accentBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                            )
                          : null,
                      child: Icon(item['icon'], color: color, size: 26),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['label'],
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: isSelected || actualIndex == 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
