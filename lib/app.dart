import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/activity_detail_screen.dart';
import 'screens/activity_created_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
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

class LlamallaApp extends StatelessWidget {
  const LlamallaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ActiYa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.home: (_) => const DashboardScreen(),
        AppRoutes.createActivity: (_) => const ActivityCreatedScreen(),
        AppRoutes.activityCreated: (_) => const ActivityCreatedScreen(),
        AppRoutes.activityDetail: (_) => const ActivityDetailScreen(),
      },
    );
  }
}
