import 'package:PiliPlus/common/widgets/newbili_cover_hero.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/dimension_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

// 视频卡片 - 垂直布局
class VideoCardV extends StatelessWidget {
  final BaseRcmdVideoItemModel videoItem;
  final VoidCallback? onRemove;
  final WidgetBuilder? coverBuilder;
  final ValueChanged<Object>? onOpen;

  const VideoCardV({
    super.key,
    required this.videoItem,
    this.onRemove,
    this.coverBuilder,
    this.onOpen,
  });

  static double metadataHeightOf(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return 12 +
        scaler.scale(39.2) +
        scaler.scale(15.4).clamp(48.0, double.infinity);
  }

  Future<void> onPushDetail({
    Object? coverHeroTag,
    BuildContext? context,
  }) async {
    switch (videoItem.goto) {
      case 'bangumi':
        PageUtils.viewPgc(epId: videoItem.param!);
        break;
      case 'av':
        var bvid = videoItem.bvid ?? IdUtils.av2bv(videoItem.aid!);
        var cid = videoItem.cid;
        bool isVertical = false;
        Dimension? dimension;
        if (videoItem is RcmdVideoItemAppModel) {
          if (videoItem.uri case final uri?) {
            isVertical = uri.isVerticalFromUri;
          }
        }
        if (cid == null) {
          if (await SearchHttp.ab2cWithDimension(aid: videoItem.aid, bvid: bvid)
              case final res?) {
            cid = res.cid;
            dimension = res.dimension;
          }
        }
        if (context != null && !context.mounted) return;
        if (cid != null) {
          PageUtils.toVideoPage(
            aid: videoItem.aid,
            bvid: bvid,
            cid: cid,
            cover: videoItem.cover,
            coverHeroTag: coverHeroTag,
            title: videoItem.title,
            isVertical: isVertical,
            dimension: dimension,
          );
        }
        break;
      // 动态
      case 'picture':
        try {
          PiliScheme.routePushFromUrl(videoItem.uri!);
        } catch (err) {
          SmartDialog.showToast(err.toString());
        }
        break;
      default:
        if (videoItem.uri?.isNotEmpty == true) {
          PiliScheme.routePushFromUrl(videoItem.uri!);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    void onLongPress() => imageSaveDialog(
      title: videoItem.title,
      cover: videoItem.cover,
      bvid: videoItem.bvid,
    );
    return NewbiliCoverSource(
      builder: (context, coverTag) => Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => onOpen != null
              ? onOpen!(coverTag)
              : onPushDetail(coverHeroTag: coverTag, context: context),
          onLongPress: onLongPress,
          onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: Style.aspectRatio,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    fit: StackFit.expand,
                    children: [
                      NewbiliCoverHero(
                        tag: coverTag,
                        radius: 8,
                        child:
                            coverBuilder?.call(context) ??
                            NetworkImgLayer(
                              src: videoItem.cover,
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              borderRadius: BorderRadius.zero,
                            ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0x99000000)],
                                stops: [.55, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 60,
                        bottom: 7,
                        child: Text(
                          '${NumUtils.numFormat(videoItem.stat.view)} 播放',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (videoItem.duration > 0)
                        PBadge(
                          bottom: 6,
                          right: 7,
                          size: .small,
                          type: .gray,
                          text: DurationUtils.formatDuration(
                            videoItem.duration,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              content(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget content(BuildContext context) {
    final theme = Theme.of(context);
    final hasMenu = videoItem.goto == 'av';
    final owner = [
      if (videoItem.isFollowed) '已关注',
      if (videoItem.goto == 'picture') '动态',
      if (videoItem.goto == 'bangumi') videoItem.pgcBadge,
      videoItem.owner.name,
    ].nonNulls.join(' · ');
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  videoItem.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.account_box_outlined,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    owner,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    semanticsLabel: 'UP：$owner',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (hasMenu)
                  SizedBox.square(
                    dimension: 48,
                    child: VideoPopupMenu(
                      iconSize: 18,
                      videoItem: videoItem,
                      onRemove: onRemove,
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static final shortFormat = DateFormat('M-d');
  static final longFormat = DateFormat('yy-M-d');

  Widget videoStat(ThemeData theme) => Text(
    [
      '${NumUtils.numFormat(videoItem.stat.view)}观看',
      if (videoItem.goto != 'picture' && videoItem.stat.danmu != null)
        '${NumUtils.numFormat(videoItem.stat.danmu)}弹幕',
      if (videoItem.pubdate != null)
        DateFormatUtils.dateFormat(
          videoItem.pubdate,
          short: shortFormat,
          long: longFormat,
        ),
    ].join(' · '),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 11,
      height: 1.4,
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}
