import 'dart:async';

import 'package:PiliPlus/common/widgets/route_aware_mixin.dart';
import 'package:material_ui/material_ui.dart';

/// Refreshes a visible page on return/resume and every 30 seconds. Requests
/// never overlap and hidden/background pages do not keep polling.
class ForegroundRefresh extends StatefulWidget {
  const ForegroundRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<ForegroundRefresh> createState() => _ForegroundRefreshState();
}

class _ForegroundRefreshState extends State<ForegroundRefresh>
    with WidgetsBindingObserver, RouteAware {
  Timer? _timer;
  ModalRoute<dynamic>? _route;
  bool _busy = false;
  bool get _visible =>
      mounted &&
      (_route?.isCurrent ?? true) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      routeObserver.unsubscribe(this);
      _route = route;
      if (route is PageRoute<dynamic>) routeObserver.subscribe(this, route);
    }
    _schedule();
  }

  void _schedule({bool refresh = false}) {
    _timer?.cancel();
    if (!_visible) return;
    if (refresh) unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!_visible || _busy) return;
    _busy = true;
    try {
      await widget.onRefresh();
    } catch (_) {
      // The page retains its last result; the next visible tick can retry.
    } finally {
      _busy = false;
    }
  }

  @override
  void didPopNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _schedule(refresh: true);
    });
  }

  @override
  void didPushNext() => _timer?.cancel();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _schedule(refresh: state == AppLifecycleState.resumed);
  @override
  void dispose() {
    _timer?.cancel();
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
