import 'dart:io';

import 'package:PiliPlus/utils/android/glass_tier_policy.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

export 'package:PiliPlus/utils/android/glass_tier_policy.dart'
    show NewbiliGlassTier;

/// One process-wide decision keeps the effect tier stable while lists scroll.
class NewbiliGlassCapability extends ChangeNotifier
    with WidgetsBindingObserver {
  NewbiliGlassCapability._();

  static final instance = NewbiliGlassCapability._();
  static const _channel = MethodChannel('com.rseam07.newbili/glass');

  NewbiliGlassTier _tier = NewbiliGlassTier.staticMaterial;
  NewbiliGlassTier get tier => _tier;

  bool get enabled => GStorage.setting.get(
    SettingBoxKey.newbiliLiquidGlass,
    defaultValue: true,
  );

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    await refresh();
  }

  Future<void> refresh() async {
    final isAndroid = Platform.isAndroid;
    final isEnabled = isAndroid && enabled;
    var next = resolveNewbiliGlassTier(
      isAndroid: isAndroid,
      enabled: isEnabled,
      apiLevel: null,
      lowRam: null,
      powerSave: null,
    );
    if (isAndroid && isEnabled) {
      try {
        final result = await _channel.invokeMapMethod<String, Object?>(
          'capability',
        );
        next = resolveNewbiliGlassTier(
          isAndroid: true,
          enabled: true,
          apiLevel: result?['api'],
          lowRam: result?['lowRam'],
          powerSave: result?['powerSave'],
        );
      } on PlatformException catch (error) {
        if (kDebugMode) {
          debugPrint('Liquid glass capability fallback: $error');
        }
      }
    }
    if (next != _tier) {
      _tier = next;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }
}
