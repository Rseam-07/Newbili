enum DoubleTapType { left, center, right }

DoubleTapType resolveDoubleTap({
  required double x,
  required double width,
  required bool fullscreen,
}) {
  if (!fullscreen || width <= 0) return DoubleTapType.center;
  if (x < width / 4) return DoubleTapType.left;
  if (x > width * 3 / 4) return DoubleTapType.right;
  return DoubleTapType.center;
}
