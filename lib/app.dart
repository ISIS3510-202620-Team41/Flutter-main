import 'package:flutter/material.dart';
import 'dart:async';

import 'analytics/analytics_facade.dart';
import 'analytics/analytics_navigator_observer.dart';
import 'analytics/analytics_screen_catalog.dart';

import 'models/activity.dart';
import 'navigation/app_routes.dart';

import 'screens/dashboard_screen.dart';
import 'screens/activity_detail_screen.dart';
import 'screens/activity_created_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/step1_invite_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'services/connectivity_service.dart';
import 'widgets/offline_banner.dart';
import 'services/pending_actions_sync_service.dart';

class LlamallaApp extends StatefulWidget {
  const LlamallaApp({super.key});

  @override
  State<LlamallaApp> createState() => _LlamallaAppState();
}

class _LlamallaAppState extends State<LlamallaApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final Future<bool> _sessionFuture = _restoreSession();
  final _startupStopwatch = Stopwatch()..start();
  late final Timer _analyticsTimer;
  bool _startupTracked = false;
  final _connectivityService = ConnectivityService.instance;
  final _pendingActionsSyncService = PendingActionsSyncService.instance;

  late final AnalyticsNavigatorObserver _analyticsObserver =
    AnalyticsNavigatorObserver(
      initialScreenResolver: () => 
          authSession.isAuthenticated == true
              ? AnalyticsScreenCatalog.home
              : AnalyticsScreenCatalog.login,
          onScreenView: (screen) => AnalyticsFacade.instance.trackScreenView(screen: screen,),
          currentDashboardTabResolver: () => AnalyticsFacade.instance.currentDashboardTab,
      );

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    authSession.addListener(_onAuthChanged);

    // Inicia el monitor global de conectividad.
    unawaited(_connectivityService.start());

    // Inicia el listener de sincronización.
    _pendingActionsSyncService.start();

    _analyticsTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(AnalyticsFacade.instance.flush()),
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
      unawaited(AnalyticsFacade.instance.flush());
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAndSync());
    }
  }

  void _trackStartup() {
    if (_startupTracked) return;

    _startupTracked = true;

    unawaited(
      AnalyticsFacade.instance.trackAppLoadingTime(
        loadType: "cold_start",
        duration: _startupStopwatch.elapsed,
      ),
    );
  }

  void _onAuthChanged() {
    if (!mounted) return;

    // Si el usuario inicia o recupera sesión, intentamos sincronizar las acciones pendientes.
    if (authSession.isAuthenticated == true) {
      if (_connectivityService.isOnline == true) {
        unawaited(
          _pendingActionsSyncService.syncPendingActions(),
        );
      }

      return;
    }

    // Si el usuario cierra sesión, regresamos al login.
    if (authSession.isAuthenticated == false) {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (_) => false,
      );
    }
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

  Future<void> _refreshAndSync() async {
    await _connectivityService.refresh();

    if (authSession.isAuthenticated == true &&
        _connectivityService.isOnline == true) {
      await _pendingActionsSyncService.syncPendingActions();
    }
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
            navigatorObservers: [_analyticsObserver],
            builder: (context, child) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _trackStartup(),
              );

              return StreamBuilder<bool>(
                stream: ConnectivityService.instance.onConnectivityChanged,
                initialData: ConnectivityService.instance.isOnline,
                builder: (context, snapshot) {
                  final isOffline = snapshot.data == false;

                  return Column(
                    children: [
                      if (isOffline)
                        const OfflineBanner(),

                      Expanded(
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
              );
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
                  settings: const RouteSettings(name: AppRoutes.login),
                  builder: (_) => const LoginScreen(),
                );
              }
              switch (settings.name) {
                case AppRoutes.home:
                  return MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) => const DashboardScreen(),
                  );
                case AppRoutes.login:
                  return MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) => const LoginScreen(),
                    );
                case AppRoutes.register:
                  return MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) => const RegisterScreen(),
                  );
                case AppRoutes.createActivity:
                  return MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) => const Step1InviteScreen(),
                  );
                case AppRoutes.activityCreated:
                  final args = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) => ActivityCreatedScreen(activity: args['activity'] as Activity,
                      friends: args['friends'] as List<String>,
                      savedOffline: args['savedOffline'] as bool? ?? false,),
                  );
                case AppRoutes.activityDetail:
                  final activityId = settings.arguments;

                  return MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) => ActivityDetailScreen(
                      activityId: activityId is String
                          ? activityId
                          : null,
                    ),
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
