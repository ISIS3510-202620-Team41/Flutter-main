import 'package:flutter/material.dart';
import 'dart:async';
import 'services/analytics_service.dart';

import 'screens/dashboard_screen.dart';
import 'screens/activity_detail_screen.dart';
import 'screens/activity_created_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/step1_invite_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const home = '/';
  static const createActivity = '/activity/create';
  static const activityDetail = '/activity-detail';
  static const activityCreated = '/activity-created'; //Confirmation screen
}

class LlamallaApp extends StatefulWidget {
  const LlamallaApp({super.key});

  @override
  State<LlamallaApp> createState() => _LlamallaAppState();
}

class _LlamallaAppState extends State<LlamallaApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final Future<bool> _sessionFuture = _restoreSession();
  final _startupStopwatch = Stopwatch()..start();
  late final Timer _analyticsTimer;
  bool _startupTracked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    authSession.addListener(_onAuthChanged);
    _analyticsTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(AnalyticsService.instance.flush()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _analyticsTimer.cancel();
    authSession.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(AnalyticsService.instance.flush());
    }
  }

  void _trackStartup() {
    if (_startupTracked) return;
    _startupTracked = true;
    unawaited(
      AnalyticsService.instance.track('app_loading_time', {
        'loadType': 'cold_start',
        'durationMs': _startupStopwatch.elapsedMilliseconds,
      }),
    );
  }

  void _onAuthChanged() {
    if (!mounted || authSession.isAuthenticated != false) return;
    _navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  }

  Future<bool> _restoreSession() async {
    final restored = await AuthService().restoreSession();
    if (restored) {
      authSession.setAuthenticated();
    } else {
      authSession.setUnauthenticated();
    }
    return restored;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return AnimatedBuilder(
          animation: authSession,
          builder: (context, _) => MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Llamalla',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            navigatorObservers: [AnalyticsNavigatorObserver()],
            builder: (context, child) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _trackStartup(),
              );
              return child ?? const SizedBox.shrink();
            },
            home: authSession.isAuthenticated == true
                ? const DashboardScreen()
                : const LoginScreen(),
            onGenerateRoute: (settings) {
              final protectedRoutes = {
                AppRoutes.home,
                AppRoutes.createActivity,
                AppRoutes.activityCreated,
                AppRoutes.activityDetail,
              };
              if (protectedRoutes.contains(settings.name) &&
                  authSession.isAuthenticated != true) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const LoginScreen(),
                );
              }
              switch (settings.name) {
                case AppRoutes.home:
                  return MaterialPageRoute(
                    builder: (_) => const DashboardScreen(),
                  );
                case AppRoutes.login:
                  return MaterialPageRoute(builder: (_) => const LoginScreen());
                case AppRoutes.register:
                  return MaterialPageRoute(
                    builder: (_) => const RegisterScreen(),
                  );
                case AppRoutes.createActivity:
                  return MaterialPageRoute(
                    builder: (_) => const Step1InviteScreen(),
                  );
                case AppRoutes.activityCreated:
                  return MaterialPageRoute(
                    builder: (_) => const ActivityCreatedScreen(),
                  );
                case AppRoutes.activityDetail:
                  return MaterialPageRoute(
                    builder: (_) => const ActivityDetailScreen(),
                  );
                default:
                  return null;
              }
            },
          ),
        );
      },
    );
  }
}
