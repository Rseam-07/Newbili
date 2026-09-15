import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/login/qr_panel.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _code = (authCode: 'test', url: 'https://example.com/login-test');

void main() {
  const fontPath = String.fromEnvironment('NEWBILI_VISUAL_FONT');
  const outputPath = String.fromEnvironment('NEWBILI_VISUAL_OUTPUT');
  setUpAll(() async {
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
      final font = FontLoader('NewbiliPreview')
        ..addFont(
          Future.value(
            ByteData.sublistView(await File(fontPath).readAsBytes()),
          ),
        );
      await font.load();
    }
  });
  for (final scale in [1.0, 2.0, 3.0]) {
    for (final name in ['loading', 'ready', 'expired', 'error']) {
      testWidgets(
        'QR $name fits 320dp at font scale $scale with safe actions',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 812));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          var refreshed = 0;
          var saved = 0;
          var opened = 0;
          var copied = 0;
          final state = switch (name) {
            'loading' =>
              LoadingState<({String authCode, String url})>.loading(),
            'error' => const Error('二维码加载失败，请检查网络后重试'),
            _ => const Success(_code),
          };
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  fontFamily: fontPath.isEmpty ? null : 'NewbiliPreview',
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFFCE4374),
                    brightness: scale == 2 ? Brightness.dark : Brightness.light,
                  ),
                ),
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    appBar: AppBar(title: const Text('登录')),
                    body: SingleChildScrollView(
                      child: QrLoginPanel(
                        state: state,
                        secondsLeft: name == 'ready' ? 180 : 0,
                        status: switch (name) {
                          'loading' => '正在生成二维码',
                          'ready' => '等待扫码',
                          'expired' => '二维码已过期，请刷新',
                          _ => '',
                        },
                        onRefresh: () => refreshed++,
                        onSave: () => saved++,
                        onOpen: () => opened++,
                        onCopy: () => copied++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          if (outputPath.isNotEmpty && scale == 1) {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await tester.runAsync(() async {
              await Directory(outputPath).create(recursive: true);
              await File('$outputPath/qr-$name.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
            });
            image.dispose();
          }
          final save = find.widgetWithText(TextButton, '保存二维码');
          final open = find.widgetWithText(TextButton, '打开 bilibili');
          final copy = find.widgetWithText(TextButton, '复制登录链接');
          for (final button in [save, open, copy]) {
            expect(
              tester.widget<TextButton>(button).onPressed != null,
              name == 'ready',
            );
            expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          }
          if (name == 'ready') {
            for (final button in [save, open, copy]) {
              await tester.ensureVisible(button);
              await tester.tap(button);
            }
            expect([saved, opened, copied], [1, 1, 1]);
          }
          if (name == 'error' || name == 'expired') {
            final retry = find.text(name == 'error' ? '点击重试' : '刷新二维码');
            await tester.ensureVisible(retry);
            await tester.tap(retry);
            expect(refreshed, 1);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
