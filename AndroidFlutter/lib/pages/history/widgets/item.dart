import 'package:PiliPlus/common/widgets/newbili_library.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

class HistoryItem extends StatelessWidget {
  const HistoryItem({
    super.key,
    required this.item,
    required this.ctr,
    required this.onDelete,
  });

  final HistoryItemModel item;
  final MultiSelectBase ctr;
  final void Function(int kid, String business) onDelete;

  @override
  Widget build(BuildContext context) {
    final business = item.history.business;
    final enableMultiSelect = ctr.enableMultiSelect.value;
    final hasDuration = item.duration != null && item.duration != 0;
    final hasProgress =
        hasDuration && item.progress != null && item.progress != 0;
    final subtitle = business == 'pgc' && item.showTitle?.isNotEmpty == true
        ? item.showTitle
        : item.authorName;
    final viewedAt = item.viewAt == null
        ? ''
        : DateFormatUtils.chatFormat(item.viewAt!, isHistory: true);
    final metadata = subtitle == item.authorName || item.authorName == null
        ? viewedAt
        : [
            item.authorName,
            viewedAt,
          ].where((value) => value?.isNotEmpty == true).join(' · ');

    final onLongPress = enableMultiSelect
        ? null
        : () => ctr
            ..enableMultiSelect.value = true
            ..onSelect(item);

    return NewbiliLibraryTile(
      title: item.title ?? '未命名内容',
      cover: item.cover?.isNotEmpty == true
          ? item.cover
          : item.covers?.firstOrNull,
      subtitle: subtitle,
      metadata: metadata,
      badge: item.isFav == 1 ? '已收藏' : item.badge,
      progressLabel: hasProgress
          ? item.progress == -1
                ? '已看完'
                : '看到 ${DurationUtils.formatDuration(item.progress)} / ${DurationUtils.formatDuration(item.duration)}'
          : null,
      progress: hasProgress
          ? item.progress == -1
                ? 1
                : item.progress! / item.duration!
          : null,
      selected: item.checked,
      selecting: enableMultiSelect,
      onTap: enableMultiSelect ? () => ctr.onSelect(item) : _open,
      onLongPress: onLongPress,
      onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
      trailing: enableMultiSelect ? null : _menu(context, business),
    );
  }

  Future<void> _open() async {
    final business = item.history.business;
    if (business?.contains('article') == true) {
      PageUtils.toDupNamed(
        '/articlePage',
        parameters: {
          'id': business == 'article-list'
              ? '${item.history.cid}'
              : '${item.history.oid}',
          'type': 'read',
        },
      );
      return;
    }
    if (business == 'live') {
      if (item.liveStatus == 1) {
        PageUtils.toLiveRoom(item.history.oid);
      } else {
        SmartDialog.showToast('直播未开播');
      }
      return;
    }
    if (business == 'pgc') {
      PageUtils.viewPgc(
        epId: item.history.epid,
        progress: item.playbackProgress,
      );
      return;
    }
    if (business == 'cheese') {
      if (item.uri?.isNotEmpty == true) {
        PageUtils.viewPgcFromUri(
          item.uri!,
          isPgc: false,
          aid: item.history.oid,
          progress: item.playbackProgress,
        );
      }
      return;
    }

    final aid = item.history.oid!;
    final bvid = item.history.bvid ?? IdUtils.av2bv(aid);
    int? cid = item.history.cid;
    Dimension? dimension;
    if (cid == null) {
      if (await SearchHttp.ab2cWithDimension(
            aid: aid,
            bvid: bvid,
            part: item.history.page,
          )
          case final res?) {
        cid = res.cid;
        dimension = res.dimension;
      }
    }
    if (cid != null) {
      PageUtils.toVideoPage(
        aid: aid,
        bvid: bvid,
        cid: cid,
        cover: item.cover,
        title: item.title,
        dimension: dimension,
        progress: item.playbackProgress,
      );
    }
  }

  Widget _menu(BuildContext context, String? business) => PopupMenuButton(
    padding: EdgeInsets.zero,
    tooltip: '功能菜单',
    icon: Icon(
      Icons.more_horiz_rounded,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    position: PopupMenuPosition.under,
    itemBuilder: (_) => [
      if (item.authorMid != null && item.authorName?.isNotEmpty == true)
        PopupMenuItem(
          onTap: () => Get.toNamed('/member?mid=${item.authorMid}'),
          child: Row(
            children: [
              const Icon(MdiIcons.accountCircleOutline, size: 20),
              const SizedBox(width: 10),
              Flexible(child: Text('访问：${item.authorName}')),
            ],
          ),
        ),
      if (business != 'pgc' &&
          item.badge != '番剧' &&
          item.tagName?.contains('动画') != true &&
          business != 'live' &&
          business?.contains('article') != true)
        PopupMenuItem(
          onTap: () => UserHttp.toViewLater(bvid: item.history.bvid),
          child: const Row(
            children: [
              Icon(Icons.watch_later_outlined, size: 20),
              SizedBox(width: 10),
              Text('稍后再看'),
            ],
          ),
        ),
      PopupMenuItem(
        onTap: () => onDelete(item.kid!, business!),
        child: const Row(
          children: [
            Icon(Icons.delete_outline, size: 20),
            SizedBox(width: 10),
            Text('删除记录'),
          ],
        ),
      ),
    ],
  );
}
