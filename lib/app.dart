import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/activity_detail_screen.dart';
import 'screens/activity_created_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/auth_service.dart';
// import 'screens/create_activity_placeholder_screen.dart';
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
  late final Future<bool> _sessionFuture = AuthService().restoreSession();

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
        return MaterialApp(
          title: 'ActiYa',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: snapshot.data! ? const DashboardScreen() : const LoginScreen(),
          routes: {
            AppRoutes.login: (_) => const LoginScreen(),
            AppRoutes.register: (_) => const RegisterScreen(),
            AppRoutes.createActivity: (_) => const ActivityCreatedScreen(),
            AppRoutes.activityCreated: (_) => const ActivityCreatedScreen(),
            AppRoutes.activityDetail: (_) => const ActivityDetailScreen(),
          },
        );
      },
    );
  }
}
