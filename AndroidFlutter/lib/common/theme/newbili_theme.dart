import 'package:material_ui/material_ui.dart';

abstract final class NewbiliMotion {
  static const feedback = Duration(milliseconds: 160);
  static const container = Duration(milliseconds: 300);
  static const route = Duration(milliseconds: 400);
  static const exit = Duration(milliseconds: 280);
  static const emphasized = Curves.easeInOutCubicEmphasized;

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  static Duration duration(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

abstract final class NewbiliMetrics {
  static const minTouchTarget = 48.0;
  static const compactRadius = 12.0;
  static const cardRadius = 12.0;
  static const chromeRadius = 16.0;
  static const paneBreakpoint = 1024.0;
}
