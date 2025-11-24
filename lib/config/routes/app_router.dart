import 'package:Maya/features/authentication/presentation/pages/forgot_password.dart';
import 'package:Maya/features/authentication/presentation/pages/energy_page.dart';
import 'package:Maya/features/widgets/talk_to_maya.dart';
import 'package:Maya/utils/tab_layout.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import 'package:Maya/core/network/api_client.dart';
import 'package:Maya/core/services/navigation_service.dart';

import 'package:Maya/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:Maya/features/authentication/presentation/bloc/auth_state.dart';

import 'package:Maya/features/authentication/presentation/pages/splash_page.dart';
import 'package:Maya/features/authentication/presentation/pages/login_page.dart';
import 'package:Maya/features/authentication/presentation/pages/home_page.dart';
import 'package:Maya/features/authentication/presentation/pages/tasks_page.dart';
import 'package:Maya/features/authentication/presentation/pages/settings_page.dart';
import 'package:Maya/features/authentication/presentation/pages/other_page.dart';
import 'package:Maya/features/authentication/presentation/pages/profile_page.dart';
import 'package:Maya/features/authentication/presentation/pages/call_sessions.dart';
import 'package:Maya/features/authentication/presentation/pages/integration_page.dart';
import 'package:Maya/features/authentication/presentation/pages/generations_page.dart';
import 'package:Maya/features/authentication/presentation/pages/todos_page.dart';
import 'package:Maya/features/authentication/presentation/pages/reminders_page.dart';

import 'package:Maya/features/widgets/ghl.dart';
import 'package:Maya/features/widgets/task_detail.dart';

class AppRouter {
  // Pathsx
  static const splash = '/';
  static const login = '/login';

  // Tabs (we'll show bottom nav on these 5)
  static const home = '/home';
  static const tasks = '/tasks';
  static const maya = '/maya';
  static const settings = '/settings';
  static const other = '/other';

  // Non-tab pages
  static const profile = '/profile';
  static const integrations = '/integrations';
  static const callSessions = '/call_sessions';
  static const ghl = '/ghl';
  static const generations = '/generations';
  static const todos = '/todos';
  static const reminders = '/reminders';
  static const forgotPassword = '/forgot-password';
  static const energy = '/energy';
  // Nested/detail
  static const taskDetail = '/tasks/:taskId';

  static final ValueNotifier<AuthState> authStateNotifier =
      ValueNotifier<AuthState>(AuthInitial());

  static GoRouter createRouter(AuthBloc authBloc) {
    authStateNotifier.value = authBloc.state;

    authBloc.stream.listen((state) {
      authStateNotifier.value = state;
    });

    return GoRouter(
      navigatorKey: NavigationService.navigatorKey,
      initialLocation: splash,
      refreshListenable: authStateNotifier,
      debugLogDiagnostics: true,

      redirect: (context, state) {
        final authed = authStateNotifier.value is AuthAuthenticated;
        final loading =
            authStateNotifier.value is AuthLoading ||
            authStateNotifier.value is AuthInitial;

        final loc = state.uri.path;

        // ✅ If loading, stay on splash only if already there
        if (loading) {
          if (loc != splash) return splash;
          return null;
        }

        // ✅ If NOT authenticated, block protected pages
        if (!authed) {
          if (loc == splash || _isProtected(loc)) {
            return login;
          }
          return null;
        }

        // ✅ If authenticated, avoid splash/login
        if (loc == splash || loc == login) {
          return home;
        }

        return null;
      },
      // ✅ Flat routes so that `push()` creates a global back stack
      routes: [
        // Auth
        GoRoute(path: splash, builder: (_, __) => const SplashPage()),
        GoRoute(path: login, builder: (_, __) => const LoginPage()),

        // ✅ Tabs (wrapped in TabLayout so bottom nav is visible)
      ShellRoute(
      builder: (context, state, child) => TabLayout(child: child),
      routes: [
        GoRoute(
          path: home,
          pageBuilder: (context, state) => const NoTransitionPage(child: HomePage()),
        ),
        GoRoute(
          path: tasks,
          pageBuilder: (context, state) => const NoTransitionPage(child: TasksPage()),
        ),
        GoRoute(
          path: maya,
          pageBuilder: (context, state) => const NoTransitionPage(child: TalkToMaya()),
        ),
        GoRoute(
          path: settings,
          pageBuilder: (context, state) => const NoTransitionPage(child: SettingsPage()),
        ),
        GoRoute(
          path: other,
          pageBuilder: (context, state) => const NoTransitionPage(child: OtherPage()),
        ),
      ],
    ),        // ✅ Detail under tasks (no bottom nav by default; change if you want)
        GoRoute(
          path: taskDetail,
          builder: (_, state) => TaskDetailPage(
            // sessionId: state.pathParameters['taskId']!,
            // apiClient: ApiClient(Dio(), Dio()),
            // taskQuery: '',
          ),
        ),

        // ✅ Other protected pages (non-tab). If you want bottom nav shown here too,
        // wrap them in TabLayout with whichever index makes sense.
        GoRoute(path: profile, builder: (_, __) => const ProfilePage()),
        GoRoute(
          path: callSessions,
          builder: (_, __) => const CallSessionsPage(),
        ),
        GoRoute(
          path: integrations,
          builder: (_, __) => const IntegrationsPage(),
        ),
        GoRoute(path: ghl, builder: (_, __) => const GhlWebViewPage()),
        GoRoute(path: generations, builder: (_, __) => const GenerationsPage()),
        GoRoute(path: todos, builder: (_, __) => const TodosPage()),
        GoRoute(path: reminders, builder: (_, __) => const RemindersPage()),
        GoRoute(path: forgotPassword, builder: (_, __) => const ForgotPasswordPage()),
        GoRoute(path: energy, builder: (_, __) => const EnergyPage(data: {},)),
      ],
    );
  }

  static bool _isProtected(String loc) {
    // Mark all app pages as protected, plus dynamic ones
    const protectedFixed = <String>{
      home,
      tasks,
      maya,
      settings,
      other,
      profile,
      integrations,
      callSessions,
      ghl,
      generations,
      todos,
      reminders,
      energy,
    };
    return protectedFixed.contains(loc) ||
        loc.startsWith('/tasks/') ||
        loc.startsWith('/ghl');
  }
}