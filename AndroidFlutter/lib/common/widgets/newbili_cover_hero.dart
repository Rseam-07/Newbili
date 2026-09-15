import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:material_ui/material_ui.dart';

/// A per-tile identity also handles duplicate videos in the same feed safely.
class NewbiliCoverSource extends StatefulWidget {
  const NewbiliCoverSource({super.key, required this.builder});
  final Widget Function(BuildContext context, Object tag) builder;

  @override
  State<NewbiliCoverSource> createState() => _NewbiliCoverSourceState();
}

class _NewbiliCoverSourceState extends State<NewbiliCoverSource> {
  final Object _tag = Object();

  @override
  Widget build(BuildContext context) => widget.builder(context, _tag);
}

/// Keeps the live player mounted while only the cover flies between routes.
class NewbiliCoverHero extends StatefulWidget {
  const NewbiliCoverHero({
    super.key,
    required this.tag,
    required this.child,
    this.radius = 0,
  });

  final Object? tag;
  final Widget child;
  final double radius;

  @override
  State<NewbiliCoverHero> createState() => _NewbiliCoverHeroState();
}

class _NewbiliCoverHeroState extends State<NewbiliCoverHero> {
  final _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final tag = widget.tag;
    final endpoint = _CoverEndpoint(
      key: _contentKey,
      radius: widget.radius,
      child: widget.child,
    );
    if (tag == null) return endpoint;
    return HeroMode(
      enabled: !NewbiliMotion.reduced(context),
      child: Hero(
        tag: tag,
        transitionOnUserGestures: true,
        createRectTween: (begin, end) => MaterialRectCenterArcTween(
          begin: begin,
          end: end,
        ),
        placeholderBuilder: (context, size, child) => SizedBox.fromSize(
          size: size,
          child: IgnorePointer(child: Opacity(opacity: 0, child: child)),
        ),
        flightShuttleBuilder: (context, animation, direction, from, to) {
          // The Hero's immediate child retains each endpoint's corner radius.
          final fromRadius =
              ((from.widget as Hero).child as _CoverEndpoint).radius;
          final toRadius = ((to.widget as Hero).child as _CoverEndpoint).radius;
          final radii = direction == HeroFlightDirection.push
              ? Tween<double>(begin: fromRadius, end: toRadius)
              : Tween<double>(begin: toRadius, end: fromRadius);
          // Reuse the source image at its decoded size. Resizing the image
          // provider every frame would create a series of different cache keys.
          final source = direction == HeroFlightDirection.push ? from : to;
          final sourceChild =
              ((source.widget as Hero).child as _CoverEndpoint).child;
          final sourceSize = (source.findRenderObject()! as RenderBox).size;
          return AnimatedBuilder(
            animation: animation,
            child: FittedBox(
              fit: BoxFit.cover,
              child: InheritedTheme.captureAll(
                source,
                SizedBox.fromSize(size: sourceSize, child: sourceChild),
              ),
            ),
            builder: (context, child) => ClipRRect(
              borderRadius: BorderRadius.circular(radii.evaluate(animation)),
              child: child,
            ),
          );
        },
        child: endpoint,
      ),
    );
  }
}

class _CoverEndpoint extends StatelessWidget {
  const _CoverEndpoint({super.key, required this.radius, required this.child});
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: child,
  );
}
