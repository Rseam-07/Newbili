import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/common/widgets/floating_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/newbili_glass.dart';
import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models/common/theme/theme_color_type.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/models_new/search/search_trending/list.dart';
import 'package:PiliPlus/pages/home/home_header.dart';
import 'package:PiliPlus/pages/mine/view.dart';
import 'package:PiliPlus/pages/search/widgets/hot_keyword.dart';
import 'package:PiliPlus/pages/video/widgets/page_switcher.dart';
import 'package:PiliPlus/pages/rcmd/featured_recommendation.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/action_item.dart';
import 'package:PiliPlus/pages/video/reply/widgets/zan_grpc.dart';
import 'package:PiliPlus/utils/enum_order.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('navigation matches iOS without changing stored enum ordinals', () {
    expect(
      colorThemeTypes[newbiliThemeColorIndex].color,
      const Color(0xFFEE719E),
    );
    expect(colorThemeTypes[1].color, const Color(0xFFFF7299));
    expect(NavigationBarType.defaultTabs.map((tab) => tab.label), [
      '首页',
      '动态',
      '直播',
      '我的',
      '搜索',
    ]);
    expect(
      restoreEnumOrder(NavigationBarType.values, [
        2,
        0,
        1,
      ], NavigationBarType.defaultTabs),
      [
        NavigationBarType.mine,
        NavigationBarType.home,
        NavigationBarType.dynamics,
      ],
    );
    expect(restoreEnumOrder(['a', 'b'], [null, -1, '0', 99, 1, 1, 0], ['a']), [
      'b',
      'a',
    ]);
    expect(restoreEnumOrder(['a', 'b'], [99], ['b']), ['b']);
  });

  test('greeting boundaries and guest wording match iOS', () {
    for (final entry in {
      0: '夜深了',
      5: '早上好',
      10: '中午好',
      13: '下午好',
      18: '晚上好',
      23: '夜深了',
    }.entries) {
      expect(homeGreeting(entry.key, '  ').title, entry.value);
      expect(homeGreeting(entry.key, '  小明 ').title, '${entry.value}，小明');
    }
  });

  test('reply like/dislike transitions adjust the count once', () {
    expect(replyReactionTransition(0, dislike: false), (
      action: 1,
      likeDelta: 1,
    ));
    expect(replyReactionTransition(1, dislike: false), (
      action: 0,
      likeDelta: -1,
    ));
    expect(replyReactionTransition(2, dislike: false), (
      action: 1,
      likeDelta: 1,
    ));
    expect(replyReactionTransition(0, dislike: true), (
      action: 2,
      likeDelta: 0,
    ));
    expect(replyReactionTransition(1, dislike: true), (
      action: 2,
      likeDelta: -1,
    ));
    expect(replyReactionTransition(2, dislike: true), (
      action: 0,
      likeDelta: 0,
    ));
  });

  for (final (size, scale, brightness) in [
    (const Size(375, 812), 1.0, Brightness.light),
    (const Size(375, 812), 2.0, Brightness.dark),
    (const Size(812, 375), 1.0, Brightness.dark),
    (const Size(1024, 768), 2.0, Brightness.light),
  ]) {
    testWidgets('header is centered and usable at $size/$scale/$brightness', (
      tester,
    ) async {
      int selected = 0;
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          size,
          scale,
          brightness,
          DefaultTabController(
            length: 5,
            child: Builder(
              builder: (context) => Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: HomeGreeting(displayName: '一个很长很长的用户名'),
                  ),
                  HomeSectionTabs(
                    controller: DefaultTabController.of(context),
                    labels: const ['推荐', '热门', '分区', '番剧', '影视'],
                    onTap: (value) => selected = value,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final tabBarRect = tester.getRect(find.byType(TabBar));
      expect(tabBarRect.center.dx, closeTo(size.width / 2, .5));
      expect(tabBarRect.height, greaterThanOrEqualTo(48));
      await tester.ensureVisible(find.text('分区'));
      await tester.tap(find.text('分区'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(selected, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('dynamic title and tabs fit their app bar at scale $scale', (
      tester,
    ) async {
      const size = Size(375, 812);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          size,
          scale,
          Brightness.light,
          DefaultTabController(
            length: 5,
            child: Builder(
              builder: (context) => Scaffold(
                primary: false,
                appBar: PreferredSize(
                  preferredSize: Size.fromHeight(
                    NewbiliPageTitle.heightOf(context) +
                        HomeSectionTabs.heightOf(context),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const NewbiliPageTitle(
                        '动态',
                        trailing: SizedBox.square(dimension: 48),
                      ),
                      HomeSectionTabs(
                        controller: DefaultTabController.of(context),
                        labels: const ['全部', '投稿', '番剧', '专栏', 'UP'],
                        onTap: (_) {},
                      ),
                    ],
                  ),
                ),
                body: const SizedBox.expand(key: ValueKey('dynamic-body')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final tabBar = tester.getRect(find.byType(TabBar));
      final body = tester.getRect(find.byKey(const ValueKey('dynamic-body')));
      expect(tabBar.bottom, lessThanOrEqualTo(body.top + .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('static cards do not subscribe to capability changes or blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Size(375, 812),
        1,
        Brightness.light,
        Column(
          children: List.generate(
            8,
            (index) => NewbiliGlassSurface(child: Text('卡片 $index')),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      find.descendant(
        of: find.byType(NewbiliGlassSurface),
        matching: find.byType(ListenableBuilder),
      ),
      findsNothing,
    );
  });

  testWidgets('player glass keeps white controls legible in light appearance', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Size(375, 812),
        1,
        Brightness.light,
        const NewbiliGlassSurface(
          role: NewbiliGlassRole.player,
          child: Icon(Icons.play_arrow, color: Colors.white),
        ),
      ),
    );
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(NewbiliGlassSurface),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    for (final color in decoration.gradient!.colors) {
      final background = Color.alphaBlend(color, Colors.white);
      expect(
        1.05 / (background.computeLuminance() + .05),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets(
    'root background changes do not remount pages or reset selection',
    (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      late StateSetter update;
      Color? background;
      await tester.pumpWidget(
        _app(
          const Size(375, 812),
          1,
          Brightness.light,
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return NewbiliAtmosphere(
                backgroundColor: background,
                child: PageView(
                  controller: controller,
                  children: const [Text('首页内容'), Text('个人页内容')],
                ),
              );
            },
          ),
        ),
      );
      final pageState = tester.state(find.byType(Scrollable));
      controller.jumpToPage(1);
      update(() => background = const Color(0xFFF2F2F7));
      await tester.pump();
      expect(
        identical(tester.state(find.byType(Scrollable)), pageState),
        isTrue,
      );
      expect(controller.page, 1);
      expect(find.text('个人页内容').hitTestable(), findsOneWidget);
      update(() => background = null);
      await tester.pump();
      expect(
        identical(tester.state(find.byType(Scrollable)), pageState),
        isTrue,
      );
      expect(controller.page, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('compact player controls keep 48dp targets at scale $scale', (
      tester,
    ) async {
      const size = Size(375, 812);
      var taps = 0;
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          size,
          scale,
          Brightness.dark,
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                for (final label in ['UP', '关注', '点赞', '投币', '收藏', '分享'])
                  ActionItem(
                    compact: true,
                    icon: const Icon(Icons.favorite_border),
                    semanticsLabel: label,
                    text: '12345',
                    onTap: () => taps++,
                  ),
              ],
            ),
          ),
          reducedMotion: true,
        ),
      );
      final controls = find.byType(InkWell);
      for (var i = 0; i < 6; i++) {
        final rect = tester.getRect(controls.at(i));
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        await tester.tap(controls.at(i));
      }
      expect(taps, 6);
      expect(tester.takeException(), isNull);
    });

    testWidgets('login and settings preserve their actions at scale $scale', (
      tester,
    ) async {
      final logins = <int>[];
      var settingsOpened = false;
      const size = Size(375, 812);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          size,
          scale,
          Brightness.light,
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: NewbiliFormSection(
                children: [
                  NewbiliLoginPanel(onLogin: logins.add),
                  NewbiliSettingsRow(
                    title: '视频与音频设置',
                    subtitle: '画质 · 编解码 · 缓冲 · 音频输出',
                    value: '自动选择适合当前网络的画质',
                    icon: Icons.video_settings,
                    onTap: () => settingsOpened = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      for (final label in ['App 短信验证码登录', 'App 扫码登录', '其他登录方式', '视频与音频设置']) {
        final row = find.widgetWithText(InkWell, label);
        await tester.ensureVisible(row);
        await tester.pump();
        expect(tester.getRect(row).height, greaterThanOrEqualTo(48));
        await tester.tap(find.text(label));
      }
      expect(logins, [1, 2, 3]);
      expect(settingsOpened, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'two-column hot search keeps full keyword actions at scale $scale',
      (tester) async {
        const size = Size(375, 812);
        String? selected;
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const keyword = '一个很长很长的完整搜索关键词';
        await tester.pumpWidget(
          _app(
            size,
            scale,
            Brightness.dark,
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverHotKeyword(
                    hotSearchList: [
                      SearchTrendingItemModel(
                        keyword: keyword,
                        showLiveIcon: true,
                      ),
                      SearchTrendingItemModel(keyword: '音乐现场'),
                    ],
                    onClick: (value) => selected = value,
                  ),
                ),
              ],
            ),
          ),
        );
        final first = find.widgetWithText(InkWell, keyword);
        final second = find.widgetWithText(InkWell, '音乐现场');
        expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
        expect(tester.getRect(first).height, greaterThanOrEqualTo(48));
        await tester.tap(first);
        expect(selected, keyword);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'player switcher retains page state and danmaku actions at scale $scale',
      (tester) async {
        const size = Size(375, 812);
        var sends = 0;
        var toggles = 0;
        var reselects = 0;
        late TabController tabs;
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _app(
            size,
            scale,
            Brightness.light,
            DefaultTabController(
              length: 2,
              child: Builder(
                builder: (context) {
                  tabs = DefaultTabController.of(context);
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: PlayerPageSwitcher(
                        controller: tabs,
                        labels: const ['简介', '评论'],
                        onSendDanmaku: () => sends++,
                        onToggleDanmaku: () => toggles++,
                        showsDanmaku: true,
                        onReselect: () => reselects++,
                      ),
                    ),
                  );
                },
              ),
            ),
            reducedMotion: true,
          ),
        );
        await tester.tap(find.text('评论'));
        await tester.pumpAndSettle();
        expect(tabs.index, 1);
        await tester.tap(find.text('评论'));
        expect(reselects, 1);
        final menu = find.byTooltip('弹幕操作');
        expect(tester.getRect(menu).width, greaterThanOrEqualTo(48));
        expect(tester.getRect(menu).height, greaterThanOrEqualTo(48));
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('隐藏弹幕'));
        await tester.pumpAndSettle();
        expect(toggles, 1);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('发弹幕'));
        await tester.pumpAndSettle();
        expect(sends, 1);
        expect(tabs.index, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'default feed stays double-column with accessible menus at scale $scale',
      (tester) async {
        const size = Size(375, 812);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final items = List.generate(
          4,
          (index) => RcmdVideoItemModel.fromJson({
            'id': index + 1,
            'goto': 'av',
            'duration': 120,
            'title': '视频 $index：保留完整标题及可操作菜单',
            'owner': {'name': '一个很长很长的创作者名字'},
            'stat': {'view': 12345, 'danmaku': 234},
          }),
        );
        await tester.pumpWidget(
          _app(
            size,
            scale,
            Brightness.light,
            GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithExtentAndRatio(
                maxCrossAxisExtent: Pref.defaultRecommendCardWidth,
                crossAxisSpacing: Style.cardSpace,
                mainAxisSpacing: Style.cardSpace,
                childAspectRatio: Style.aspectRatio,
                mainAxisExtent: 90 * scale,
              ),
              itemCount: items.length,
              itemBuilder: (_, index) => VideoCardV(videoItem: items[index]),
            ),
          ),
        );
        await tester.pump();
        final cards = find.byType(VideoCardV);
        expect(
          tester.getTopLeft(cards.at(0)).dy,
          tester.getTopLeft(cards.at(1)).dy,
        );
        expect(
          tester.getTopLeft(cards.at(2)).dy,
          greaterThan(tester.getTopLeft(cards.at(0)).dy),
        );
        final menu = tester.getRect(find.byTooltip('视频操作').first);
        expect(menu.size, const Size(48, 48));
        expect(
          tester
              .getRect(cards.first)
              .contains(menu.bottomRight - const Offset(1, 1)),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('video action row grows with text at scale $scale', (
      tester,
    ) async {
      int taps = 0;
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          const Size(375, 812),
          scale,
          Brightness.light,
          ListView(
            children: [
              Row(
                children: [
                  for (final label in ['点赞', '点踩', '投币', '收藏', '再看', '分享'])
                    ActionItem(
                      icon: const Icon(Icons.favorite_border),
                      selectIcon: const Icon(Icons.favorite),
                      semanticsLabel: label,
                      text: label == '点赞' ? '123.4万' : label,
                      onTap: () => taps++,
                    ),
                ],
              ),
            ],
          ),
          reducedMotion: true,
        ),
      );
      await tester.pump();
      for (final label in ['点赞', '点踩', '投币', '收藏', '再看', '分享']) {
        final button = find.widgetWithText(
          InkWell,
          label == '点赞' ? '123.4万' : label,
        );
        final rect = tester.getRect(button);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(64));
        await tester.tap(button);
      }
      expect(taps, 6);
      expect(tester.takeException(), isNull);
      for (final element in find.byType(AnimatedSwitcher).evaluate()) {
        expect((element.widget as AnimatedSwitcher).duration, Duration.zero);
      }
    });
  }

  testWidgets('held like button exposes its short press to accessibility', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      _app(
        const Size(375, 812),
        1,
        Brightness.light,
        Row(
          children: [
            ActionItem(
              icon: const Icon(Icons.thumb_up_outlined),
              selectIcon: const Icon(Icons.thumb_up),
              semanticsLabel: '点赞',
              onStartTriple: () => events.add('down'),
              onCancelTriple: ([isTapUp = false]) =>
                  events.add(isTapUp ? 'tap' : 'cancel'),
            ),
          ],
        ),
      ),
    );
    tester.semantics.tap(find.semantics.byLabel(RegExp('^点赞')));
    expect(events, ['down', 'tap']);
  }, semanticsEnabled: true);

  testWidgets(
    'five destinations fit a small phone and respect reduced motion',
    (tester) async {
      int selected = 0;
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          const Size(375, 812),
          2,
          Brightness.dark,
          Align(
            alignment: Alignment.bottomCenter,
            child: FloatingNavigationBar(
              selectedIndex: 0,
              onDestinationSelected: (value) => selected = value,
              destinations: [
                for (final tab in NavigationBarType.defaultTabs)
                  NavigationDestination(icon: tab.icon, label: tab.label),
              ],
            ),
          ),
          reducedMotion: true,
        ),
      );
      for (final element in find.byType(AnimatedContainer).evaluate()) {
        expect((element.widget as AnimatedContainer).duration, Duration.zero);
      }
      await tester.tap(find.text('搜索'));
      expect(selected, 4);
      for (final label in NavigationBarType.defaultTabs.map(
        (tab) => tab.label,
      )) {
        final rect = tester.getRect(find.widgetWithText(InkWell, label));
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'carousel pauses offscreen, in background, and on explicit pause',
    (tester) async {
      final items = List.generate(
        3,
        (index) => RcmdVideoItemModel.fromJson({
          'id': index + 1,
          'cid': index + 1,
          'duration': 120,
          'pubdate': 1,
          'title': '推荐视频 $index',
          'owner': {'name': '创作者'},
          'stat': <String, dynamic>{},
        }),
      );
      Widget carousel({bool visible = true, bool reduced = false}) => _app(
        const Size(375, 812),
        1,
        Brightness.light,
        FeaturedRecommendationCarousel(items: items, isVisible: visible),
        reducedMotion: reduced,
      );
      double page() =>
          tester.widget<PageView>(find.byType(PageView)).controller!.page!;

      await tester.pumpWidget(carousel(visible: false));
      await tester.pump(const Duration(seconds: 8));
      expect(page(), 0);
      await tester.pumpWidget(carousel());
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 400));
      expect(page(), 1);
      await tester.tap(find.byTooltip('暂停轮播'));
      await tester.pump(const Duration(seconds: 8));
      expect(page(), 1);
      await tester.tap(find.byTooltip('继续轮播'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 8));
      expect(page(), 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(carousel(reduced: true));
      await tester.pump(const Duration(seconds: 8));
      expect(page(), 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Widget _app(
  Size size,
  double scale,
  Brightness brightness,
  Widget child, {
  bool reducedMotion = false,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFEA6F98),
    brightness: brightness,
  );
  return MaterialApp(
    theme: ThemeData(
      colorScheme: scheme,
      extensions: [NewbiliVisualTheme.from(scheme)],
    ),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(scale),
        disableAnimations: reducedMotion,
      ),
      child: Scaffold(body: child),
    ),
  );
}
