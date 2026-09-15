import 'dart:async';
import 'dart:convert' show jsonDecode;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/publish/publish_route.dart';
import 'package:PiliPlus/pages/video/send_danmaku/view.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  _testComposer(
    'button and keyboard share one flight; failure retains draft for explicit retry',
    (tester) async {
      final pending = Completer<LoadingState<void>>();
      final requests = <DanmakuDraft>[];
      var sent = 0;
      String? saved;
      await _open(
        tester,
        SendDanmakuPanel(
          progress: 83000,
          onSave: (value) => saved = value,
          onSent: () => sent++,
          onSend: (draft) {
            requests.add(draft);
            return requests.length == 1
                ? pending.future
                : Future.value(const Success(null));
          },
        ),
      );
      expect(find.text('发送到 01:23 · 关闭后保留草稿'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  这一刻真好  ');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '发送'));
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(requests, hasLength(1));
      expect(requests.single.text, '这一刻真好');
      expect(find.text('发送中'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '关闭并保留草稿',
              ),
            )
            .onPressed,
        isNull,
      );
      await Navigator.of(tester.element(find.byType(SendDanmakuPanel)))
          .maybePop();
      await tester.pump();
      expect(find.byType(SendDanmakuPanel), findsOneWidget);

      pending.complete(const Error('发送过于频繁，请稍后再试'));
      await tester.pumpAndSettle();
      expect(find.textContaining('草稿已保留'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '  这一刻真好  ',
      );
      expect(sent, 0);
      await tester.tap(find.widgetWithText(FilledButton, '发送'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(sent, 1);
      expect(saved, '');
      expect(find.byType(SendDanmakuPanel), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  _testComposer(
    'empty input cannot send; closing preserves unsent text and style',
    (tester) async {
      var calls = 0;
      String? saved;
      DanmakuStyle? style;
      await _open(
        tester,
        SendDanmakuPanel(
          progress: 0,
          initialValue: '未发出的草稿',
          onSend: (_) async {
            calls++;
            return const Success(null);
          },
          onSave: (value) => saved = value,
          onSaveDmConfig: (value) => style = value,
        ),
      );
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      expect(calls, 0);
      await tester.enterText(find.byType(TextField), '稍后继续写');
      await tester.tap(find.text('弹幕样式'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('顶部'));
      await tester.tap(find.text('顶部'));
      await tester.pump();
      await tester.ensureVisible(find.bySemanticsLabel('红色'));
      await tester.tap(find.bySemanticsLabel('红色'));
      await tester.pump();
      await tester.ensureVisible(find.byTooltip('关闭并保留草稿'));
      await tester.tap(find.byTooltip('关闭并保留草稿'));
      await tester.pumpAndSettle();
      expect(saved, '稍后继续写');
      expect(style, (mode: 5, fontSize: 25, color: const Color(0xFFFE0302)));
    },
  );

  _testComposer(
    'exceptions release the send lock and retain inline recovery instructions',
    (tester) async {
      await _open(
        tester,
        SendDanmakuPanel(
          progress: 0,
          initialValue: '保留我',
          onSend: (_) async => throw const SocketException('offline'),
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, '发送'));
      await tester.pumpAndSettle();
      expect(find.textContaining('无法确认发送结果'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '保留我',
      );
      expect(tester.takeException(), isNull);
    },
  );

  _testComposer(
    'late response after forced route disposal does not access disposed input or pop another page',
    (tester) async {
      final pending = Completer<LoadingState<void>>();
      String? saved;
      var sent = 0;
      await _open(
        tester,
        SendDanmakuPanel(
          progress: 0,
          initialValue: '还在发送',
          onSend: (_) => pending.future,
          onSave: (value) => saved = value,
          onSent: () => sent++,
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, '发送'));
      await tester.pumpWidget(const SizedBox());
      pending.complete(const Success(null));
      await tester.pumpAndSettle();
      expect(saved, '还在发送');
      expect(sent, 0);
      expect(tester.takeException(), isNull);
    },
  );

  _testComposer(
    'reopening restores all draft styles including custom and VIP colors',
    (tester) async {
      DanmakuDraft? sent;
      await _open(
        tester,
        SendDanmakuPanel(
          progress: 0,
          initialValue: '样式测试',
          isVip: true,
          dmConfig: (mode: 4, fontSize: 18, color: Colors.transparent),
          onSend: (draft) async {
            sent = draft;
            return const Success(null);
          },
        ),
      );
      await tester.tap(find.text('弹幕样式'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('会员渐变色'), findsOneWidget);
      expect(find.byTooltip('自定义颜色'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(FilledButton, '发送'));
      await tester.tap(find.widgetWithText(FilledButton, '发送'));
      await tester.pumpAndSettle();
      expect(sent, (
        text: '样式测试',
        mode: 4,
        fontSize: 18,
        color: Colors.transparent,
      ));
    },
  );

  _testComposer(
    'custom color picker closes only itself and sends the chosen color',
    (tester) async {
      DanmakuDraft? sent;
      await _open(
        tester,
        SendDanmakuPanel(
          progress: 0,
          initialValue: '自定义颜色测试',
          onSend: (draft) async {
            sent = draft;
            return const Success(null);
          },
        ),
      );
      await tester.tap(find.text('弹幕样式'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('自定义颜色'));
      await tester.tap(find.byTooltip('自定义颜色'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'ABCDEF',
      );
      await tester.pump();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SendDanmakuPanel), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '发送'));
      await tester.pumpAndSettle();
      expect(sent?.color, const Color(0xFFABCDEF));
    },
  );

  for (final (name, size, scale, brightness, keyboard) in [
    ('composer-light', const Size(375, 812), 1.0, Brightness.light, 300.0),
    ('composer-dark', const Size(375, 812), 1.0, Brightness.dark, 300.0),
    ('composer-landscape', const Size(812, 375), 1.0, Brightness.dark, 180.0),
    ('composer-large-text', const Size(320, 812), 2.0, Brightness.light, 0.0),
    ('composer-tablet', const Size(1024, 768), 3.0, Brightness.dark, 260.0),
  ]) {
    _testComposer('$name supports keyboard, scrolling and reduced motion', (
      tester,
    ) async {
      final key = GlobalKey();
      await _open(
        tester,
        SendDanmakuPanel(
          progress: 83000,
          initialValue: '这一刻，值得一起分享',
          onSend: (_) async => const Error('网络中断，请先检查是否已发送'),
        ),
        size: size,
        scale: scale,
        brightness: brightness,
        keyboard: keyboard,
        boundaryKey: key,
      );
      expect(tester.takeException(), isNull);
      final send = find.widgetWithText(FilledButton, '发送');
      if (outputPath.isNotEmpty) {
        await _capture(tester, key, '$outputPath/$name.png');
      }
      // The primary action stays above the keyboard without scrolling to it.
      expect(send.hitTestable(), findsOneWidget);
      expect(tester.getSize(send).height, greaterThanOrEqualTo(48));
      expect(
        tester.getRect(send).bottom,
        lessThanOrEqualTo(size.height - keyboard),
      );
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.textContaining('草稿已保留'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('弹幕样式'));
      await tester.tap(find.text('弹幕样式'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.bySemanticsLabel('红色'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.bySemanticsLabel('红色')), const Size(48, 48));
      expect(send.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      if (outputPath.isNotEmpty) {
        await _capture(tester, key, '$outputPath/$name-styles.png');
      }
    });
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String path) =>
    tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File(path);
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });

void _testComposer(
  String description,
  Future<void> Function(WidgetTester) testBody,
) {
  testWidgets(description, (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await testBody(tester);
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> _open(
  WidgetTester tester,
  SendDanmakuPanel panel, {
  Size size = const Size(375, 812),
  double scale = 1,
  double keyboard = 0,
  Brightness brightness = Brightness.light,
  GlobalKey? boundaryKey,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFEE719E),
            brightness: brightness,
          ),
          fontFamily: 'NewbiliPreview',
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  PublishRoute(
                    transitionDuration: Duration.zero,
                    barrierLabel: '关闭并保留弹幕草稿',
                    pageBuilder: (_, _, _) => panel,
                  ),
                ),
                child: const Text('打开编辑器'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开编辑器'));
  await tester.pumpAndSettle();
}
