import 'dart:math' as math;

import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/pages/main/view.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

typedef OnboardingVersionReader = int Function();
typedef OnboardingVersionWriter = Future<void> Function(int version);

/// Keeps the main application cold until the first-use story is completed.
class FirstUseGate extends StatefulWidget {
  const FirstUseGate({
    super.key,
    this.home,
    this.readVersion,
    this.writeVersion,
  });

  static const int currentVersion = 1;

  final Widget? home;
  final OnboardingVersionReader? readVersion;
  final OnboardingVersionWriter? writeVersion;

  @override
  State<FirstUseGate> createState() => _FirstUseGateState();
}

class _FirstUseGateState extends State<FirstUseGate> {
  late bool _completed;

  @override
  void initState() {
    super.initState();
    final storedVersion = widget.readVersion?.call() ??
        (GStorage.setting.get(SettingBoxKey.newbiliOnboardingVersion) as int? ??
            0);
    _completed = storedVersion >= FirstUseGate.currentVersion;
  }

  Future<void> _complete() async {
    final writeVersion = widget.writeVersion;
    if (writeVersion != null) {
      await writeVersion(FirstUseGate.currentVersion);
    } else {
      await GStorage.setting.put(
        SettingBoxKey.newbiliOnboardingVersion,
        FirstUseGate.currentVersion,
      );
    }
    if (mounted) setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = NewbiliMotion.reduced(context);
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : NewbiliMotion.route,
      switchInCurve: NewbiliMotion.emphasized,
      switchOutCurve: Curves.easeOutCubic,
      child: _completed
          ? KeyedSubtree(
              key: const ValueKey('newbili-home'),
              child: widget.home ?? const MainApp(),
            )
          : NewbiliOnboarding(
              key: const ValueKey('newbili-onboarding'),
              onComplete: _complete,
            ),
    );
  }
}

class NewbiliOnboarding extends StatefulWidget {
  const NewbiliOnboarding({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<NewbiliOnboarding> createState() => _NewbiliOnboardingState();
}

class _NewbiliOnboardingState extends State<NewbiliOnboarding> {
  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      eyebrow: '欢迎来到 NEWBILI',
      title: '把喜欢的内容，\n放回画面中心',
      body: '清爽的 Material 设计、熟悉的内容入口，以及更专注的观看体验。',
      icon: Icons.auto_awesome_rounded,
    ),
    _OnboardingPageData(
      eyebrow: '随时找到下一段精彩',
      title: '首页、动态与搜索，\n自然衔接',
      body: '推荐卡片保留关键信息；滑动、返回和页面切换保持同一条视觉动线。',
      icon: Icons.explore_rounded,
    ),
    _OnboardingPageData(
      eyebrow: '为每一种屏幕准备',
      title: '沉浸播放，\n信息触手可及',
      body: '手机上双指切换全屏与详情；平板上视频与评论面板并肩展开。',
      icon: Icons.play_circle_rounded,
    ),
  ];

  late final PageController _controller;
  int _index = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index == _pages.length - 1) {
      if (_finishing) return;
      setState(() => _finishing = true);
      await widget.onComplete();
      return;
    }
    final reduceMotion = NewbiliMotion.reduced(context);
    if (reduceMotion) {
      _controller.jumpToPage(_index + 1);
    } else {
      await _controller.nextPage(
        duration: NewbiliMotion.route,
        curve: NewbiliMotion.emphasized,
      );
    }
  }

  Future<void> _previous() async {
    if (_index == 0) return;
    final reduceMotion = NewbiliMotion.reduced(context);
    if (reduceMotion) {
      _controller.jumpToPage(_index - 1);
    } else {
      await _controller.previousPage(
        duration: NewbiliMotion.container,
        curve: NewbiliMotion.emphasized,
      );
    }
  }

  Future<void> _skip() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final page = _controller.hasClients
              ? (_controller.page ?? _index.toDouble())
              : _index.toDouble();
          final background = Color.lerp(
            colors.surface,
            colors.primaryContainer.withValues(alpha: 0.46),
            (page / 2).clamp(0.0, 1.0).toDouble(),
          )!;
          return ColoredBox(
            color: background,
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(child: _AmbientBackdrop(progress: page)),
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1360),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 840 &&
                              constraints.maxHeight >= 560;
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              wide ? 48 : 20,
                              wide ? 30 : 12,
                              wide ? 48 : 20,
                              wide ? 32 : 18,
                            ),
                            child: wide
                                ? _wideLayout(page)
                                : _compactLayout(page),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 12,
                    child: Semantics(
                      button: true,
                      label: '跳过首次使用介绍',
                      child: TextButton(
                        key: const ValueKey('onboarding-skip'),
                        onPressed: _finishing ? null : _skip,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(64, NewbiliMetrics.minTouchTarget),
                        ),
                        child: const Text('跳过'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _compactLayout(double page) {
    return Column(
      children: [
        const SizedBox(height: 42),
        Expanded(
          flex: 11,
          child: _OnboardingStory(progress: page),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 8,
          child: _copyPager(),
        ),
        const SizedBox(height: 12),
        _PageIndicators(index: _index, count: _pages.length),
        const SizedBox(height: 16),
        _controls(),
      ],
    );
  }

  Widget _wideLayout(double page) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.only(right: 34),
            child: _OnboardingStory(progress: page),
          ),
        ),
        Expanded(
          flex: 5,
          child: Container(
            margin: const EdgeInsets.only(top: 52),
            padding: const EdgeInsets.fromLTRB(34, 34, 34, 28),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.08),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(child: _copyPager()),
                _PageIndicators(index: _index, count: _pages.length),
                const SizedBox(height: 24),
                _controls(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _copyPager() {
    return PageView.builder(
      key: const ValueKey('onboarding-pages'),
      controller: _controller,
      itemCount: _pages.length,
      onPageChanged: (value) => setState(() => _index = value),
      itemBuilder: (context, index) => _OnboardingCopy(
        data: _pages[index],
        page: index + 1,
        total: _pages.length,
      ),
    );
  }

  Widget _controls() {
    final lastPage = _index == _pages.length - 1;
    return Row(
      children: [
        AnimatedOpacity(
          opacity: _index == 0 ? 0 : 1,
          duration: NewbiliMotion.duration(context, NewbiliMotion.feedback),
          child: IgnorePointer(
            ignoring: _index == 0,
            child: OutlinedButton.icon(
              key: const ValueKey('onboarding-back'),
              onPressed: _previous,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(104, NewbiliMetrics.minTouchTarget),
              ),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('上一步'),
            ),
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          key: const ValueKey('onboarding-next'),
          onPressed: _finishing ? null : _next,
          style: FilledButton.styleFrom(
            minimumSize: const Size(132, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          iconAlignment: IconAlignment.end,
          icon: _finishing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(lastPage ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded),
          label: Text(lastPage ? '开始使用' : '下一步'),
        ),
      ],
    );
  }
}

class _OnboardingCopy extends StatelessWidget {
  const _OnboardingCopy({
    required this.data,
    required this.page,
    required this.total,
  });

  final _OnboardingPageData data;
  final int page;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '第$page页，共$total页。${data.title.replaceAll('\n', '')}。${data.body}',
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(data.icon, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    data.eyebrow,
                    style: text.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              data.title,
              style: text.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.15,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              data.body,
              style: text.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.65,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicators extends StatelessWidget {
  const _PageIndicators({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '第${index + 1}页，共$count页',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (i) {
            final selected = i == index;
            return AnimatedContainer(
              duration: NewbiliMotion.duration(context, NewbiliMotion.feedback),
              curve: Curves.easeOutCubic,
              width: selected ? 28 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: selected ? colors.primary : colors.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final alignment = Alignment(
      -0.82 + progress * 0.7,
      -0.88 + math.sin(progress * math.pi) * 0.22,
    );
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: alignment,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
          Align(
            alignment: Alignment(0.95 - progress * 0.25, 0.78),
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.secondary.withValues(alpha: 0.07),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStory extends StatelessWidget {
  const _OnboardingStory({required this.progress});

  final double progress;

  double _presence(double scene) =>
      (1 - (progress - scene).abs()).clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final one = _presence(0);
    final two = _presence(1);
    final three = _presence(2);
    final isDark = colors.brightness == Brightness.dark;

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: Center(
        child: AspectRatio(
          aspectRatio: 1.18,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final unit = math.min(constraints.maxWidth, constraints.maxHeight);
              final lift = -unit * 0.025 * progress;
              return Transform.translate(
                offset: Offset(0, lift),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Transform.rotate(
                      angle: -0.06 + progress * 0.04,
                      child: Container(
                        width: constraints.maxWidth * 0.82,
                        height: constraints.maxHeight * 0.78,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(42),
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 0.94 + progress * 0.025,
                      child: Container(
                        width: constraints.maxWidth * 0.78,
                        height: constraints.maxHeight * 0.72,
                        padding: EdgeInsets.all(unit * 0.035),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceContainerHigh
                              : colors.surface.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(alpha: 0.65),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withValues(alpha: 0.14),
                              blurRadius: 36,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Opacity(
                              opacity: one,
                              child: Padding(
                                padding: EdgeInsets.all(unit * 0.06),
                                child: SvgPicture.asset(
                                  'assets/images/logo/newbili-icon.svg',
                                  semanticsLabel: 'Newbili 标志',
                                ),
                              ),
                            ),
                            Opacity(opacity: two, child: const _DiscoveryScene()),
                            Opacity(opacity: three, child: const _PlayerScene()),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: constraints.maxWidth * (0.02 + progress * 0.015),
                      bottom: constraints.maxHeight * (0.09 + three * 0.04),
                      child: Transform.scale(
                        scale: 0.85 + two * 0.1 + three * 0.16,
                        child: _FloatingActionBadge(progress: progress),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        ),
      ),
    );
  }
}

class _DiscoveryScene extends StatelessWidget {
  const _DiscoveryScene();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            SvgPicture.asset('assets/images/logo/newbili-mark.svg', width: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Icon(Icons.search_rounded, size: 17),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: _ContentCard(color: colors.primaryContainer)),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Expanded(child: _ContentCard(color: colors.secondaryContainer)),
                    const SizedBox(height: 10),
                    Expanded(child: _ContentCard(color: colors.tertiaryContainer)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: 6,
            width: 58,
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 5,
            width: 34,
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerScene extends StatelessWidget {
  const _PlayerScene();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF202064), Color(0xFF0A4BA7)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, color: colors.onPrimary, size: 48),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: LinearProgressIndicator(
                    value: 0.64,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(99),
                    backgroundColor: Colors.white24,
                    color: const Color(0xFFFF4B8B),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _commentLine(colors, 0.9),
                const SizedBox(height: 10),
                _commentLine(colors, 0.65),
                const SizedBox(height: 10),
                _commentLine(colors, 0.78),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _commentLine(ColorScheme colors, double width) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 8,
            backgroundColor: colors.primaryContainer,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: width,
              child: Container(
                height: 22,
                decoration: BoxDecoration(
                  color: colors.outlineVariant.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
        ],
      );
}

class _FloatingActionBadge extends StatelessWidget {
  const _FloatingActionBadge({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = progress < 0.7
        ? Icons.auto_awesome_rounded
        : progress < 1.55
            ? Icons.explore_rounded
            : Icons.forum_rounded;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: colors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: colors.surface, width: 4),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: colors.onPrimary),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
}
