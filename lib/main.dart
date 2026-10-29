import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'analytics/analytics_facade.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  AnalyticsFacade.installErrorHandlers();
  await AnalyticsFacade.instance.initialize();
  runApp(const LlamallaApp());
}
