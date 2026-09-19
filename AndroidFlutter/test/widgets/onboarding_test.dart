import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/pages/onboarding/view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const output = String.fromEnvironment('NEWBILI_VISUAL_OUTPUT');
const fontPath = String.fromEnvironment('NEWBILI_VISUAL_FONT');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (fontPath.isNotEmpty) {
      await ui.loadFontFromList(
        await File(fontPath).readAsBytes(),
        fontFamily: 'PreviewCJK',
      );
    }
  });

  testWidgets('first-use state is stored only after skip or completion', (
    tester,
  ) async {
    var storedVersion = 0;
    var writes = 0;
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        FirstUseGate(
          home: const Text('NEWBILI HOME'),
          readVersion: () => storedVersion,
          writeVersion: (version) async {
            writes++;
            storedVersion = version;
          },
        ),
      ),
    );

    expect(find.text('把喜欢的内容，\n放回画面中心'), findsOneWidget);
    expect(writes, 0);
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('首页、动态与搜索，\n自然衔接'), findsOneWidget);
    expect(writes, 0);

    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(find.text('NEWBILI HOME'), findsOneWidget);
    expect(storedVersion, FirstUseGate.currentVersion);
    expect(writes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed users go straight to the main experience', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        FirstUseGate(
          home: const Text('EXISTING USER HOME'),
          readVersion: () => FirstUseGate.currentVersion,
          writeVersion: (_) async {},
        ),
      ),
    );
    expect(find.text('EXISTING USER HOME'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-skip')), findsNothing);
  });

  testWidgets('three-stage story finishes from the primary action', (
    tester,
  ) async {
    var completed = false;
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        NewbiliOnboarding(
          onComplete: () async {
            completed = true;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('开始使用'), findsOneWidget);
    expect(find.text('沉浸播放，\n信息触手可及'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pump();
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final config in <(String, Size, Brightness, double)>[
    ('onboarding-phone-light', const Size(375, 812), Brightness.light, 1),
    ('onboarding-phone-dark', const Size(375, 812), Brightness.dark, 1),
    ('onboarding-large-text', const Size(320, 700), Brightness.light, 1.6),
    ('onboarding-tablet', const Size(1280, 800), Brightness.light, 1),
  ]) {
    testWidgets('${config.$1} renders without overflow', (tester) async {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(config.$2);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          RepaintBoundary(
            key: key,
            child: NewbiliOnboarding(onComplete: () async {}),
          ),
          brightness: config.$3,
          textScale: config.$4,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (output.isNotEmpty) await _capture(tester, key, '${config.$1}.png');
    });
  }
}

Widget _app(
  Widget home, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: const Color(0xFFFF4B8B),
      fontFamily: fontPath.isEmpty ? null : 'PreviewCJK',
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: home,
  );
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final directory = Directory(output);
  await directory.create(recursive: true);
  await File('${directory.path}/$name').writeAsBytes(
    data!.buffer.asUint8List(),
  );
  image.dispose();
}
