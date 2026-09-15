import 'dart:convert';

import 'package:flutter/services.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/common/widgets/foreground_refresh.dart';
import 'package:PiliPlus/common/widgets/gesture/mouse_interactive_viewer.dart';
import 'package:PiliPlus/common/widgets/gesture/player_gesture_recognizer.dart';
import 'package:PiliPlus/common/widgets/route_aware_mixin.dart';
import 'package:PiliPlus/pages/home/home_header.dart';
import 'package:PiliPlus/plugin/pl_player/models/double_tap_type.dart';
import 'package:PiliPlus/plugin/pl_player/models/pinch_fullscreen.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/compact_player_bar.dart';
import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/common/widgets/progress_bar/segment_progress_bar.dart'
    show ViewPointSegment, ViewPointSegmentProgressBar;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const fontPath = String.fromEnvironment('NEWBILI_VISUAL_FONT');
  setUpAll(() async {
    if (fontPath.isEmpty) return;
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
      fontFamily: 'PreviewFeedback',
    );
  });
  test(
    'inline double taps always pause; fullscreen keeps deliberate edge seeking',
    () {
      for (final x in [0.0, 30.0, 150.0, 319.0]) {
        expect(
          resolveDoubleTap(x: x, width: 320, fullscreen: false),
          DoubleTapType.center,
        );
      }
      expect(
        resolveDoubleTap(x: 30, width: 320, fullscreen: true),
        DoubleTapType.left,
      );
      expect(
        resolveDoubleTap(x: 290, width: 320, fullscreen: true),
        DoubleTapType.right,
      );
      expect(
        resolveDoubleTap(x: 160, width: 320, fullscreen: true),
        DoubleTapType.center,
      );
    },
  );
  test(
    'pinch threshold ignores jitter, reverse direction and canceled intent',
    () {
      expect(pinchFullscreenTarget(scale: 1.2, fullscreen: false), isTrue);
      expect(pinchFullscreenTarget(scale: .8, fullscreen: true), isFalse);
      for (final scale in [1.0, 1.1, .9, double.nan]) {
        expect(pinchFullscreenTarget(scale: scale, fullscreen: false), isNull);
        expect(pinchFullscreenTarget(scale: scale, fullscreen: true), isNull);
      }
      expect(pinchFullscreenTarget(scale: .7, fullscreen: false), isNull);
      expect(pinchFullscreenTarget(scale: 1.3, fullscreen: true), isNull);
    },
  );
  testWidgets(
    'two fingers switch once, suppress single-finger seek, and preserve picture scale',
    (tester) async {
      final transform = TransformationController();
      final recognizer = PlayerScaleGestureRecognizer();
      addTearDown(transform.dispose);
      addTearDown(recognizer.dispose);
      final key = GlobalKey();
      final scales = <double>[];
      var pans = 0, cancellations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              height: 200,
              child: MouseInteractiveViewer(
                childKey: key,
                transformationController: transform,
                scaleGestureRecognizer: recognizer,
                pointerSignalFallback: (_) {},
                onPointerDown: recognizer.addPointer,
                onPanStart: (_) {},
                onPanUpdate: (_) => pans++,
                onPanEnd: (_) {},
                onScaleUpdate: (_) {},
                onPinchStart: () => cancellations++,
                onPinchEnd: scales.add,
                child: ColoredBox(key: key, color: Colors.black),
              ),
            ),
          ),
        ),
      );
      final first = await tester.startGesture(
        const Offset(100, 100),
        pointer: 1,
      );
      final second = await tester.startGesture(
        const Offset(220, 100),
        pointer: 2,
      );
      await first.moveTo(const Offset(65, 100));
      await second.moveTo(const Offset(255, 100));
      await tester.pump();
      await second.up();
      await first.moveTo(const Offset(30, 100));
      await first.up();
      await tester.pumpAndSettle();
      expect(scales, hasLength(1));
      expect(scales.single, greaterThan(1.16));
      expect(cancellations, 1);
      expect(pans, 0);
      expect(transform.value.getMaxScaleOnAxis(), 1);
      final a = await tester.startGesture(const Offset(100, 100), pointer: 3);
      final b = await tester.startGesture(const Offset(220, 100), pointer: 4);
      await a.moveTo(const Offset(40, 100));
      await b.cancel();
      await a.up();
      expect(scales, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('compact chapter ticks never paint titles over the video', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 48));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const ColoredBox(
          color: Color(0xFF263A43),
          child: Center(
            child: ViewPointSegmentProgressBar(
              height: 3,
              showLabels: false,
              segments: [
                ViewPointSegment(end: .5, title: 'Long chapter title', from: 0),
                ViewPointSegment(end: 1, title: 'Another chapter', from: 120),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(ViewPointSegmentProgressBar)).height, 3);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await boundary.toImage();
      final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final pixels = data.buffer.asUint8List();
      // The previous renderer reserved 3px but painted its 15px title anyway.
      for (var y = 0; y < 48; y++) {
        if (y >= 22 && y <= 25) continue;
        for (var x = 0; x < 320; x++) {
          final i = (y * 320 + x) * 4;
          expect(pixels.sublist(i, i + 4), [0x26, 0x3A, 0x43, 0xFF]);
        }
      }
      const tick = (24 * 320 + 160) * 4;
      expect(pixels[tick], lessThan(0x26));
      img.dispose();
    });
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 375.0, 840.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        'compact transport fits $width dp at $scale text with real seeking',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 240));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final key = GlobalKey();
          var play = 0, more = 0, full = 0;
          int? seek;
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  fontFamily: fontPath.isEmpty ? null : 'PreviewFeedback',
                ),
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    backgroundColor: const Color(0xFF263A43),
                    body: Align(
                      alignment: Alignment.bottomCenter,
                      child: CompactPlayerBar(
                        playing: true,
                        time: '01:24',
                        total: '12:30',
                        fullscreen: false,
                        onPlay: () => play++,
                        onMore: () => more++,
                        onFullscreen: () => full++,
                        timeline: ProgressBar(
                          barHeight: 3,
                          thumbRadius: 5,
                          thumbGlowRadius: 16,
                          onDragStart: (_) {},
                          baseBarColor: Colors.white24,
                          progressBarColor: Colors.pinkAccent,
                          bufferedBarColor: Colors.white54,
                          thumbColor: Colors.white,
                          thumbGlowColor: Colors.white24,
                          progress: 84,
                          total: 750,
                          buffered: 200,
                          onSeek: (position) => seek = position,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.getSize(find.byType(CompactPlayerBar)).height, 48);
          for (final label in ['暂停', '更多播放控制', '全屏']) {
            expect(
              tester.getSize(find.byTooltip(label)).shortestSide,
              greaterThanOrEqualTo(48),
            );
            await tester.tap(find.byTooltip(label));
          }
          await tester.tap(find.byType(ProgressBar));
          await tester.pump();
          expect([play, more, full], [1, 1, 1]);
          expect(seek, isNotNull);
          expect(tester.takeException(), isNull);
          const output = String.fromEnvironment('NEWBILI_VISUAL_OUTPUT');
          if (output.isNotEmpty && scale == 1) {
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final img = await boundary.toImage(pixelRatio: 2);
              final bytes = await img.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File('$output/player-bar-$width.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              img.dispose();
            });
          }
        },
      );
    }
  }
  testWidgets(
    'collapsed toolbar paints and accepts input only inside its remaining height',
    (tester) async {
      final offset = ValueNotifier(0.0);
      addTearDown(offset.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ValueListenableBuilder(
                  valueListenable: offset,
                  builder: (_, v, _) => NewbiliCollapsingToolbar(
                    offset: v,
                    child: const Text('Search header'),
                  ),
                ),
                const Expanded(child: Text('Feed')),
                const SizedBox(height: 64, child: Text('Navigation')),
              ],
            ),
          ),
        ),
      );
      final nav = tester.getRect(find.text('Navigation'));
      offset.value = 60;
      await tester.pump();
      expect(tester.getSize(find.byType(NewbiliCollapsingToolbar)).height, 0);
      expect(find.text('Search header').hitTestable(), findsNothing);
      expect(tester.getRect(find.text('Navigation')), nav);
    },
  );
  testWidgets(
    'foreground refresh recovers errors without overlapping and stops in background',
    (tester) async {
      var calls = 0;
      Completer<void>? pending;
      await tester.pumpWidget(
        MaterialApp(
          home: ForegroundRefresh(
            onRefresh: () async {
              calls++;
              if (calls == 1) throw StateError('offline');
              await (pending ??= Completer<void>()).future;
            },
            child: const Text('inbox'),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 2);
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 2);
      pending!.complete();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 60));
      expect(calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
      expect(calls, 3);
    },
  );
  testWidgets('returning from an inbox subpage refreshes immediately', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    var calls = 0;
    await tester.pumpWidget(
      GetMaterialApp(
        navigatorKey: nav,
        navigatorObservers: [routeObserver],
        home: ForegroundRefresh(
          onRefresh: () async => calls++,
          child: const Text('inbox'),
        ),
      ),
    );
    nav.currentState!.push(
      GetPageRoute(page: () => const Scaffold(body: Text('chat'))),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 60));
    expect(calls, 0);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    Get.reset();
  });
}
