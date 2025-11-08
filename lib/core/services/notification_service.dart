import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationServices {
  //initialising firebase message plugin
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  //initialising firebase message plugin
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  //function to initialise flutter local notification plugin to show notifications for android when app is active
  void initLocalNotifications(
    BuildContext context,
    RemoteMessage message,
  ) async {
    var androidInitializationSettings = const AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    var iosInitializationSettings = const DarwinInitializationSettings();

    var initializationSetting = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSetting,
      onDidReceiveNotificationResponse: (payload) {
        // handle interaction when app is active for android
        handleMessage(context, message);
      },
    );
  }

  void firebaseInit(BuildContext context) {
    FirebaseMessaging.onMessage.listen((message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification!.android;

      if (kDebugMode) {
        print("notifications title:${notification!.title}");
        print("notifications body:${notification.body}");
        print('count:${android!.count}');
        print('data:${message.data.toString()}');
      }

      if (Platform.isIOS) {
        forgroundMessage();
      }

      if (Platform.isAndroid) {
        initLocalNotifications(context, message);
        showNotification(message);
      }
    });
  }

  void requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('user granted permission');
      }
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      if (kDebugMode) {
        print('user granted provisional permission');
      }
    } else {
      //appsetting.AppSettings.openNotificationSettings();
      if (kDebugMode) {
        print('user denied permission');
      }
    }
  }

  // function to show visible notification when app is active
  Future<void> showNotification(RemoteMessage message) async {
    AndroidNotificationChannel channel = AndroidNotificationChannel(
      message.notification!.android!.channelId.toString(),
      message.notification!.android!.channelId.toString(),
      importance: Importance.max,
      showBadge: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('jetsons_doorbell'),
    );

    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          channel.id.toString(),
          channel.name.toString(),
          channelDescription: 'your channel description',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          ticker: 'ticker',
          sound: channel.sound,
          //     sound: RawResourceAndroidNotificationSound('jetsons_doorbell')
          //  icon: largeIconPath
        );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );

    Future.delayed(Duration.zero, () {
      _flutterLocalNotificationsPlugin.show(
        message.hashCode, // Unique ID for the notification
        message.notification!.title.toString(),
        message.notification!.body.toString(),
        notificationDetails,
      );
    });
  }

  
Future<String?> getDeviceToken() async {
  try {
    // final isIOS = Platform.isIOS;
    // final isSimulator = Platform.environment['SIMULATOR_DEVICE_NAME'] != null;

    // ✅ Force-enable FCM even if APNs is missing
    await FirebaseMessaging.instance.setAutoInitEnabled(true);

    // ✅ Simulator path (skip APNs completely)
    // if (isIOS && isSimulator) {
    //   print('✅ Running on iOS Simulator — skipping APNs');
    //   final token = await FirebaseMessaging.instance.getToken();
    //   print('✅ Simulator FCM Token: $token');
    //   return token;
    // }

    // // ✅ Real iPhone — get APNs
    // if (isIOS && !isSimulator) {
    //   String? apns = await FirebaseMessaging.instance.getAPNSToken();
    //   print('✅ APNs Token: $apns');
    // }

    // ✅ Android & real iPhone

      String? apns = await FirebaseMessaging.instance.getAPNSToken();
      print('✅ APNs Token: $apns');
    final token = await FirebaseMessaging.instance.getToken();
    print('✅ FCM Token: $token');
    return token;

  } catch (e) {
    print('❌ Still failing: $e');
    return null;
  }
}

  void isTokenRefresh() async {
    messaging.onTokenRefresh.listen((event) {
      event.toString();
      if (kDebugMode) {
        print('refresh');
      }
    });
  }

  //handle tap on notification when app is in background or terminated
  Future<void> setupInteractMessage(BuildContext context) async {
    // when app is terminated
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();

    if (initialMessage != null) {
      handleMessage(context, initialMessage);
    }

    //when app ins background
    FirebaseMessaging.onMessageOpenedApp.listen((event) {
      handleMessage(context, event);
    });
  }

  void handleMessage(BuildContext context, RemoteMessage message) {
    // Use navigatorKey to ensure valid context
    final BuildContext? navContext = navigatorKey.currentContext;
    if (navContext == null) {
      if (kDebugMode) {
        print('Navigator context is null, cannot navigate');
      }
      return;
    }

    // Get notification type and optional id
    final notificationType = message.data['type'];
    final id = message.data['id'];

    // Map notification types to routes
    switch (notificationType) {
      case 'todo':
        context.go('/home');
        break;
      case 'profile':
        context.go('/profile');
        break;
      case 'tasks':
        context.go('/tasks');
        break;
      case 'integrations':
        context.go('/integrations');
        break;
      case 'settings':
        context.go('/settings');
        break;
      case 'call_sessions':
        context.go('/call_sessions');
        break;
      default:
        // Fallback to home route if type is unknown
        context.go('/home');
    }
  }

  Future forgroundMessage() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  }
}
