import 'dart:io' show Platform;

import 'package:PiliPlus/build_config.dart';
import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

abstract final class Update {
  // 检查更新
  static Future<void> checkUpdate([bool isAuto = true]) async {
    if (kDebugMode) return;
    SmartDialog.dismiss();
    try {
      final res = await Request().get(
        Api.latestApp,
        options: Options(
          headers: {'user-agent': BrowserUa.mob},
          extra: {'account': const NoAccount()},
        ),
      );
      if (res.data is Map || res.data.isEmpty) {
        if (!isAuto) {
          SmartDialog.showToast('检查更新失败，GitHub接口未返回数据，请检查网络');
        }
        return;
      }
      final data = findNewerRelease(
        res.data as List,
        '${BuildConfig.versionName}+${BuildConfig.versionCode}',
        android: Platform.isAndroid,
      );
      if (data == null) {
        if (!isAuto) {
          SmartDialog.showToast('已是最新版本');
        }
      } else {
        SmartDialog.show(
          animationType: SmartAnimationType.centerFade_otherSlide,
          builder: (context) {
            final colorScheme = ColorScheme.of(context);
            Widget downloadBtn(String text, {String? ext}) => TextButton(
              onPressed: () => onDownload(data, ext: ext),
              child: Text(text),
            );
            return AlertDialog(
              title: const Text('发现新版本'),
              content: SizedBox(
                height: 280,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['tag_name']}',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Text('${data['body']}'),
                      TextButton(
                        onPressed: () => PageUtils.launchURL(
                          '${Constants.sourceCodeUrl}/commits/main',
                        ),
                        child: Text(
                          "点此查看完整更新(即commit)内容",
                          style: TextStyle(color: colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (isAuto)
                  TextButton(
                    onPressed: () {
                      SmartDialog.dismiss();
                      GStorage.setting.put(SettingBoxKey.autoUpdate, false);
                    },
                    child: Text(
                      '不再提醒',
                      style: TextStyle(color: colorScheme.outline),
                    ),
                  ),
                TextButton(
                  onPressed: SmartDialog.dismiss,
                  child: Text(
                    '取消',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ),
                if (Platform.isWindows) ...[
                  downloadBtn('zip', ext: 'zip'),
                  downloadBtn('exe', ext: 'exe'),
                ] else if (Platform.isLinux) ...[
                  downloadBtn('rpm', ext: 'rpm'),
                  downloadBtn('deb', ext: 'deb'),
                  downloadBtn('targz', ext: 'tar.gz'),
                ] else
                  downloadBtn('Github'),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('failed to check update: $e');
      if (!isAuto) SmartDialog.showToast('检查更新失败，请稍后重试');
    }
  }

  // 下载适用于当前系统的安装包
  static Future<void> onDownload(Map data, {String? ext}) async {
    SmartDialog.dismiss();
    try {
      void download(String plat) {
        if (data['assets'].isNotEmpty) {
          for (Map<String, dynamic> i in data['assets']) {
            final String name = i['name'];
            if (name.contains(plat) &&
                (ext == null || ext.isEmpty ? true : name.endsWith(ext))) {
              PageUtils.launchURL(i['browser_download_url']);
              return;
            }
          }
          throw UnsupportedError('platform not found: $plat');
        }
      }

      if (Platform.isAndroid) {
        // 获取设备信息
        AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
        // [arm64-v8a]
        download(androidInfo.supportedAbis.first);
      } else {
        download(Platform.operatingSystem);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('download error: $e');
      PageUtils.launchURL('${Constants.sourceCodeUrl}/releases/latest');
    }
  }
}

bool isNewerReleaseVersion(String candidate, String current) {
  List<int>? parse(String input) {
    final match = RegExp(r'^(?:v|android-v)?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$')
        .firstMatch(input.trim());
    if (match == null) return null;
    return [
      for (var index = 1; index <= 4; index++) int.parse(match[index] ?? '0'),
    ];
  }

  final candidateParts = parse(candidate);
  final currentParts = parse(current);
  if (candidateParts == null || currentParts == null) return false;
  for (var index = 0; index < candidateParts.length; index++) {
    final comparison = candidateParts[index].compareTo(currentParts[index]);
    if (comparison != 0) return comparison > 0;
  }
  return false;
}

/// Date-based preview tags are not app versions. Android releases advertise
/// their actual version and build in the APK asset name produced by packaging.
Map? findNewerRelease(List releases, String current, {bool android = false}) {
  Map? newest;
  var newestVersion = current;
  for (final release in releases.whereType<Map>()) {
    if (release['draft'] == true) continue;
    var version = '${release['tag_name'] ?? ''}';
    if (android) {
      final assets = (release['assets'] as List?)?.whereType<Map>();
      if (assets == null) continue;
      var hasApk = false;
      for (final asset in assets) {
        final name = '${asset['name'] ?? ''}';
        if (!name.endsWith('.apk')) continue;
        hasApk = true;
        final match = RegExp(r'^Newbili-Android-(\d+\.\d+\.\d+)-(\d+)-')
            .firstMatch(name);
        if (match != null) {
          version = '${match[1]}+${match[2]}';
          break;
        }
      }
      if (!hasApk) continue;
    }
    if (isNewerReleaseVersion(version, newestVersion)) {
      newest = release;
      newestVersion = version;
    }
  }
  return newest;
}
