import 'package:flutter/material.dart';

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

class _LlamallaAppState extends State<LlamallaApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final Future<bool> _sessionFuture = _restoreSession();

  @override
  void initState() {
    super.initState();
    authSession.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    authSession.removeListener(_onAuthChanged);
    super.dispose();
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
            title: 'ActiYa',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
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
