import 'dart:async';

import 'package:flutter/widgets.dart';

import '../navigation/app_routes.dart';
import 'analytics_facade.dart';
import 'analytics_screen_catalog.dart';

class AnalyticsNavigatorObserver extends NavigatorObserver {
  AnalyticsNavigatorObserver({
    required this.initialScreenResolver,
    AnalyticsFacade? facade,
  }) : _facade = facade ?? AnalyticsFacade.instance;

  final String Function() initialScreenResolver;
  final AnalyticsFacade _facade;

  final Map<Route<dynamic>, String> _routeScreens =
      Map<Route<dynamic>, String>.identity();

  bool _initialRouteSeen = false;

  // Usado cuando la app abre una pantallas, etc.
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute,) {
    final isInitialRoute = !_initialRouteSeen;
    _initialRouteSeen = true;

    _track(route, isInitialRoute: isInitialRoute);

    super.didPush(route, previousRoute);
  }

  // Cuando una ruta se cambia por otra para dejar la actual como activa
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute,}) {
    if (oldRoute != null) {
      _routeScreens.remove(oldRoute);
    }

    if (newRoute != null) {
      _track(newRoute);
    }

    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute,) {
    final poppedScreen = _routeScreens.remove(route); //El nombre de la pantalla que acaba de salir, si estaba registrada

    if (poppedScreen != null && previousRoute != null) {
      final previousScreen =
          _routeScreens[previousRoute] ??
          AnalyticsScreenCatalog.screenForRoute(
            previousRoute.settings.name,
          );

      final visibleScreen =
          previousRoute.settings.name == AppRoutes.home &&
              previousScreen == AnalyticsScreenCatalog.home
          ? _facade.currentDashboardTab
          : previousScreen;

      if (visibleScreen != null) {
        unawaited(
          _facade.trackScreenView(screen: visibleScreen),
        );
      }
    }

    super.didPop(route, previousRoute);
  }

  void _track(Route<dynamic> route, { bool isInitialRoute = false,}) {
    final routeName = route.settings.name;

    // Identificamos que pantalla debe registrarse
    final String? screen =
        isInitialRoute &&
            (routeName == null || routeName == AppRoutes.home)
        ? initialScreenResolver()
        : AnalyticsScreenCatalog.screenForRoute(routeName);

    if (screen == null) {
      _routeScreens.remove(route);
      return;
    }

    // Guarda la ruta y su pantalla
    _routeScreens[route] = screen;

    unawaited(
      _facade.trackScreenView(screen: screen),
    );
  }
}