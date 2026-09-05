import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/progress_bar/video_progress_indicator.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/horizontal_video_model.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

// 视频卡片 - 水平布局
class VideoCardH extends StatelessWidget {
  const VideoCardH({
    super.key,
    required this.videoItem,
    this.onTap,
    this.onViewLater,
    this.onRemove,
    this.compact = false,
  });
  final HorizontalVideoModel videoItem;
  final VoidCallback? onTap;
  final ValueChanged<int>? onViewLater;
  final VoidCallback? onRemove;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    void onLongPress() => imageSaveDialog(
      bvid: videoItem.bvid,
      title: videoItem.title,
      cover: videoItem.cover,
    );
    final theme = Theme.of(context);
    return Material(
      type: compact ? MaterialType.canvas : MaterialType.transparency,
      color: compact ? NewbiliFormStyle.card(context) : null,
      borderRadius: compact ? BorderRadius.circular(18) : null,
      clipBehavior: compact ? Clip.antiAlias : Clip.none,
      child: Stack(
        clipBehavior: .none,
        children: [
          InkWell(
            onLongPress: onLongPress,
            onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
            onTap:
                onTap ??
                () async {
                  if (videoItem.isPugv ?? false) {
                    PageUtils.viewPugv(seasonId: videoItem.seasonId);
                    return;
                  }

                  if (videoItem.isLive ?? false) {
                    if (videoItem.roomId case final roomId?) {
                      PageUtils.toLiveRoom(roomId);
                    }
                    return;
                  }

                  if (videoItem.redirectUrl?.isNotEmpty == true &&
                      PageUtils.viewPgcFromUri(videoItem.redirectUrl!)) {
                    return;
                  }

                  int? cid = videoItem.cid;
                  Dimension? dimension = videoItem.dimension;
                  if (cid == null) {
                    if (await SearchHttp.ab2cWithDimension(
                          aid: videoItem.aid,
                          bvid: videoItem.bvid,
                        )
                        case final res?) {
                      cid = res.cid;
                      dimension = res.dimension;
                    }
                  }
                  if (cid != null) {
                    PageUtils.toVideoPage(
                      bvid: videoItem.bvid,
                      cid: cid,
                      cover: videoItem.cover,
                      title: videoItem.title,
                      dimension: dimension,
                    );
                  }
                },
            child: compact
                ? _compactBody(context)
                : Padding(
                    padding: const .symmetric(
                      horizontal: Style.safeSpace,
                      vertical: 5,
                    ),
                    child: Row(
                      crossAxisAlignment: .start,
                      children: [
                        AspectRatio(
                          aspectRatio: Style.aspectRatio,
                          child: LayoutBuilder(
                            builder: (context, boxConstraints) {
                              final double maxWidth = boxConstraints.maxWidth;
                              final double maxHeight = boxConstraints.maxHeight;

                              return _cover(
                                theme,
                                width: maxWidth,
                                height: maxHeight,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        content(theme),
                      ],
                    ),
                  ),
          ),
          Positioned(
            bottom: 0,
            right: compact ? 4 : 12,
            width: compact ? 48 : 29,
            height: compact ? 48 : 29,
            child: VideoPopupMenu(
              iconSize: 17,
              videoItem: videoItem,
              onRemove: onRemove,
            ),
          ),
        ],
      ),
    );
  }

  static double compactHeightOf(BuildContext context) =>
      108 +
      (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(
            0,
            double.infinity,
          ) *
          5;

  Widget _compactBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: compactHeightOf(context),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cover(
              Theme.of(context),
              width: 140,
              height: 88,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: videoItem.titleList?.isNotEmpty == true
                            ? videoItem.titleList!
                                  .map(
                                    (part) => TextSpan(
                                      text: part.text,
                                      style: TextStyle(
                                        color: part.isEm
                                            ? scheme.primary
                                            : scheme.onSurface,
                                      ),
                                    ),
                                  )
                                  .toList()
                            : [TextSpan(text: videoItem.title)],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 38),
                    child: Text(
                      videoItem.owner.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 38),
                    child: Text(
                      '${DurationUtils.formatDuration(videoItem.duration)} · ${NumUtils.numFormat(videoItem.stat.view)}观看',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover(
    ThemeData theme, {
    required double width,
    required double height,
  }) {
    final progress = videoItem.progress;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          NetworkImgLayer(
            src: videoItem.cover,
            width: width,
            height: height,
            borderRadius: compact ? BorderRadius.circular(12) : Style.mdRadius,
          ),
          if (videoItem.badge case final badge?)
            PBadge(
              text: badge,
              top: 6,
              right: 6,
              type: badge == '充电专属' ? .error : .primary,
            ),
          if (progress != null && progress != 0) ...[
            PBadge(
              text: progress == -1
                  ? '已看完'
                  : '${DurationUtils.formatDuration(progress)}/${DurationUtils.formatDuration(videoItem.duration)}',
              right: 6,
              bottom: 8,
              type: .gray,
            ),
            Positioned(
              left: 0,
              bottom: 0,
              right: 0,
              child: VideoProgressIndicator(
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.secondaryContainer,
                progress: progress == -1
                    ? 1
                    : videoItem.duration > 0
                    ? (progress / videoItem.duration).clamp(0, 1)
                    : 0,
              ),
            ),
          ] else if (!compact && videoItem.duration > 0)
            PBadge(
              text: DurationUtils.formatDuration(videoItem.duration),
              right: 6,
              bottom: 6,
              type: .gray,
            ),
        ],
      ),
    );
  }

  Widget content(ThemeData theme) {
    String pubdate = DateFormatUtils.dateFormat(videoItem.pubdate!);
    if (pubdate != '') pubdate += '  ';
    return Expanded(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (videoItem.titleList?.isNotEmpty == true)
            Expanded(
              child: Text.rich(
                overflow: .ellipsis,
                maxLines: 2,
                TextSpan(
                  children: videoItem.titleList!
                      .map(
                        (e) => TextSpan(
                          text: e.text,
                          style: TextStyle(
                            fontSize: theme.textTheme.bodyMedium!.fontSize,
                            height: 1.42,
                            letterSpacing: 0.3,
                            color: e.isEm
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            )
          else
            Expanded(
              child: Text(
                videoItem.title,
                textAlign: .start,
                style: TextStyle(
                  fontSize: theme.textTheme.bodyMedium!.fontSize,
                  height: 1.42,
                  letterSpacing: 0.3,
                ),
                maxLines: 2,
                overflow: .ellipsis,
              ),
            ),
          Text(
            "$pubdate${videoItem.owner.name}",
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              height: 1,
              color: theme.colorScheme.outline,
              overflow: .clip,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            spacing: 8,
            children: [
              StatWidget(
                type: .play,
                value: videoItem.stat.view,
              ),
              StatWidget(
                type: .danmaku,
                value: videoItem.stat.danmu,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
