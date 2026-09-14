import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/newbili_library.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models_new/later/list.dart';
import 'package:PiliPlus/pages/later/controller.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

class VideoCardHLater extends StatelessWidget {
  const VideoCardHLater({
    super.key,
    required this.ctr,
    required this.videoItem,
    required this.onViewLater,
  });

  final BaseLaterController ctr;
  final LaterItemModel videoItem;
  final ValueChanged<int> onViewLater;

  @override
  Widget build(BuildContext context) {
    final enableMultiSelect = ctr.enableMultiSelect.value;
    final isPgc = videoItem.isPgc == true && videoItem.bangumi != null;
    final duration = videoItem.duration ?? 0;
    final progress = videoItem.progress;
    final hasProgress = progress != null && progress != 0 && duration > 0;
    final onLongPress = enableMultiSelect
        ? null
        : () => ctr
            ..enableMultiSelect.value = true
            ..onSelect(videoItem);

    return NewbiliLibraryTile(
      title: isPgc
          ? videoItem.bangumi?.season?.title ?? videoItem.title ?? '未命名内容'
          : videoItem.title ?? '未命名内容',
      cover: videoItem.pic,
      cacheWidth: videoItem.dimension?.cacheWidth,
      subtitle: isPgc ? videoItem.subtitle : videoItem.owner?.name,
      metadata:
          '${NumUtils.numFormat(videoItem.stat?.view)}次观看 · ${NumUtils.numFormat(videoItem.stat?.danmaku)}弹幕',
      badge: _badge(duration),
      progressLabel: hasProgress
          ? progress == -1
                ? '已看完'
                : '看到 ${DurationUtils.formatDuration(progress)} / ${DurationUtils.formatDuration(duration)}'
          : null,
      progress: hasProgress
          ? progress == -1
                ? 1
                : progress / duration
          : null,
      selected: videoItem.checked,
      selecting: enableMultiSelect,
      onLongPress: onLongPress,
      onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
      onTap: enableMultiSelect ? () => ctr.onSelect(videoItem) : _open,
      trailing: enableMultiSelect
          ? null
          : iconButton(
              size: 48,
              iconSize: 22,
              tooltip: '从稍后再看移除',
              onPressed: videoItem.aid == null
                  ? null
                  : () => ctr.toViewDel(context, videoItem.aid!),
              icon: const Icon(Icons.close_rounded),
              iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
    );
  }

  String? _badge(int duration) {
    if (videoItem.isCharging == true) return '充电专属';
    if (videoItem.rights?.isCooperation == 1) return '合作';
    if (videoItem.pgcLabel?.isNotEmpty == true) return videoItem.pgcLabel;
    if (videoItem.isPugv == true) return '课堂';
    if (duration > 0 &&
        (videoItem.progress == null || videoItem.progress == 0)) {
      return DurationUtils.formatDuration(duration);
    }
    return null;
  }

  Future<void> _open() async {
    if (videoItem.isPugv == true) {
      PageUtils.viewPugv(seasonId: videoItem.aid);
      return;
    }
    if (videoItem.isPgc == true) {
      if (videoItem.bangumi?.epId != null) {
        PageUtils.viewPgc(epId: videoItem.bangumi!.epId);
      } else if (videoItem.redirectUrl?.isNotEmpty == true) {
        PageUtils.viewPgcFromUri(videoItem.redirectUrl!);
      }
      return;
    }
    try {
      final cid =
          videoItem.cid ??
          await SearchHttp.ab2c(aid: videoItem.aid, bvid: videoItem.bvid);
      if (cid != null) onViewLater(cid);
    } catch (err) {
      SmartDialog.showToast(err.toString());
    }
  }
}
