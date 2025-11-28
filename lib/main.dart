import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:Maya/firebase_options.dart';
import 'config/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/presentation/bloc/auth_bloc.dart';
import 'features/authentication/presentation/bloc/auth_event.dart';
import 'injection_container.dart' as di;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'core/network/query_client.dart'; // ← your file above
import 'package:firebase_app_check/firebase_app_check.dart';
// Background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();   // ← iOS automatically uses plist
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(
  appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
);




  final FirebaseMessaging messaging = FirebaseMessaging.instance;


  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('User granted permission: ${settings.authorizationStatus}');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

runApp(
       QueryClientProvider(  // ← Important!
        client: QueryClient(
  cache: QueryCache.instance,
  networkPolicy: NetworkPolicy.instance,),
        child: const MyApp(),
      ),
  );}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = di.sl<AuthBloc>();
    _router = AppRouter.createRouter(_authBloc);
    _authBloc.add(AppStarted());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupFirebaseMessaging();
  }

  void _setupFirebaseMessaging() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received foreground message: ${message.notification?.title}');

      if (message.notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${message.notification?.title}: ${message.notification?.body}',
            ),
          ),
        );
      }
    });

    // App opened from terminated
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationNavigation(message);
      }
    });

    // App opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationNavigation(message);
    });

    // Token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      print("FCM Token refreshed: $token");
    });

    // iOS APNs token
    FirebaseMessaging.instance.getAPNSToken().then((apns) {
      print("APNs Token: $apns");
    });
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    final String? route = message.data["route"];
    if (route != null && mounted) {
      print("Navigating to: $route");
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'Maya App',
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }
}
