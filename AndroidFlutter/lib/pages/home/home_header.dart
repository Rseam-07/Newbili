import 'dart:async';

import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Same wording and time ranges as iOS HomeGreetingContent.
({String title, String subtitle}) homeGreeting(int hour, String? displayName) {
  final (salutation, subtitle) = switch (hour) {
    >= 5 && < 10 => ('早上好', '新一天，从喜欢的内容开始'),
    >= 10 && < 13 => ('中午好', '歇一会儿，看看为你挑的内容'),
    >= 13 && < 18 => ('下午好', '为你准备了一些新鲜内容'),
    >= 18 && < 23 => ('晚上好', '今晚想看点什么？'),
    _ => ('夜深了', '慢慢看，也别忘了休息'),
  };
  final name = displayName?.trim() ?? '';
  return (
    title: name.isEmpty ? salutation : '$salutation，$name',
    subtitle: subtitle,
  );
}

class HomeGreeting extends StatefulWidget {
  const HomeGreeting({super.key, this.displayName});
  final String? displayName;

  @override
  State<HomeGreeting> createState() => _HomeGreetingState();
}

class _HomeGreetingState extends State<HomeGreeting>
    with WidgetsBindingObserver {
  int _hour = DateTime.now().hour;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _updateClock();

  void _updateClock() {
    _timer?.cancel();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!TickerMode.valuesOf(context).enabled ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      return;
    }
    final now = DateTime.now();
    if (_hour != now.hour) setState(() => _hour = now.hour);
    // One wake-up at the next hour, not a timer per frame or per minute.
    _timer = Timer(
      DateTime(now.year, now.month, now.day, now.hour + 1).difference(now),
      _updateClock,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final greeting = homeGreeting(_hour, widget.displayName);
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            greeting.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (MediaQuery.orientationOf(context) == Orientation.portrait)
            Text(
              greeting.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class HomeSectionTabs extends StatelessWidget {
  const HomeSectionTabs({
    super.key,
    required this.controller,
    required this.labels,
    required this.onTap,
  });
  final TabController controller;
  final List<String> labels;
  final ValueChanged<int> onTap;

  static double _tabHeight(BuildContext context) =>
      (MediaQuery.textScalerOf(context).scale(20) + 16).clamp(
        NewbiliMetrics.minTouchTarget,
        double.infinity,
      );

  // TabBar reserves its indicator weight even with a custom decoration.
  static double heightOf(BuildContext context) => _tabHeight(context) + 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          dividerHeight: 0,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: .20),
            ),
          ),
          labelColor: theme.colorScheme.onSurface,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          splashBorderRadius: BorderRadius.circular(24),
          tabs: [
            for (final label in labels)
              Tab(
                height: _tabHeight(context),
                text: label,
              ),
          ],
          onTap: onTap,
        ),
      ),
    );
  }
}
