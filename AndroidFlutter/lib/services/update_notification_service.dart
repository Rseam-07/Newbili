import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/models/update_notifications.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class UpdateNotificationService extends GetxService
    with WidgetsBindingObserver {
  static UpdateNotificationService get instance =>
      Get.find<UpdateNotificationService>();
  static const _channel = MethodChannel('com.rseam07.newbili/updates');
  final state = const UpdateNotificationState().obs;
  final busy = false.obs;
  final loaded = false.obs;
  final error = RxnString();
  final pending = <String>{}.obs;
  StreamSubscription<bool>? _accountListener;
  Future<void>? _refreshTask;
  Future<void> _configuration = Future.value();

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _accountListener = Get.find<AccountService>().isLogin.listen(
      (_) => syncAccount(),
    );
    refresh();
  }

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    final json = await _channel.invokeMethod<String>(method, arguments);
    state.value = UpdateNotificationState.fromJson(
      jsonDecode(json!) as Map<String, dynamic>,
    );
    loaded.value = true;
    error.value = null;
  }

  /// Serializes tier/account changes; no cookies leave the app except to Bilibili.
  Future<void> syncAccount([UploaderNotificationLevel? level]) {
    return _configuration = _configuration
        .then((_) async {
          if (!loaded.value) await _invoke('state');
          final selected = level ?? state.value.level;
          late final account = Accounts.main;
          final useAccount =
              selected != UploaderNotificationLevel.off && account.isLogin;
          final cookies = useAccount
              ? await account.cookieJar.loadForRequest(
                  Uri.parse('https://api.bilibili.com/'),
                )
              : null;
          await _invoke('configure', {
            'level': selected.name,
            'mid': useAccount ? account.mid : 0,
            'cookie':
                cookies
                    ?.map((cookie) => '${cookie.name}=${cookie.value}')
                    .join('; ') ??
                '',
          });
        })
        .catchError((Object _) {
          error.value = '无法同步通知设置，请重试';
        });
  }

  Future<void> refresh({bool manual = false}) =>
      _refreshTask ??= _refresh(manual);
  Future<void> _refresh(bool manual) async {
    busy.value = true;
    try {
      await syncAccount();
      if (error.value == null) await _invoke('check', {'manual': manual});
    } catch (_) {
      error.value = '更新检查暂时不可用，请稍后重试';
    } finally {
      busy.value = false;
      _refreshTask = null;
    }
  }

  Future<void> requestPermission() async {
    await Permission.notification.request();
    await refresh(manual: true);
  }

  Future<bool> toggle(VideoDetailData video) async {
    final bvid = video.bvid;
    if (bvid == null || !pending.add(bvid)) return false;
    try {
      if (state.value.contains(bvid)) {
        await _invoke('unmark', {'bvid': bvid});
      } else {
        await _invoke('mark', {
          'video': jsonEncode({
            'bvid': bvid,
            'title': video.title ?? bvid,
            'pic': video.pic ?? '',
            'owner': {'name': video.owner?.name ?? ''},
            'pages': [
              for (final page in video.pages ?? [])
                {'cid': page.cid, 'page': page.page, 'part': page.part ?? ''},
            ],
          }),
        });
      }
      return true;
    } catch (_) {
      error.value = '追更保存失败，请重试';
      return false;
    } finally {
      pending.remove(bvid);
    }
  }

  Future<void> remove(String bvid) async {
    if (!pending.add(bvid)) return;
    try {
      await _invoke('unmark', {'bvid': bvid});
    } catch (_) {
      error.value = '无法移除追更，请重试';
    } finally {
      pending.remove(bvid);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _accountListener?.cancel();
    super.onClose();
  }
}
