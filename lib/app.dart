import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

class AppRoutes {
  static const home = '/';
}

class LlamallaApp extends StatelessWidget {
  const LlamallaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ActiYa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => const DashboardScreen(),
      },
    );
  }
}
