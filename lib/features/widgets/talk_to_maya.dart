import 'dart:async';
import 'dart:ui';
import 'package:Maya/features/widgets/skeleton.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import '../../../authentication/presentation/bloc/auth_bloc.dart';
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
  late SharedPreferences _prefs;
  bool _locationPermissionAsked = false;
  bool _contactsPermissionAsked = false;
  bool isLoadingTodos = false;
  bool isLoadingReminders = false;
  bool isLoadingTasks = false;

  final NotificationServices _notification = NotificationServices();
  late final ApiClient _apiClient;

  String? _fcmToken;
  String? _locationStatus;
  String? _userFirstName;
  String? _userLastName;
  StreamSubscription<Position>? _locationSubscription;
  Position? _lastSentPosition;
  bool _isSendingLocation = false;

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

    _locationSubscription =
        Geolocator.getPositionStream(
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
      final userCountry = _getUserCountry();

      setState(() {
        _userFirstName = firstName;
        _userLastName = lastName;
      });

      // Wait for FCM + Location/Timezone
      final results = await Future.wait([
        _waitForFcmToken(),
        _obtainLocationAndTimezone(),
      ]);

      final String? token = results[0] as String?;
      final (Position position, String timezone) =
          results[1] as (Position, String);

      if (token == null) return;

      // ✅ Only send dynamic fields that can change frequently
      final Map<String, dynamic> payload = {
        "fcm_token": token ?? '',
        "latitude": position.latitude,
        "longitude": position.longitude,
        "timezone": timezone,
        "country": userCountry,
      };
      final updateResp = await _apiClient.updateUserProfile(
        fcmToken: token ?? '',
        latitude: position.latitude,
        longitude: position.longitude,
        timezone: timezone,
        country: userCountry,
      );

      if (updateResp['statusCode'] == 200) {
        _showSnack('Profile synced successfully');
      } else {
        _showSnack('Profile sync failed: ${updateResp['data']['message']}');
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

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!_locationPermissionAsked) {
        _showLocationServiceDialog();
        await _prefs.setBool('location_permission_asked', true);
      }
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied && !_locationPermissionAsked) {
      permission = await Geolocator.requestPermission();
      await _prefs.setBool('location_permission_asked', true);

      if (permission == LocationPermission.denied) {
        _showLocationPermissionDialog();
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!_locationPermissionAsked) {
        _showLocationPermissionDialog(permanent: true);
        await _prefs.setBool('location_permission_asked', true);
      }
      throw Exception('Location permission permanently denied');
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      ).timeout(const Duration(seconds: 15));

      debugPrint(
        'Location obtained: ${position.latitude}, ${position.longitude}',
      );
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
  // Updated location service dialog
  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        // Use dialogContext
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Please enable location services to save your location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // Pop dialogContext
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Pop first
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Updated location permission dialog
  void _showLocationPermissionDialog({bool permanent = false}) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        // Use dialogContext
        title: const Text('Location Permission Required'),
        content: Text(
          permanent
              ? 'Location permissions are permanently denied. Please enable them in app settings.'
              : 'Location permission is required to save your location.',
        ),
        actions: [
          if (!permanent)
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext), // Pop dialogContext
              child: const Text('Cancel'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Pop first
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
  // Updated contacts permission dialog (with recursion guard)
  void _showContactsPermissionDialog({bool permanent = false}) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        // Use dialogContext
        title: const Text('Contacts Permission Required'),
        content: Text(
          permanent
              ? 'Contacts permissions are permanently denied. Please enable them in app settings.'
              : 'Contacts permission is required to sync your contacts.',
        ),
        actions: [
          if (!permanent)
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext), // Pop dialogContext
              child: const Text('Cancel'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Pop first
              if (permanent) {
                openAppSettings();
              } else {
                // Guard against recursion: Check permission before retrying
                Permission.contacts.request().then((status) {
                  if (status.isGranted) {
                    _initializeAndSyncContacts();
                  } else {
                    _showSnack('Permission still denied');
                  }
                });
              }
            },
            child: Text(permanent ? 'Open Settings' : 'Grant Permission'),
          ),
        ],
      ),
    );
  }

  // Updated contacts sync (minor: add explicit permission check if ContactsService doesn't handle it)
  Future<void> _initializeAndSyncContacts() async {
    try {
      final PermissionStatus status = await Permission.contacts.status;

      if (status.isGranted) {
        // Proceed
      } else if (status.isPermanentlyDenied) {
        if (!_contactsPermissionAsked) {
          _showContactsPermissionDialog(permanent: true);
          await _prefs.setBool('contacts_permission_asked', true);
        }
        return;
      } else if (status.isDenied && !_contactsPermissionAsked) {
        _showContactsPermissionDialog();
        await _prefs.setBool('contacts_permission_asked', true);
        return;
      } else {
        return; // Denied before, don't ask
      }

      final contacts = await ContactsService.fetchContactsSafely();
      if (contacts == null || contacts.isEmpty) {
        _showSnack(
          contacts == null ? 'No contacts permission' : 'No contacts to sync',
        );
        return;
      }

      final payload = _apiClient.prepareSyncContactsPayload(contacts);
      final response = await _apiClient.syncContacts(payload);
      final msg = response['statusCode'] == 200
          ? 'Contacts synced successfully'
          : 'Failed to sync contacts: ${response['data']['message']}';
      _showSnack(msg);
    } catch (e) {
      debugPrint('Contacts sync error: $e');
    }
  }

  // -----------------------------------------------------------------------
  // Data fetchers
  // -----------------------------------------------------------------------

  Future<void> fetchReminders() async {
    setState(() => isLoadingReminders = true);
    try {
      final response = await _apiClient.getReminders(); // no params → latest
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
  Future<void> addToDo(
    String title,
    String description, {
    String? reminder,
  }) async {
    final payload = _apiClient.prepareCreateToDoPayload(
      title,
      description,
      reminder,
    );
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
    final snack = SnackBar(
      content: Text('Syncing...'),
      duration: Duration(seconds: 5),
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);

    await Future.wait([_syncUserProfile(), _initializeAndSyncContacts()]);

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------
  @override
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
          body: Stack(
            children: [
              // Background
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

              // Scrollable Content
              SafeArea(
                child: CustomScrollView(
                  slivers: [
                    // === Header Section ===
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile image
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Image.asset(
                                  'assets/maya_logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      LucideIcons.user,
                                      color: Colors.white,
                                      size: 24,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Greeting
                            Text(
                              'Hello, $displayName!',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Let\'s explore the way in which I can\nassist you.',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Blue gradient card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF3B82F6),
                                    Color(0xFF2563EB),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Generate complex algorithms\nand clean code with ease.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: () => context.push('/maya'),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.30),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Start Now',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // === Scrollable Sections ===
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Active Tasks
                          // ---------------------------------------------------------------
                          //  Inside the SliverList delegate (replace the old sections)
                          // ---------------------------------------------------------------

                          // === Active Tasks ===
                          _buildSectionHeader(
                            'Active Tasks',
                            LucideIcons.zap,
                            () => context.push('/tasks'),
                          ),
                          const SizedBox(height: 12),

                          if (isLoadingTasks) ...[
                            // Show 3 skeletons while loading
                            const SkeletonItem(),
                            const SizedBox(height: 12),
                            const SkeletonItem(),
                            const SizedBox(height: 12),
                            const SkeletonItem(),
                          ] else if (tasks.isEmpty)
                            _buildEmptyState('No active tasks')
                          else
                            ...tasks
                                .take(3)
                                .map((task) => _buildTaskCard(task)),

                          const SizedBox(height: 24),

                          // === Reminders ===
                          _buildSectionHeader(
                            'Reminders',
                            LucideIcons.calendar,
                            () => context.push('/reminders'),
                          ),
                          const SizedBox(height: 12),

                          if (isLoadingReminders) ...[
                            const SkeletonItem(),
                            const SizedBox(height: 12),
                            const SkeletonItem(),
                            const SizedBox(height: 12),
                            const SkeletonItem(),
                          ] else if (reminders.isEmpty)
                            _buildEmptyState('No reminders')
                          else
                            ...reminders.map((r) => _buildReminderCard(r)),

                          const SizedBox(height: 24),

                          // === To‑Do ===
                          _buildSectionHeader(
                            'To-Do',
                            LucideIcons.clipboardList,
                            () => context.push('/todos'),
                          ),
                          const SizedBox(height: 12),

                          if (isLoadingTodos) ...[
                            const SkeletonItem(),
                            const SizedBox(height: 12),
                            const SkeletonItem(),
                            const SizedBox(height: 12),
                            const SkeletonItem(),
                          ] else if (todos.isEmpty)
                            _buildEmptyState('No to-dos')
                          else
                            ...todos
                                .take(3)
                                .map((todo) => _buildToDoCard(todo)),

                          const SizedBox(
                            height: 100,
                          ), // Bottom padding // Bottom padding
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  // Solid blue card at the top
  Widget _buildSolidBlueCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A57E8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A57E8).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Good to see you!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have ${tasks.length} active tasks',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.trendingUp,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  // Section header with title and "View all"

  // Task card
  // Task card matching the first image
  Widget _buildTaskCard(TaskDetail task) {
    IconData statusIcon;
    Color accentColor;
    String statusLabel;

    switch (task.status.toLowerCase()) {
      case 'succeeded':
      case 'completed':
        statusIcon = LucideIcons.checkCircle2;
        accentColor = const Color(0xFF10B981);
        statusLabel = '● Completed';
        break;
      case 'failed':
        statusIcon = LucideIcons.xCircle;
        accentColor = const Color(0xFFEF4444);
        statusLabel = '● Failed';
        break;
      case 'approval_pending':
        statusIcon = LucideIcons.clock;
        accentColor = const Color(0xFF3B82F6);
        statusLabel = '● In Progress';
        break;
      default:
        statusIcon = LucideIcons.clock;
        accentColor = const Color(0xFFF59E0B);
        statusLabel = '● Pending';
    }

    return GestureDetector(
      onTap: () =>
          context.push('/tasks/${task.id}', extra: {'query': task.query}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge with dot
            Text(
              statusLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 12),

            // Task title
            Text(
              task.query.isNotEmpty ? task.query : 'No query provided',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Footer with timestamp and arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.clock,
                      size: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      task.timestamp,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                Icon(
                  LucideIcons.arrowRight,
                  size: 18,
                  color: Colors.white.withOpacity(0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // To-Do card matching the second image
  Widget _buildToDoCard(Map<String, dynamic> todo) {
    final isCompleted = todo['status'] == 'completed';

    return GestureDetector(
      onTap: isCompleted ? null : () => completeToDo(todo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D4A6F).withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              todo['title'],
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                decoration: isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                decorationColor: Colors.white.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 6),

            // Description
            Text(
              todo['description'],
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 12),

            // Footer with timestamp and icons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.clock,
                      size: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Today, 20 Sep 2025',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Reminder card matching the style
  Widget _buildReminderCard(Map<String, dynamic> reminder) {
    try {
      final String timeStr = reminder['reminder_time'] as String;
      final DateTime utcTime = DateTime.parse(timeStr).toUtc();
      final DateTime localTime = utcTime.toLocal(); // IST

      final now = DateTime.now();
      final isToday =
          localTime.year == now.year &&
          localTime.month == now.month &&
          localTime.day == now.day;
      final isTomorrow =
          localTime.year == now.add(const Duration(days: 1)).year &&
          localTime.month == now.add(const Duration(days: 1)).month &&
          localTime.day == now.add(const Duration(days: 1)).day;
      final isPast = localTime.isBefore(now);

      String dateLabel;
      if (isToday) {
        dateLabel = 'Today';
      } else if (isTomorrow) {
        dateLabel = 'Tomorrow';
      } else if (isPast) {
        dateLabel = DateFormat('MMM d').format(localTime);
      } else {
        dateLabel = DateFormat('MMM d').format(localTime);
      }

      final timeText = DateFormat('h:mm a').format(localTime);
      final fullDateTime = '$dateLabel, $timeText';

      return GestureDetector(
        onTap: () => context.push('/reminders'),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
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
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      color: isPast ? Colors.grey : const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                reminder['description'] ?? 'No description',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(isPast ? 0.4 : 0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.clock,
                        size: 14,
                        color: Colors.white.withOpacity(isPast ? 0.3 : 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        fullDateTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(isPast ? 0.3 : 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error parsing reminder: $e | Data: $reminder');
      return _buildErrorCard('Failed to load reminder');
    }
  }

  Widget _buildErrorCard(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }

  // Section header with title and "View all"
  Widget _buildSectionHeader(String title, IconData icon, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            'View all',
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF3B82F6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallIconButton(IconData icon) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
      ),
      child: Icon(icon, size: 14, color: Colors.white.withOpacity(0.7)),
    );
  }
}
