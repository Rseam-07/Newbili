import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/common/widgets/newbili_library.dart';
import 'package:PiliPlus/models/update_notifications.dart';
import 'package:PiliPlus/pages/updates/library.dart';
import 'package:PiliPlus/pages/updates/parts.dart';
import 'package:PiliPlus/pages/updates/view.dart';
import 'package:PiliPlus/services/update_notification_service.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _series = TrackedSeries(
  bvid: 'BV1td8R6EE2L',
  title: '沿海旅行日记',
  cover: '',
  owner: '城市漫游',
  markedAt: 10,
  checkedAt: 20,
  known: [101, 202, 303],
  pages: [
    TrackedPage(cid: 101, page: 1, title: '出发'),
    TrackedPage(cid: 303, page: 2, title: '海边日落'),
  ],
);
const _other = TrackedSeries(
  bvid: 'BV1hz4y157kz',
  title: '周末烘焙课堂',
  cover: '',
  owner: '厨房笔记',
  markedAt: 30,
  checkedAt: 40,
  pages: [],
);

Map<String, Object?> _snapshot({
  List<TrackedSeries> tracks = const [],
  int revision = 1,
}) => {
  'revision': revision,
  'level': 'off',
  'tracks': tracks.map((item) => item.toJson()).toList(),
  'permission': false,
  'seriesPermission': false,
  'upPermission': false,
  'loggedIn': false,
  'checking': false,
  'lastChecked': 0,
  'status': '已检查，目前没有新内容',
  'recent': [],
};

Widget _app(Widget content, {MediaQueryData? media, GlobalKey? boundary}) =>
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFEE719E),
            brightness: media?.platformBrightness ?? Brightness.light,
          ).copyWith(primary: const Color(0xFFEE719E)),
          fontFamily: 'NewbiliPreview',
        ),
        builder: media == null
            ? null
            : (context, child) => MediaQuery(data: media, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: NewbiliFormStyle.background(context),
            appBar: AppBar(title: const Text('我的追更')),
            body: content,
          ),
        ),
      ),
    );

TrackedSeriesContent _content({
  List<TrackedSeries> tracks = const [_series, _other],
  Future<TrackedSeries?> Function(String)? onRemove,
  Future<bool> Function(TrackedSeries)? onRestore,
  void Function(TrackedSeries, TrackedPage?)? onOpen,
}) => TrackedSeriesContent(
  state: UpdateNotificationState(tracks: tracks),
  busy: false,
  onRefresh: () async {},
  onRemove: onRemove ?? (_) async => null,
  onRestore: onRestore ?? (_) async => false,
  onOpen: onOpen ?? (_, _) {},
);

Future<void> _menu(WidgetTester tester, String title, String action) async {
  final trigger = find.byTooltip('选集与追更选项：$title');
  await tester.ensureVisible(trigger);
  await tester.tap(trigger);
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.rseam07.newbili/updates');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const fontPath = String.fromEnvironment('NEWBILI_VISUAL_FONT');
  const outputPath = String.fromEnvironment('NEWBILI_VISUAL_OUTPUT');
  setUpAll(() async {
    if (fontPath.isEmpty) return;
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in fonts) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    await ui.loadFontFromList(
      await File(fontPath).readAsBytes(),
      fontFamily: 'NewbiliPreview',
    );
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('tracked snapshots round-trip CID history and original dates', () {
    final restored = TrackedSeries.fromJson(_series.toJson());
    expect(restored.toJson(), _series.toJson());
    expect(restored.pageCount, 2);
    expect(restored.pages.last.cid, 303);
    expect(restored.known, contains(202));
    final legacy = Map<String, dynamic>.of(_series.toJson())
      ..remove('known')
      ..remove('markedAt');
    expect(TrackedSeries.fromJson(legacy).known, isEmpty);
  });

  test('removal returns native snapshot, not the stale UI snapshot; retry is guarded', () async {
    final gate = Completer<void>();
    var calls = 0;
    Map<String, dynamic>? restored;
    final removed = Map<String, dynamic>.of(_series.toJson())
      ..['known'] = [101, 202, 303, 404];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'unmark') {
        calls++;
        await gate.future;
        return jsonEncode({..._snapshot(), 'removed': removed});
      }
      restored = jsonDecode(
        (call.arguments as Map)['snapshot'] as String,
      ) as Map<String, dynamic>;
      return jsonEncode(
        _snapshot(tracks: [TrackedSeries.fromJson(restored!)], revision: 2),
      );
    });
    final service = UpdateNotificationService();
    service.state.value = const UpdateNotificationState(tracks: [_series]);
    final first = service.remove(_series.bvid);
    expect(await service.remove(_series.bvid), isNull);
    gate.complete();
    final snapshot = (await first)!;
    expect(calls, 1);
    expect(service.pending, isEmpty);
    expect(snapshot.known, contains(404));
    expect(await service.restore(snapshot), true);
    expect(restored, removed);
  });

  test(
    'failed removal preserves the list; restore failure unlocks explicit retry',
    () async {
      var fail = true;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (fail) throw PlatformException(code: 'disk_full');
        return jsonEncode(_snapshot(tracks: [_series]));
      });
      final service = UpdateNotificationService();
      service.state.value = const UpdateNotificationState(tracks: [_series]);
      expect(await service.remove(_series.bvid), isNull);
      expect(service.state.value.tracks, [_series]);
      expect(service.pending, isEmpty);
      expect(await service.restore(_series), false);
      expect(service.pending, isEmpty);
      fail = false;
      expect(await service.restore(_series), true);
      expect(service.error.value, isNull);
    },
  );

  test(
    'late native response cannot reinsert a different removed item in UI',
    () async {
      final firstGate = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        final bvid = (call.arguments as Map)['bvid'];
        if (bvid == _series.bvid) {
          await firstGate.future;
          return jsonEncode({
            ..._snapshot(tracks: [_other], revision: 1),
            'removed': _series.toJson(),
          });
        }
        return jsonEncode({
          ..._snapshot(revision: 2),
          'removed': _other.toJson(),
        });
      });
      final service = UpdateNotificationService();
      final first = service.remove(_series.bvid);
      await service.remove(_other.bvid);
      firstGate.complete();
      expect((await first)!.bvid, _series.bvid);
      expect(service.state.value.tracks, isEmpty);
      expect(service.pending, isEmpty);
    },
  );

  testWidgets(
    'manual update check remains usable without notification permission',
    (tester) async {
      var checks = 0;
      await tester.pumpWidget(
        _app(
          UpdateNotificationContent(
            state: const UpdateNotificationState(tracks: [_series]),
            busy: false,
            onSelectLevel: (_) {},
            onRequestPermission: () {},
            onSystemSettings: () {},
            onRefresh: () => checks++,
            onLibrary: () {},
            onVideo: (_, _) {},
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('立即检查更新'), 200);
      await tester.tap(find.text('立即检查更新'));
      expect(checks, 1);
      expect(find.text('仅更新 App 内记录，不发送系统通知'), findsOneWidget);
    },
  );

  testWidgets(
    'search works locally by title, uploader and BV; clear restores list',
    (tester) async {
      await tester.pumpWidget(_app(_content()));
      for (final query in ['旅行', '城市漫游', 'bv1td8r6ee2l']) {
        await tester.enterText(find.byType(TextField), query);
        await tester.pumpAndSettle();
        expect(find.byType(NewbiliLibraryTile), findsOneWidget);
        expect(find.text(_series.title), findsOneWidget);
      }
      await tester.enterText(find.byType(TextField), '没有这部');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的追更'), findsOneWidget);
      await tester.tap(find.byTooltip('清除搜索'));
      await tester.pumpAndSettle();
      expect(find.byType(NewbiliLibraryTile), findsNWidgets(2));
    },
  );

  testWidgets(
    'part selection preserves CID through reverse and search, closes only its sheet',
    (tester) async {
      TrackedPage? opened;
      var opens = 0;
      await tester.pumpWidget(
        _app(
          _content(
            onOpen: (_, page) {
              opened = page;
              opens++;
            },
          ),
        ),
      );
      await _menu(tester, _series.title, '选集');
      expect(opens, 0);
      await tester.tap(find.byTooltip('正序 · 切换倒序'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListTile>(find.byType(ListTile).first).key,
        const ValueKey(303),
      );
      final field = find.descendant(
        of: find.byType(TrackedPartsSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, '日落');
      await tester.pumpAndSettle();
      await tester.tap(find.text('P2 · 海边日落'));
      await tester.pumpAndSettle();
      expect(opened?.cid, 303);
      expect(opens, 1);
      expect(find.byType(TrackedPartsSheet), findsNothing);
      expect(find.byType(TrackedSeriesContent), findsOneWidget);
      await _menu(tester, _series.title, '播放最后一 P');
      expect(opened?.cid, 303);
      expect(opens, 2);
    },
  );

  testWidgets(
    'cancel is harmless; remove is confirmed; undo retains snapshot until success',
    (tester) async {
      var tracks = [_series];
      var removals = 0;
      var restores = 0;
      final gate = Completer<bool>();
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, update) => _content(
              tracks: tracks,
              onRemove: (bvid) async {
                removals++;
                update(() => tracks = []);
                return _series;
              },
              onRestore: (snapshot) async {
                expect(snapshot.known, [101, 202, 303]);
                restores++;
                if (restores == 1) return gate.future;
                update(() => tracks = [snapshot]);
                return true;
              },
            ),
          ),
        ),
      );
      await _menu(tester, _series.title, '取消追更');
      await tester.tap(find.text('保留'));
      await tester.pumpAndSettle();
      expect(removals, 0);
      await _menu(tester, _series.title, '取消追更');
      await tester.tap(find.widgetWithText(TextButton, '取消追更'));
      await tester.pumpAndSettle();
      expect(removals, 1);
      expect(find.byType(NewbiliLibraryTile), findsNothing);
      final undo = find.widgetWithText(TextButton, '撤销');
      await tester.tap(undo);
      await tester.tap(undo);
      await tester.pump();
      expect(restores, 1);
      gate.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('恢复失败，请再次点击撤销'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '撤销'));
      await tester.pumpAndSettle();
      expect(restores, 2);
      expect(find.byType(NewbiliLibraryTile), findsOneWidget);
      expect(find.text('撤销'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (name, size, scale, brightness, keyboard) in [
    ('light', const Size(375, 812), 1.0, Brightness.light, 0.0),
    ('dark', const Size(375, 812), 1.0, Brightness.dark, 0.0),
    ('landscape', const Size(812, 375), 1.0, Brightness.dark, 160.0),
    ('large-text', const Size(320, 812), 2.0, Brightness.light, 260.0),
    ('tablet', const Size(1024, 768), 3.0, Brightness.dark, 260.0),
  ]) {
    testWidgets('tracking library and parts adapt to $name', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final boundary = GlobalKey();
      await tester.pumpWidget(
        _app(
          _content(),
          boundary: boundary,
          media: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            platformBrightness: brightness,
            disableAnimations: true,
            viewPadding: const EdgeInsets.only(bottom: 24),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(tester, boundary, outputPath, 'tracking-$name');
      await _menu(tester, _series.title, '选集');
      // Exercise real route content under keyboard insets without a keyboard screenshot.
      await tester.pumpWidget(
        _app(
          _content(),
          boundary: boundary,
          media: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            platformBrightness: brightness,
            disableAnimations: true,
            viewPadding: const EdgeInsets.only(bottom: 24),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final part = find.text('P2 · 海边日落');
      final scroll = find
          .descendant(
            of: find.byType(TrackedPartsSheet),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .first;
      await tester.scrollUntilVisible(part, 140, scrollable: scroll);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.ancestor(of: part, matching: find.byType(ListTile)))
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
      await _capture(tester, boundary, outputPath, 'tracking-$name-parts');
      await tester.tap(part);
      await tester.pumpAndSettle();
      expect(find.byType(TrackedSeriesContent), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String directory,
  String name,
) async {
  if (directory.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$directory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
