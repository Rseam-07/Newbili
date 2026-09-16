import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/common/widgets/main_layout.dart';
import 'package:PiliPlus/common/widgets/newbili_cover_hero.dart';
import 'package:PiliPlus/common/widgets/newbili_destination_view.dart';
import 'package:PiliPlus/common/widgets/newbili_navigation_bar.dart';
import 'package:PiliPlus/pages/home/home_header.dart';
import 'package:PiliPlus/router/app_pages.dart';
import 'package:PiliPlus/pages/video/widgets/tablet_player_stage.dart';
import 'package:PiliPlus/router/newbili_page_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('tablet navigation stays in the top toolbar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = 0;
    var searched = false;
    final sections = TabController(length: 5, vsync: tester);
    addTearDown(sections.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: MainLayout(
            sideBar: null,
            bottomNav: null,
            body: Align(
              alignment: Alignment.topCenter,
              child: NewbiliTabletToolbar(
                sections: HomeSectionTabs(
                  controller: sections,
                  labels: const ['推荐', '热门', '分区', '番剧', '影视'],
                  compact: true,
                  onTap: (_) {},
                ),
                labels: const ['首页', '动态', '直播'],
                selectedIndex: selected,
                onSelected: (index) => selected = index,
                onSearch: () => searched = true,
                trailing: const SizedBox.square(
                  dimension: 48,
                  child: Icon(Icons.person_outline_rounded),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('动态'), findsOneWidget);
    expect(find.text('直播'), findsOneWidget);
    expect(find.text('我的'), findsNothing);
    expect(find.text('搜索'), findsNothing);
    expect(find.byType(HomeSectionTabs), findsOneWidget);
    expect(
      (tester.getCenter(find.text('推荐')).dy -
              tester.getCenter(find.text('首页')).dy)
          .abs(),
      lessThan(4),
    );
    await tester.tap(find.text('动态'));
    expect(selected, 1);
    await tester.tap(find.text('热门'));
    await tester.pumpAndSettle();
    expect(sections.index, 1);
    await tester.tap(find.byType(NewbiliSearchEntry));
    expect(searched, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final width in [840.0, 1024.0, 1280.0]) {
    testWidgets(
      'tablet header at $width with large text keeps menus reachable',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final sections = TabController(length: 5, vsync: tester);
        addTearDown(sections.dispose);
        var selected = 0;
        var searched = false;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: NewbiliTabletToolbar(
                  sections: HomeSectionTabs(
                    controller: sections,
                    labels: const ['推荐', '热门', '分区', '番剧', '影视'],
                    compact: true,
                    onTap: (_) {},
                  ),
                  labels: const ['首页', '动态', '直播'],
                  selectedIndex: selected,
                  onSelected: (index) => selected = index,
                  onSearch: () => searched = true,
                  trailing: const SizedBox(width: 100, height: 48),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('影视'));
        await tester.tap(find.text('影视'));
        await tester.pumpAndSettle();
        expect(sections.index, 4);
        await tester.ensureVisible(find.text('直播'));
        await tester.tap(find.text('直播'));
        expect(selected, 2);
        await tester.tap(find.byTooltip('搜索视频、UP主'));
        expect(searched, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'destination changes retain scroll and interrupt from the current frame',
    (tester) async {
      final selected = ValueNotifier(0);
      final scroll = ScrollController();
      final mounted = <int>[];
      addTearDown(selected.dispose);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: selected,
              builder: (context, index, _) => NewbiliDestinationView(
                index: index,
                children: [
                  for (var i = 0; i < 5; i++)
                    _MountedPage(
                      key: ValueKey('page-$i'),
                      onInit: () => mounted.add(i),
                      child: i == 0
                          ? ListView(
                              controller: scroll,
                              children: const [SizedBox(height: 2000)],
                            )
                          : Center(child: Text('Page $i')),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      scroll.jumpTo(180);
      selected.value = 4;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final inFlight = tester.getTopLeft(find.byKey(const ValueKey('page-4')));
      selected.value = 1;
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(const ValueKey('page-4'))), inFlight);
      await tester.pumpAndSettle();
      expect(mounted, [0, 4, 1]);
      expect(find.text('Page 1').hitTestable(), findsOneWidget);
      expect(find.text('Page 4').hitTestable(), findsNothing);
      selected.value = 0;
      await tester.pumpAndSettle();
      expect(scroll.offset, 180);
      expect(mounted, [0, 4, 1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tablet subpage preserves the base scroll and lazy mounting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final index = ValueNotifier(0);
    final scroll = ScrollController();
    final mounted = <int>[];
    addTearDown(index.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: index,
          builder: (_, i, _) => NewbiliDestinationView(
            index: i,
            baseIndex: 0,
            paneTitle: '动态',
            onClosePane: () => index.value = 0,
            children: [
              for (var n = 0; n < 3; n++)
                _MountedPage(
                  onInit: () => mounted.add(n),
                  child: n == 0
                      ? ListView(
                          controller: scroll,
                          children: const [SizedBox(height: 2000)],
                        )
                      : Text('subpage $n'),
                ),
            ],
          ),
        ),
      ),
    );
    scroll.jumpTo(180);
    index.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    index.value = 2;
    await tester.pumpAndSettle();
    expect(mounted, [0, 1, 2]);
    expect(scroll.offset, 180);
    expect(find.text('subpage 2').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('收起副页'));
    await tester.pumpAndSettle();
    expect(scroll.offset, 180);
    expect(find.text('subpage 2').hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet comment panel never remounts its player', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var mounts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TabletPlayerStage(
          playerBuilder: (w, h) => SizedBox(
            width: w,
            height: h,
            child: _MountedPage(
              onInit: () => mounts++,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
          details: const Text('Details'),
          secondary: const Text('Comments'),
          extraPane: const Text('Following feed'),
          onSendDanmaku: () {},
        ),
      ),
    );
    final closedBounds = tester.getRect(find.byType(_MountedPage));
    expect(closedBounds.width, 1280);
    await tester.tap(find.byTooltip('打开简介、评论与动态'));
    await tester.pumpAndSettle();
    final playerBounds = tester.getRect(find.byType(_MountedPage));
    expect(playerBounds.width, 1280 * .7);
    await tester.tap(find.text('评论'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('动态'));
    await tester.pumpAndSettle();
    expect(find.text('Following feed').hitTestable(), findsOneWidget);
    expect(find.text('Comments').hitTestable(), findsNothing);
    await tester.tap(find.text('简介'));
    await tester.pumpAndSettle();
    expect(mounts, 1);
    expect(tester.getRect(find.byType(_MountedPage)), playerBounds);
    await tester.tap(find.byTooltip('收起内容卡片'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(_MountedPage)), closedBounds);
    expect(mounts, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact tablet player remains usable with largest text', (
    tester,
  ) async {
    const size = Size(840, 600);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(3),
            disableAnimations: true,
          ),
          child: TabletPlayerStage(
            playerBuilder: (w, h) => SizedBox(width: w, height: h),
            details: ListView(children: const [Text('标题与简介')]),
            secondary: const Text('评论内容'),
            onSendDanmaku: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('打开简介、评论与动态'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('评论'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back reverses the expanding card without leaving playback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final navigator = GlobalKey<NavigatorState>();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var mounts = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Text('Home'),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => TabletPlayerStage(
          playerBuilder: (w, h) => SizedBox(
            width: w,
            height: h,
            child: _MountedPage(
              onInit: () => mounts++,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
          details: ListView(
            controller: scroll,
            children: const [SizedBox(height: 2000)],
          ),
          onSendDanmaku: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final surface = find.byKey(const ValueKey('tablet-content-surface'));
    final initial = tester.getRect(surface);
    final element = tester.element(surface);
    await tester.tap(find.byTooltip('打开简介、评论与动态'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final intermediate = tester.getRect(surface);
    expect(intermediate.width, greaterThan(initial.width));
    expect(intermediate.width, lessThan(1280 * .3 - 24));
    await navigator.currentState!.maybePop();
    await tester.pump();
    expect(tester.getRect(surface), intermediate);
    await tester.pumpAndSettle();
    expect(tester.getRect(surface), initial);
    expect(tester.element(surface), same(element));
    expect(mounts, 1);
    expect(navigator.currentState!.canPop(), isTrue);

    await tester.tap(find.byTooltip('打开简介、评论与动态'));
    await tester.pumpAndSettle();
    scroll.jumpTo(220);
    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开简介、评论与动态'));
    await tester.pumpAndSettle();
    expect(scroll.offset, 220);
    expect(mounts, 1);
    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion settles a tab immediately', (tester) async {
    final index = ValueNotifier(0);
    addTearDown(index.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ValueListenableBuilder(
            valueListenable: index,
            builder: (context, value, _) => NewbiliDestinationView(
              index: value,
              children: const [Text('First'), Text('Second')],
            ),
          ),
        ),
      ),
    );
    index.value = 1;
    await tester.pump();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second').hitTestable(), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('Material bar reserves its own space at text scale $scale', (
      tester,
    ) async {
      const size = Size(375, 812);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
              viewPadding: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.only(bottom: 24),
            ),
            child: MainLayout(
              sideBar: null,
              bottomNav: NewbiliNavigationBar(
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                destinations: [
                  for (final label in ['首页', '动态', '直播', '我的', '搜索'])
                    NavigationDestination(
                      icon: const Icon(Icons.home_outlined),
                      label: label,
                    ),
                ],
              ),
              body: const SizedBox.expand(key: ValueKey('body')),
            ),
          ),
        ),
      );
      final body = tester.getRect(find.byKey(const ValueKey('body')));
      final bar = tester.getRect(find.byType(NewbiliNavigationBar));
      expect(body.bottom, bar.top);
      expect(bar.bottom, size.height);
      expect(bar.width, size.width);
      for (var i = 0; i < 5; i++) {
        final rect = tester.getRect(
          find.byKey(ValueKey('newbili-destination-$i')),
        );
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Material routes preserve parameters, bindings and cancelable predictive back',
    (tester) async {
      final closed = <bool>[];
      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
              },
            ),
          ),
          onInit: () => Get.addPages([
            GetPage(
              name: '/',
              page: () => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      Get.toNamed('/detail?id=42', arguments: 'cover'),
                  child: const Text('Open'),
                ),
              ),
            ),
            GetPage(
              name: '/detail',
              binding: BindingsBuilder(
                () => Get.put<_Lifetime>(_Lifetime(closed)),
              ),
              page: () => Scaffold(
                body: Text('Detail ${Get.parameters['id']} ${Get.arguments}'),
              ),
            ),
          ]),
          initialRoute: '/',
          onGenerateRoute: Routes.generate,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Detail 42 cover'), findsOneWidget);
      expect(Get.isRegistered<_Lifetime>(), isTrue);
      final route = ModalRoute.of(
        tester.element(find.text('Detail 42 cover')),
      ) as NewbiliPageRoute;
      expect(route.allowSnapshotting, isFalse);
      expect(route.reverseTransitionDuration, NewbiliMotion.exit);
      await _back(tester, 'startBackGesture', {
        'touchOffset': [5.0, 300.0],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      await _back(tester, 'updateBackGestureProgress', {
        'touchOffset': [100.0, 300.0],
        'progress': 0.4,
        'swipeEdge': 0,
      });
      await tester.pump(const Duration(milliseconds: 50));
      expect(route.popGestureInProgress, isTrue);
      await _back(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();
      expect(route.isCurrent, isTrue);
      expect(closed, isEmpty);
      await _back(tester, 'startBackGesture', {
        'touchOffset': [5.0, 300.0],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      await _back(tester, 'commitBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(closed, [true]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cover flies in both directions without remounting the player', (
    tester,
  ) async {
    final tag = Object();
    var playerMounts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
            },
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  NewbiliPageRoute(
                    page: () => Scaffold(
                      body: SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: NewbiliCoverHero(
                          tag: tag,
                          child: _MountedPage(
                            onInit: () => playerMounts++,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: 140,
                  height: 90,
                  child: NewbiliCoverHero(
                    tag: tag,
                    radius: 12,
                    child: const ColoredBox(color: Colors.blue),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(playerMounts, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(playerMounts, 1);
    Navigator.of(tester.element(find.byType(_MountedPage))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(playerMounts, 1);
  });
}

Future<void> _back(
  WidgetTester tester,
  String method, [
  Map<String, Object>? data,
]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, data)),
    (_) {},
  );
  await tester.pump();
}

class _Lifetime extends GetxController {
  _Lifetime(this.closed);
  final List<bool> closed;
  @override
  void onClose() {
    closed.add(true);
    super.onClose();
  }
}

class _MountedPage extends StatefulWidget {
  const _MountedPage({super.key, required this.onInit, required this.child});
  final VoidCallback onInit;
  final Widget child;
  @override
  State<_MountedPage> createState() => _MountedPageState();
}

class _MountedPageState extends State<_MountedPage> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
