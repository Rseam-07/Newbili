import 'package:PiliPlus/plugin/pl_player/widgets/compact_player_bar.dart';
import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/common/widgets/main_layout.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/pages/rcmd/featured_recommendation.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/pages/rcmd/view.dart';
import 'package:get/get.dart';
import 'package:PiliPlus/common/widgets/newbili_cover_hero.dart';
import 'package:PiliPlus/common/widgets/newbili_destination_view.dart';
import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/common/widgets/newbili_navigation_bar.dart';
import 'package:PiliPlus/pages/home/home_header.dart';
import 'package:PiliPlus/pages/video/widgets/page_switcher.dart';
import 'package:PiliPlus/pages/video/widgets/tablet_player_stage.dart';
import 'package:PiliPlus/router/newbili_page_route.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

const output = String.fromEnvironment('NEWBILI_VISUAL_OUTPUT');
const fontPath = String.fromEnvironment('NEWBILI_VISUAL_FONT');
const coverPath = String.fromEnvironment('NEWBILI_VISUAL_COVERS');
final _art = <String, Uint8List>{};
const _files = [
  'spring.jpg',
  'wing-it.jpg',
  'sintel.jpg',
  'bunny-meadow.png',
  'overgrown.jpg',
  'singularity.jpg',
  'bunny.png',
];
final _items =
    [
          '《春天》：穿过森林，让四季再次苏醒',
          'WING IT!｜一只倔强的猫，和一次奇妙飞行',
          '《寻龙记》：关于陪伴与成长的冒险',
          '大雄兔的快乐一天 · 开源动画短片',
          'OVERGROWN：走进想象中的奇幻世界',
          'SINGULARITY｜手绘风格的太空冒险',
          '角色动画练习：用表情讲一个故事',
        ].indexed
        .map(
          (entry) => RcmdVideoItemModel.fromJson({
            'id': entry.$1 + 1,
            'cid': entry.$1 + 1,
            'goto': 'av',
            'duration': 360 + entry.$1 * 53,
            'pic': '',
            'title': entry.$2,
            'owner': {'name': 'Blender Studio', 'mid': 0},
            'stat': {
              'view': 124000 - entry.$1 * 15000,
              'danmaku': 1040 + entry.$1 * 91,
            },
          }),
        )
        .toList();
Widget _artwork(BaseRcmdVideoItemModel item) {
  final file =
      _files[_items
          .indexWhere((candidate) => identical(candidate, item))
          .clamp(0, _files.length - 1)];
  return _art.containsKey(file)
      ? Image.memory(_art[file]!, fit: BoxFit.cover, gaplessPlayback: true)
      : const ColoredBox(color: Color(0xFF526A79));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory settings;
  setUpAll(() async {
    settings = await Directory.systemTemp.createTemp(
      'newbili-material-visual-',
    );
    Hive.init(settings.path);
    GStorage.setting = await Hive.openBox('setting');
    GStorage.video = await Hive.openBox('video');
    GStorage.localCache = await Hive.openBox('localCache');
    if (coverPath.isNotEmpty) {
      for (final file in _files) {
        _art[file] = await File('$coverPath/$file').readAsBytes();
      }
    }
    if (fontPath.isNotEmpty) {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final entry in manifest) {
        final loader = FontLoader(entry['family'] as String);
        for (final font in entry['fonts'] as List) {
          loader.addFont(rootBundle.load(font['asset'] as String));
        }
        await loader.load();
      }
      await ui.loadFontFromList(
        await File(fontPath).readAsBytes(),
        fontFamily: 'PreviewCJK',
      );
      await GStorage.setting.put(SettingBoxKey.appFont, 'PreviewCJK');
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await settings.delete(recursive: true);
  });

  for (final (name, brightness, width, scale) in [
    ('uwp-phone-light', Brightness.light, 375.0, 1.0),
    ('uwp-phone-dark', Brightness.dark, 375.0, 1.0),
    ('uwp-large-text', Brightness.light, 320.0, 2.0),
    ('uwp-tablet-light', Brightness.light, 1280.0, 1.0),
    ('uwp-tablet-dark', Brightness.dark, 1280.0, 1.0),
    ('uwp-tablet-compact', Brightness.light, 1024.0, 1.0),
  ]) {
    testWidgets(name, (tester) async {
      final key = GlobalKey();
      final size = Size(width, 812);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(key, size, scale, brightness));
      await _loadArtwork(tester, key);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (output.isNotEmpty) await _capture(tester, key, '$name.png');
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final width in [375.0, 1024.0]) {
    testWidgets(
      'real recommendation page renders loading, success, empty and error at $width',
      (tester) async {
        final key = GlobalKey();
        final size = Size(width, 812);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = Get.put<RcmdController>(_RcmdFixtureController());
        await tester.pumpWidget(
          _app(key, size, 1, Brightness.light, page: const RcmdPage()),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        controller.enableSaveLastData = true;
        expect(controller.handleError('offline'), isFalse);
        controller.loadingState.value = Success(_items);
        await tester.pumpAndSettle();
        expect(controller.handleError('offline'), isTrue);
        controller.requestError.value = '加载失败，请检查网络后重试';
        await tester.pumpAndSettle();
        expect(find.text('重试，保留当前内容'), findsOneWidget);
        if (output.isNotEmpty) await _capture(tester, key, 'retry-$width.png');
        await tester.tap(find.text('重试，保留当前内容'));
        await tester.pumpAndSettle();
        expect(controller.requestError.value, isNull);
        expect(find.text(_items.first.title), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);
        controller.loadingState.value = const Success([]);
        expect(controller.handleError('offline'), isFalse);
        await tester.pumpAndSettle();
        expect(find.text('没有数据'), findsOneWidget);
        controller.loadingState.value = const Error('连接失败');
        await tester.pumpAndSettle();
        expect(find.text('连接失败'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        Get.delete<RcmdController>();
      },
    );
  }

  testWidgets('tablet subpage and player keep the content stage visible', (
    tester,
  ) async {
    final key = GlobalKey();
    const size = Size(1280, 812);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(key, size, 1, Brightness.dark));
    await _loadArtwork(tester, key);
    await tester.pumpAndSettle();
    await tester.tap(find.text('动态'));
    await tester.pumpAndSettle();
    expect(find.text('播放视频').hitTestable(), findsOneWidget);
    if (output.isNotEmpty) await _capture(tester, key, 'uwp-tablet-pane.png');
    await tester.tap(find.byTooltip('收起副页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('播放视频'));
    await tester.pumpAndSettle();
    if (output.isNotEmpty) await _capture(tester, key, 'uwp-tablet-player.png');
    var frame = 0;
    Future<void> frames(int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        if (output.isNotEmpty) {
          await _capture(
            tester,
            key,
            'tablet-motion/frame-${(frame++).toString().padLeft(3, '0')}.png',
          );
        }
        expect(tester.takeException(), isNull);
      }
    }

    await frames(12);
    await tester.tap(find.byTooltip('打开简介、评论与动态'));
    await tester.pump();
    await frames(20);
    if (output.isNotEmpty) {
      await _capture(tester, key, 'uwp-tablet-player-details.png');
    }
    await tester.tap(find.text('评论'));
    await tester.pump();
    await frames(20);
    if (output.isNotEmpty) {
      await _capture(tester, key, 'uwp-tablet-player-comments.png');
    }
    await tester.tap(find.text('动态'));
    await tester.pump();
    await frames(20);
    if (output.isNotEmpty) {
      await _capture(tester, key, 'uwp-tablet-player-feed.png');
    }
    await tester.tap(find.byTooltip('收起内容卡片'));
    await tester.pump();
    await frames(20);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('record production Material cover motion', (tester) async {
    final key = GlobalKey();
    const size = Size(375, 812);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(key, size, 1, Brightness.light));
    await _loadArtwork(tester, key);
    await tester.pumpAndSettle();
    var frame = 0;
    Future<void> frames(int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        await _capture(
          tester,
          key,
          'motion/frame-${(frame++).toString().padLeft(3, '0')}.png',
        );
        expect(tester.takeException(), isNull);
      }
    }

    await frames(20);
    await tester.tap(find.byKey(const ValueKey('open-video')));
    await tester.pump();
    await frames(30);
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await frames(25);
    await tester.pumpWidget(const SizedBox());
  }, skip: output.isEmpty);
}

Widget _app(
  GlobalKey key,
  Size size,
  double scale,
  Brightness brightness, {
  Widget? page,
}) {
  final theme = ThemeUtils.getThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFEE719E),
      brightness: brightness,
    ),
    isDynamic: false,
    isDark: brightness == Brightness.dark,
  );
  return RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      onGenerateRoute: (settings) => NewbiliPageRoute(
        settings: settings,
        page: () => page ?? const _Preview(),
      ),
    ),
  );
}

Future<void> _loadArtwork(WidgetTester tester, GlobalKey key) async {
  await tester.runAsync(() async {
    for (final bytes in _art.values) {
      await precacheImage(MemoryImage(bytes), key.currentContext!);
    }
  });
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final file = File('$output/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data.buffer.asUint8List());
    image.dispose();
  });
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  int selected = 0;
  static const labels = ['首页', '动态', '直播', '我的', '搜索'];
  static const icons = [
    Icons.home_outlined,
    Icons.dynamic_feed_outlined,
    Icons.live_tv_outlined,
    Icons.account_circle_outlined,
    Icons.search_rounded,
  ];

  void _open(BaseRcmdVideoItemModel item, Object tag) =>
      Navigator.of(context).push(
        NewbiliPageRoute(
          page: () => _Detail(tag: tag, item: item),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    return Material(
      child: MainLayout(
        sideBar: null,
        bottomNav: wide
            ? null
            : NewbiliNavigationBar(
                selectedIndex: selected,
                onDestinationSelected: (i) => setState(() => selected = i),
                destinations: [
                  for (var i = 0; i < 5; i++)
                    NavigationDestination(
                      icon: Icon(icons[i]),
                      label: labels[i],
                    ),
                ],
              ),
        body: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            children: [
              if (wide)
                NewbiliTabletToolbar(
                  labels: labels,
                  selectedIndex: selected,
                  onSelected: (i) => setState(() => selected = i),
                  onSearch: () {},
                  trailing: const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                ),
              Expanded(
                child: NewbiliDestinationView(
                  index: selected,
                  baseIndex: MediaQuery.sizeOf(context).width >= 1100
                      ? 0
                      : null,
                  paneTitle: labels[selected],
                  onClosePane: () => setState(() => selected = 0),
                  children: [
                    DefaultTabController(
                      length: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!wide)
                            NewbiliHomeToolbar(
                              onSearch: () {},
                              trailing: IconButton(
                                onPressed: () {},
                                tooltip: '消息',
                                icon: const Icon(
                                  Icons.notifications_none_rounded,
                                  size: 22,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Builder(
                              builder: (context) => HomeSectionTabs(
                                controller: DefaultTabController.of(context),
                                labels: const ['推荐', '热门', '分区', '番剧', '影视'],
                                onTap: (_) {},
                              ),
                            ),
                          ),
                          Expanded(
                            child: wide
                                ? SingleChildScrollView(
                                    child: TabletRecommendationStage(
                                      items: _items,
                                      onRefresh: () {},
                                      onLoadMore: () {},
                                      coverBuilder: _artwork,
                                      onOpen: _open,
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      16,
                                    ),
                                    gridDelegate:
                                        SliverGridDelegateWithExtentAndRatio(
                                          maxCrossAxisExtent:
                                              MediaQuery.textScalerOf(context)
                                                      .scale(14) >
                                                  20
                                              ? 10000
                                              : 240,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 20,
                                          childAspectRatio: 16 / 9,
                                          mainAxisExtent:
                                              VideoCardV.metadataHeightOf(
                                                context,
                                              ),
                                        ),
                                    itemCount: _items.length,
                                    itemBuilder: (context, index) => VideoCardV(
                                      key: index == 0
                                          ? const ValueKey('open-video')
                                          : null,
                                      videoItem: _items[index],
                                      coverBuilder: (_) =>
                                          _artwork(_items[index]),
                                      onOpen: (tag) =>
                                          _open(_items[index], tag),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    _FeedPreview(items: _items),
                    for (final label in labels.skip(2))
                      ListView(children: [NewbiliPageTitle(label)]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedPreview extends StatelessWidget {
  const _FeedPreview({required this.items});
  final List<BaseRcmdVideoItemModel> items;
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(20),
    itemCount: 3,
    separatorBuilder: (_, _) => const Divider(height: 32),
    itemBuilder: (context, i) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person_outline_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              items[i].owner.name!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(items[i].title, style: const TextStyle(fontSize: 14, height: 1.5)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(aspectRatio: 16 / 9, child: _artwork(items[i])),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final icon in [
              Icons.share_outlined,
              Icons.chat_bubble_outline_rounded,
              Icons.thumb_up_outlined,
            ])
              Icon(
                icon,
                size: 18,
                color: ColorScheme.of(context).onSurfaceVariant,
              ),
          ],
        ),
      ],
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.tag, required this.item});
  final Object tag;
  final BaseRcmdVideoItemModel item;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 840) {
      return Scaffold(
        body: SafeArea(
          child: TabletPlayerStage(
            playerBuilder: (width, height) => SizedBox(
              width: width,
              height: height,
              child: NewbiliCoverHero(
                tag: tag,
                radius: 10,
                child: _previewPlayer(item),
              ),
            ),
            details: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(item.owner.name!, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                Text(
                  '12.4万次观看 · 1040条弹幕',
                  style: TextStyle(
                    fontSize: 12,
                    color: ColorScheme.of(context).onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    for (final (icon, label) in [
                      (Icons.thumb_up_outlined, '点赞'),
                      (Icons.paid_outlined, '投币'),
                      (Icons.star_border_rounded, '收藏'),
                      (Icons.share_outlined, '分享'),
                    ])
                      TextButton.icon(
                        onPressed: () {},
                        icon: Icon(icon, size: 20),
                        label: Text(label),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Blender 开源动画短片。一个女孩、一只小狗，和森林中等待苏醒的春天。',
                  style: TextStyle(fontSize: 14, height: 1.8),
                ),
                const SizedBox(height: 24),
                const Text(
                  '相关推荐',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                for (final related in _items.skip(1))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: LayoutBuilder(
                      builder: (context, box) => SizedBox(
                        height:
                            box.maxWidth * 9 / 16 +
                            VideoCardV.metadataHeightOf(context),
                        child: VideoCardV(
                          videoItem: related,
                          coverBuilder: (_) => _artwork(related),
                          onOpen: (_) {},
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            secondary: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '评论 1,040',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                for (final text in ['这段光影和角色表情太细腻了。', '春天终于到了。', '感谢分享开源动画！'])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: const Text('动画爱好者'),
                    subtitle: Text(text),
                  ),
              ],
            ),
            extraPane: _FeedPreview(items: _items),
            onSendDanmaku: () {},
          ),
        ),
      );
    }
    return _phone(context);
  }

  Widget _phone(BuildContext context) => Scaffold(
    body: SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: NewbiliCoverHero(
                    tag: tag,
                    child: _previewPlayer(item),
                  ),
                ),
                const Positioned(
                  left: 4,
                  top: 4,
                  child: BackButton(color: Colors.white),
                ),
              ],
            ),
            Builder(
              builder: (context) => PlayerPageSwitcher(
                controller: DefaultTabController.of(context),
                labels: const ['简介', '评论'],
                onSendDanmaku: () {},
                onToggleDanmaku: () {},
                showsDanmaku: true,
                onReselect: () {},
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${item.owner.name}  ·  12.4万观看',
                    style: TextStyle(
                      fontSize: 12,
                      color: ColorScheme.of(context).onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (final (icon, label) in [
                        (Icons.thumb_up_outlined, '点赞'),
                        (Icons.paid_outlined, '投币'),
                        (Icons.star_border_rounded, '收藏'),
                        (Icons.share_outlined, '分享'),
                      ])
                        Column(
                          children: [
                            IconButton(
                              onPressed: () {},
                              icon: Icon(icon, size: 22),
                            ),
                            Text(label, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                    ],
                  ),
                  const Divider(height: 40),
                  const Text(
                    '接下来播放',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height:
                        (MediaQuery.sizeOf(context).width - 40) * 9 / 16 +
                        VideoCardV.metadataHeightOf(context),
                    child: VideoCardV(
                      videoItem: _items[1],
                      coverBuilder: (_) => _artwork(_items[1]),
                      onOpen: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RcmdFixtureController extends RcmdController {
  @override
  Future<void> queryData([bool isRefresh = true]) async {}
  @override
  Future<void> onLoadMore() async {}
  @override
  Future<void> onRefresh() async {
    requestError.value = null;
  }
}

Widget _previewPlayer(BaseRcmdVideoItemModel item) => Stack(
  fit: StackFit.expand,
  children: [
    const ColoredBox(color: Colors.black),
    Center(
      child: AspectRatio(aspectRatio: 16 / 9, child: _artwork(item)),
    ),
    Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xBF000000)],
          ),
        ),
        child: CompactPlayerBar(
          playing: true,
          time: '01:24',
          total: '12:30',
          fullscreen: false,
          onPlay: () {},
          onMore: () {},
          onFullscreen: () {},
          timeline: ProgressBar(
            progress: 84,
            total: 750,
            buffered: 200,
            barHeight: 3,
            thumbRadius: 5,
            thumbGlowRadius: 16,
            onDragStart: (_) {},
            onSeek: (_) {},
            baseBarColor: Colors.white24,
            progressBarColor: const Color(0xFFF8A3BD),
            bufferedBarColor: Colors.white54,
            thumbColor: Colors.white,
            thumbGlowColor: Colors.white24,
          ),
        ),
      ),
    ),
  ],
);
