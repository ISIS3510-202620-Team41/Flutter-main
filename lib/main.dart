import 'package:flutter/material.dart';
import 'app.dart';
import 'services/analytics_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AnalyticsService.installErrorHandlers();
  await AnalyticsService.instance.initialize();
  runApp(const LlamallaApp());
}
