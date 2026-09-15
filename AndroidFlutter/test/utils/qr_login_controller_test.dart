import 'dart:async';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _first = (authCode: 'first', url: 'https://example.com/first');
const _second = (authCode: 'second', url: 'https://example.com/second');

void main() {
  testWidgets('QR generation failures become retryable and reset expiry', (
    tester,
  ) async {
    var attempts = 0;
    final controller = LoginPageController(
      initialTab: 2,
      qrLoader: () async {
        if (attempts++ == 0) throw StateError('offline');
        return const Success(_second);
      },
      qrPoller: (_) async => {'status': false, 'code': 86101},
    )..onInit();
    await tester.pump();
    expect(controller.codeInfo.value, isA<Error>());
    await controller.refreshQRCode();
    expect(controller.codeInfo.value.data, _second);
    expect(controller.qrCodeLeftTime.value, 180);
    expect(controller.statusQRCode.value, '等待扫码');
    controller.onClose();
  });

  testWidgets('out-of-order QR generations cannot replace the newest code', (
    tester,
  ) async {
    final first = Completer<LoadingState<LoginQrCode>>();
    final second = Completer<LoadingState<LoginQrCode>>();
    var attempts = 0;
    final controller = LoginPageController(
      initialTab: 2,
      qrLoader: () => attempts++ == 0 ? first.future : second.future,
    )..onInit();
    final refresh = controller.refreshQRCode();
    second.complete(const Success(_second));
    await refresh;
    first.complete(const Success(_first));
    await tester.pump();
    expect(controller.codeInfo.value.data, _second);
    controller.onClose();
  });

  testWidgets('a thrown poll releases the lock and polling recovers', (
    tester,
  ) async {
    var polls = 0;
    final controller = LoginPageController(
      initialTab: 2,
      qrLoader: () async => const Success(_first),
      qrPoller: (_) async {
        if (polls++ == 0) throw StateError('offline');
        return {'status': false, 'code': 86090};
      },
    )..onInit();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.statusQRCode.value, contains('正在重试'));
    await tester.pump(const Duration(seconds: 1));
    expect(polls, 2);
    expect(controller.statusQRCode.value, contains('App 中确认'));
    controller.onClose();
  });

  for (final action in ['refresh', 'leave', 'close', 'expire']) {
    testWidgets('late QR authorization is ignored after $action', (
      tester,
    ) async {
      final poll = Completer<dynamic>();
      var loggedIn = false;
      final controller = LoginPageController(
        initialTab: 2,
        qrLoader: () async => const Success(_first),
        qrPoller: (_) => poll.future,
        onQrAuthenticated: (_) async => loggedIn = true,
      )..onInit();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      switch (action) {
        case 'refresh':
          await controller.refreshQRCode();
        case 'leave':
          controller.tabController.index = 1;
        case 'close':
          controller.onClose();
        case 'expire':
          await tester.pump(const Duration(seconds: 180));
      }
      poll.complete({'status': true, 'data': <String, dynamic>{}});
      await tester.pump();
      expect(loggedIn, isFalse);
      if (action != 'close') controller.onClose();
    });
  }

  testWidgets('successful authorization is committed only once', (
    tester,
  ) async {
    var saved = 0;
    final controller = LoginPageController(
      initialTab: 2,
      qrLoader: () async => const Success(_first),
      qrPoller: (_) async => {'status': true, 'data': <String, dynamic>{}},
      onQrAuthenticated: (_) async {
        saved++;
      },
    )..onInit();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    expect(saved, 1);
    expect(controller.statusQRCode.value, '扫码成功');
    controller.onClose();
  });
}
