enum NewbiliGlassTier { staticMaterial, blur, enhanced }

/// Resolves the glass rendering tier without reading platform or app state.
///
/// Platform-channel values deliberately stay typed as [Object] so malformed or
/// missing host data degrades to the inexpensive static material instead of
/// throwing while the app is starting or resuming.
NewbiliGlassTier resolveNewbiliGlassTier({
  required bool isAndroid,
  required bool enabled,
  required Object? apiLevel,
  required Object? lowRam,
  required Object? powerSave,
}) {
  if (!isAndroid || !enabled) return NewbiliGlassTier.staticMaterial;

  final api = apiLevel is int ? apiLevel : 0;
  final isLowRamDevice = lowRam is bool ? lowRam : true;
  final isPowerSaveMode = powerSave is bool ? powerSave : true;

  if (isLowRamDevice || isPowerSaveMode) {
    return NewbiliGlassTier.staticMaterial;
  }
  if (api >= 33) return NewbiliGlassTier.enhanced;
  if (api >= 31) return NewbiliGlassTier.blur;
  return NewbiliGlassTier.staticMaterial;
}
