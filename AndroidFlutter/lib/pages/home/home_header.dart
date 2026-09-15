import 'dart:async';

import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  static double heightOf(BuildContext context) => _tabHeight(context) + 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerHeight: 0,
        indicator: _SectionIndicator(theme.colorScheme.primary),
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 3,
        labelColor: theme.colorScheme.onSurface,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        tabs: [
          for (final label in labels)
            Tab(height: _tabHeight(context), text: label),
        ],
        onTap: onTap,
      ),
    );
  }
}

class _SectionIndicator extends Decoration {
  const _SectionIndicator(this.color);
  final Color color;
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _SectionPainter(color);
}

class _SectionPainter extends BoxPainter {
  _SectionPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          offset.dx + (size.width - 16) / 2,
          offset.dy + size.height - 5,
          16,
          3,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );
  }
}

/// App identity is shared with Newbili's existing vector mark.
class NewbiliWordmark extends StatelessWidget {
  const NewbiliWordmark({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Newbili',
    image: true,
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/logo/newbili-mark.svg',
            width: 30,
            height: 30,
          ),
          if (!compact) ...[
            const SizedBox(width: 5),
            Text(
              'Newbili',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -.7,
                color: ColorScheme.of(context).onSurface,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class NewbiliSearchEntry extends StatelessWidget {
  const NewbiliSearchEntry({
    super.key,
    required this.onTap,
    this.hint = '搜索视频、UP主',
  });
  final VoidCallback onTap;
  final String hint;
  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return Semantics(
      button: true,
      label: '搜索',
      child: Material(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NewbiliHomeToolbar extends StatelessWidget {
  const NewbiliHomeToolbar({
    super.key,
    required this.onSearch,
    required this.trailing,
  });
  final VoidCallback onSearch;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
    child: Row(
      children: [
        NewbiliWordmark(
          compact:
              MediaQuery.sizeOf(context).width < 360 ||
              MediaQuery.textScalerOf(context).scale(14) > 20,
        ),
        const SizedBox(width: 16),
        Expanded(child: NewbiliSearchEntry(onTap: onSearch)),
        const SizedBox(width: 4),
        SizedBox(width: 48, height: 48, child: trailing),
      ],
    ),
  );
}

/// The reference's light top menu, adapted to touch and resizable windows.
class NewbiliTabletToolbar extends StatelessWidget {
  const NewbiliTabletToolbar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    required this.onSearch,
    required this.trailing,
  });
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSearch;
  final Widget trailing;
  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
      child: Row(
        children: [
          NewbiliWordmark(compact: largeText),
          const SizedBox(width: 28),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Semantics(
                      selected: selectedIndex == i,
                      button: true,
                      child: InkWell(
                        onTap: () => onSelected(i),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 64,
                            minHeight: 48,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: selectedIndex == i
                              ? _SectionIndicator(colors.primary)
                              : null,
                          alignment: Alignment.center,
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selectedIndex == i
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selectedIndex == i
                                  ? colors.onSurface
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: largeText ? 160 : 220,
            child: NewbiliSearchEntry(onTap: onSearch),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

/// Clips paint, input and semantics together, including at the final pixel.
class NewbiliCollapsingToolbar extends StatelessWidget {
  const NewbiliCollapsingToolbar({
    super.key,
    required this.offset,
    required this.child,
  });
  final double offset;
  final Widget child;
  static const height = 60.0;

  @override
  Widget build(BuildContext context) {
    final fraction = (1 - offset / height).clamp(0.0, 1.0);
    return ClipRect(
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: fraction,
        child: ExcludeSemantics(
          excluding: fraction == 0,
          child: IgnorePointer(
            ignoring: fraction == 0,
            child: SizedBox(height: height, child: child),
          ),
        ),
      ),
    );
  }
}
