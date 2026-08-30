import 'package:PiliPlus/utils/android/glass_tier_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NewbiliGlassTier resolve({
    bool isAndroid = true,
    bool enabled = true,
    Object? apiLevel = 33,
    Object? lowRam = false,
    Object? powerSave = false,
  }) => resolveNewbiliGlassTier(
    isAndroid: isAndroid,
    enabled: enabled,
    apiLevel: apiLevel,
    lowRam: lowRam,
    powerSave: powerSave,
  );

  group('resolveNewbiliGlassTier', () {
    test('uses enhanced glass on capable Android 13 and newer devices', () {
      expect(resolve(), NewbiliGlassTier.enhanced);
      expect(resolve(apiLevel: 37), NewbiliGlassTier.enhanced);
    });

    test('uses blur on Android 12 and 12L', () {
      expect(resolve(apiLevel: 31), NewbiliGlassTier.blur);
      expect(resolve(apiLevel: 32), NewbiliGlassTier.blur);
    });

    test('uses static material below Android 12', () {
      expect(resolve(apiLevel: 30), NewbiliGlassTier.staticMaterial);
    });

    test('uses static material when glass is disabled or off Android', () {
      expect(resolve(enabled: false), NewbiliGlassTier.staticMaterial);
      expect(resolve(isAndroid: false), NewbiliGlassTier.staticMaterial);
    });

    test('uses static material on low-memory or power-saving devices', () {
      expect(resolve(lowRam: true), NewbiliGlassTier.staticMaterial);
      expect(resolve(powerSave: true), NewbiliGlassTier.staticMaterial);
    });

    test('malformed or missing host data fails closed', () {
      expect(resolve(apiLevel: '33'), NewbiliGlassTier.staticMaterial);
      expect(resolve(lowRam: null), NewbiliGlassTier.staticMaterial);
      expect(resolve(powerSave: 0), NewbiliGlassTier.staticMaterial);
    });
  });
}
