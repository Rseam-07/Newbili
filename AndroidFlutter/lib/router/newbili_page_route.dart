import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// Retains GetX bindings/route disposal while using the app's Material motion.
/// The upstream GetPageRoute hard-codes Zoom and ignores PageTransitionsTheme.
class NewbiliPageRoute<T> extends GetPageRoute<T> {
  NewbiliPageRoute({
    super.settings,
    super.page,
    super.parameter,
    super.binding,
    super.bindings,
    super.middlewares,
    super.maintainState,
    super.routeName,
  });

  @override
  Duration get transitionDuration => NewbiliMotion.route;

  @override
  Duration get reverseTransitionDuration => NewbiliMotion.exit;

  @override
  bool get allowSnapshotting => false;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      const PredictiveBackPageTransitionsBuilder().delegatedTransition;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is NewbiliPageRoute || super.canTransitionTo(nextRoute);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => NewbiliMotion.reduced(context)
      ? child
      : Theme.of(context).pageTransitionsTheme.buildTransitions(
          this,
          context,
          animation,
          secondaryAnimation,
          child,
        );
}
