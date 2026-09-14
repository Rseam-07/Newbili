import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

/// Shared with history, watch later and favorite folders. The cover geometry
/// follows iOS LibraryVideoRow; text and touch targets grow independently.
class NewbiliLibraryTile extends StatelessWidget {
  const NewbiliLibraryTile({
    super.key,
    required this.title,
    required this.cover,
    required this.metadata,
    this.subtitle,
    this.badge,
    this.progressLabel,
    this.progress,
    this.selected = false,
    this.selecting = false,
    this.heroTag,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.trailing,
    this.cacheWidth,
  });

  final String title;
  final String? cover, subtitle, badge, progressLabel, heroTag;
  final String metadata;
  final double? progress;
  final bool? cacheWidth;
  final bool selected, selecting;
  final VoidCallback? onTap, onLongPress, onSecondaryTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget image = NetworkImgLayer(
      src: cover,
      width: 92,
      height: 58,
      cacheWidth: cacheWidth,
      borderRadius: BorderRadius.circular(8),
    );
    if (heroTag != null) image = Hero(tag: heroTag!, child: image);
    const titleSize = 15.0;
    final coverColumn = SizedBox(
      width: 92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              image,
              if (selecting)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      selected
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.circle,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
          if (badge?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                badge!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
    final info = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: titleSize,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        if (subtitle?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          metadata,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (progressLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            progressLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
          if (progress != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 2,
              ),
            ),
        ],
      ],
    );
    final action = trailing == null
        ? null
        : SizedBox.square(dimension: 48, child: trailing!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Semantics(
        selected: selecting ? selected : null,
        child: Material(
          color: NewbiliFormStyle.card(context),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            onSecondaryTap: onSecondaryTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textWidth =
                      constraints.maxWidth -
                      92 -
                      10 -
                      (action == null ? 0 : 48);
                  // Keep at least seven title glyphs per line at the user's
                  // selected text size; use full-width text on narrow screens.
                  if (textWidth <
                      MediaQuery.textScalerOf(context).scale(titleSize) * 7) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [coverColumn, ?action],
                        ),
                        const SizedBox(height: 10),
                        info,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      coverColumn,
                      const SizedBox(width: 10),
                      Expanded(child: info),
                      ?action,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NewbiliLibrarySkeleton extends StatelessWidget {
  const NewbiliLibrarySkeleton({super.key});

  @override
  Widget build(BuildContext context) => SliverList.builder(
    itemCount: 6,
    itemBuilder: (context, _) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: NewbiliFormStyle.card(context),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ),
  );
}
