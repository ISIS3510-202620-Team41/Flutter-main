import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'database/local_database_facade.dart';
import 'app.dart';
import 'analytics/analytics_facade.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env', isOptional: true);

  AnalyticsFacade.installErrorHandlers();
  await AnalyticsFacade.instance.initialize();

  await LocalDatabaseFacade.instance.initialize();

  await NotificationService.instance.initialize();
  // Recuperar y programar las actividades guardadas localmente.
  await NotificationService.instance.syncCurrentUserPlans();
  SyncService.instance.start();

  runApp(const LlamallaApp());
}
