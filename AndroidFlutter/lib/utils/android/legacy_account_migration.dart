import 'dart:io';

import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _legacyAccountChannel = MethodChannel(
  'com.rseam07.newbili/legacy_account',
);

Map<String, String>? parseLegacyCookieHeader(String header) {
  final cookies = <String, String>{};
  for (final segment in header.split(';')) {
    final separator = segment.indexOf('=');
    if (separator <= 0) continue;
    final name = segment.substring(0, separator).trim();
    final value = segment.substring(separator + 1).trim();
    if (name.isEmpty || value.isEmpty || name.contains(RegExp(r'[\r\n]'))) {
      continue;
    }
    cookies[name] = value.replaceAll(RegExp(r'[\r\n]'), '');
  }
  if (cookies['SESSDATA']?.isEmpty != false ||
      cookies['bili_jct']?.isEmpty != false ||
      int.tryParse(cookies['DedeUserID'] ?? '') == null) {
    return null;
  }
  return cookies;
}

abstract final class LegacyAccountMigration {
  static Future<bool> run() async {
    if (!Platform.isAndroid || Accounts.account.isNotEmpty) return false;
    try {
      final legacy = await _legacyAccountChannel
          .invokeMapMethod<String, Object?>(
            'peek',
          );
      final cookieHeader = legacy?['cookieHeader'];
      if (cookieHeader is! String) return false;
      final cookies = parseLegacyCookieHeader(cookieHeader);
      if (cookies == null) return false;

      final accessKey = switch (legacy?['accessKey']) {
        final String value when value.trim().isNotEmpty => value.trim(),
        _ => null,
      };
      final account = LoginAccount(
        BiliCookieJar.fromJson(cookies),
        accessKey,
        null,
        AccountType.values.toSet(),
      );
      await Future.wait([account.onChange(), AnonymousAccount().delete()]);
      await _legacyAccountChannel.invokeMethod<bool>('clear');
      return true;
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('Legacy account migration unavailable: ${error.code}');
      }
      return false;
    } on FormatException {
      return false;
    }
  }
}
