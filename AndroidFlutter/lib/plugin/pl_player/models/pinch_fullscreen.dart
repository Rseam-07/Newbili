/// A deliberate 16% span change switches presentation, never playback state.
/// Returning to the original span before lifting cancels the gesture.
bool? pinchFullscreenTarget({required double scale, required bool fullscreen}) {
  if (!scale.isFinite || scale <= 0) return null;
  if (!fullscreen && scale >= 1.16) return true;
  if (fullscreen && scale <= .84) return false;
  return null;
}
