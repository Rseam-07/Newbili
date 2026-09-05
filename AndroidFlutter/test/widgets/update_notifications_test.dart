import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/common/widgets/background_playback_picker.dart';
import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/models/common/video/background_playback_mode.dart';
import 'package:PiliPlus/models/update_notifications.dart';
import 'package:PiliPlus/pages/updates/view.dart';
import 'package:PiliPlus/services/update_notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.rseam07.newbili/updates');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Map<String, Object?> snapshot() => {
    'level': 'off',
    'tracks': [],
    'permission': true,
    'seriesPermission': true,
    'upPermission': true,
    'loggedIn': false,
    'checking': false,
    'lastChecked': 0,
    'status': '已检查，目前没有新内容',
    'recent': [],
  };
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('background mode preserves explicit old choices and defaults to listen only', () {
    expect(
      BackgroundPlaybackMode.restore(null, true),
      BackgroundPlaybackMode.always,
    );
    expect(
      BackgroundPlaybackMode.restore(null, false),
      BackgroundPlaybackMode.off,
    );
    expect(
      BackgroundPlaybackMode.restore(null, null),
      BackgroundPlaybackMode.listenOnly,
    );
    expect(
      BackgroundPlaybackMode.restore('listenOnly', true),
      BackgroundPlaybackMode.listenOnly,
    );
    expect(
      BackgroundPlaybackMode.restore('unknown', false),
      BackgroundPlaybackMode.off,
    );
  });
  test(
    'background policy distinguishes listen mode, normal playback and PiP',
    () {
      for (final mode in BackgroundPlaybackMode.values) {
        expect(mode.allows(listening: false, pictureInPicture: true), true);
      }
      expect(BackgroundPlaybackMode.off.allows(listening: true), false);
      expect(BackgroundPlaybackMode.listenOnly.allows(listening: false), false);
      expect(BackgroundPlaybackMode.listenOnly.allows(listening: true), true);
      expect(BackgroundPlaybackMode.always.allows(listening: false), true);
    },
  );
  test(
    'update checks coalesce and leave busy state after completion',
    () async {
      final release = Completer<void>();
      var checks = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'check') {
          checks++;
          await release.future;
        }
        return jsonEncode(snapshot());
      });
      final service = UpdateNotificationService();
      final first = service.refresh();
      final second = service.refresh(manual: true);
      expect(identical(first, second), true);
      expect(service.busy.value, true);
      release.complete();
      await first;
      expect(checks, 1);
      expect(service.busy.value, false);
      expect(service.loaded.value, true);
    },
  );
  test('failed checks unlock UI and allow subsequent retries', () async {
    var fail = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'check' && fail) {
        throw PlatformException(code: 'offline');
      }
      return jsonEncode(snapshot());
    });
    final service = UpdateNotificationService();
    await service.refresh();
    expect(service.busy.value, false);
    expect(service.error.value, isNotNull);
    fail = false;
    await service.refresh(manual: true);
    expect(service.error.value, isNull);
  });
  test(
    'disabled notification tier passes no account credential to native storage',
    () async {
      Map? configured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'configure') configured = call.arguments as Map;
        return jsonEncode(snapshot());
      });
      await UpdateNotificationService().syncAccount(
        UploaderNotificationLevel.off,
      );
      expect(configured!['cookie'], '');
      expect(configured!['mid'], 0);
    },
  );

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets(
      'notification settings keep actions usable at text scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        UploaderNotificationLevel? selected;
        var library = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: scale == 2 ? Brightness.dark : Brightness.light,
            ),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: UpdateNotificationContent(
                  state: const UpdateNotificationState(
                    permission: true,
                    level: UploaderNotificationLevel.specialOnly,
                  ),
                  busy: false,
                  onSelectLevel: (value) => selected = value,
                  onRequestPermission: () {},
                  onSystemSettings: () {},
                  onRefresh: () {},
                  onLibrary: () => library = true,
                  onVideo: (_, _) {},
                ),
              ),
            ),
          ),
        );
        await tester.ensureVisible(find.text('全部关注'));
        await tester.tap(find.text('全部关注'));
        expect(selected, UploaderNotificationLevel.allFollowing);
        await tester.scrollUntilVisible(find.text('我的追更'), 250);
        await tester.tap(find.text('我的追更'));
        expect(library, true);
        for (final row in find.byType(NewbiliSettingsRow).evaluate()) {
          expect(
            tester.getSize(find.byWidget(row.widget)).height,
            greaterThanOrEqualTo(48),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('all three background choices fit at text scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      BackgroundPlaybackMode? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showBackgroundPlaybackPicker(
                    context,
                    BackgroundPlaybackMode.listenOnly,
                    (mode) => selected = mode,
                  ),
                  child: const Text('后台播放'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('后台播放'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('始终继续'));
      await tester.tap(find.text('始终继续'));
      await tester.pumpAndSettle();
      expect(selected, BackgroundPlaybackMode.always);
      expect(tester.takeException(), isNull);
    });
  }
}
