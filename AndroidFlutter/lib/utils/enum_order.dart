/// Validate persisted indices once at the storage boundary. Existing ordinals
/// and explicit user ordering survive additions to either navigation enum.
List<T> restoreEnumOrder<T>(List<T> values, List? stored, List<T> defaults) {
  if (stored == null) return defaults;
  final restored = stored
      .whereType<int>()
      .where((index) => index >= 0 && index < values.length)
      .map((index) => values[index])
      .toSet()
      .toList();
  return restored.isEmpty ? defaults : restored;
}
