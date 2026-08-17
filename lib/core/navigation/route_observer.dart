import 'package:flutter/material.dart';

/// Ignora pops de overlays (dropdown, diálogo) para que [RouteAware.didPopNext]
/// solo dispare al volver de una pantalla completa ([PageRoute]).
final routeObserver = OverlayAwareRouteObserver();

class OverlayAwareRouteObserver extends RouteObserver<ModalRoute<void>> {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    super.didPop(route, previousRoute);
  }
}
