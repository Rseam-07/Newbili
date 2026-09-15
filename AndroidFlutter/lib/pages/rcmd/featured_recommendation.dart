import 'dart:ui' as ui;

import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/newbili_cover_hero.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Tablet composition inspired by Richasy's original BiliBili-UWP:
/// selected artwork + details, with a horizontally browsable recommendation row.
/// Selection is explicit; it never advances while someone is reading.
class TabletRecommendationStage extends StatefulWidget {
  const TabletRecommendationStage({
    super.key,
    required this.items,
    required this.onRefresh,
    required this.onLoadMore,
    this.onRemove,
    this.onOpen,
    this.coverBuilder,
    this.lastRefreshAt,
  });
  final List<BaseRcmdVideoItemModel> items;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMore;
  final ValueChanged<BaseRcmdVideoItemModel>? onRemove;
  final void Function(BaseRcmdVideoItemModel item, Object tag)? onOpen;
  final Widget Function(BaseRcmdVideoItemModel item)? coverBuilder;
  final int? lastRefreshAt;

  @override
  State<TabletRecommendationStage> createState() =>
      _TabletRecommendationStageState();
}

class _TabletRecommendationStageState extends State<TabletRecommendationStage> {
  final _scroll = ScrollController();
  late BaseRcmdVideoItemModel _selected = widget.items.first;
  // Each selection keeps its own source, even if the feed contains duplicates.
  final _coverTags = <BaseRcmdVideoItemModel, Object>{};

  @override
  void didUpdateWidget(TabletRecommendationStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.items.contains(_selected)) _selected = widget.items.first;
    _coverTags.removeWhere((item, _) => !widget.items.contains(item));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Object get _tag => _coverTags.putIfAbsent(_selected, Object.new);

  void _open() {
    if (widget.onOpen case final onOpen?) {
      onOpen(_selected, _tag);
    } else {
      VideoCardV(videoItem: _selected)
          .onPushDetail(coverHeroTag: _tag, context: context);
    }
  }

  Widget _cover(BaseRcmdVideoItemModel item) =>
      widget.coverBuilder?.call(item) ??
      LayoutBuilder(
        builder: (context, constraints) => NetworkImgLayer(
          src: item.cover,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          borderRadius: BorderRadius.zero,
        ),
      );

  void _move(int direction) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      (_scroll.offset + direction * 456).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      ),
      duration: NewbiliMotion.duration(context, NewbiliMotion.container),
      curve: NewbiliMotion.emphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 760 ||
            MediaQuery.textScalerOf(context).scale(16) > 24;
        final titleStyle = TextStyle(
          fontSize: compact ? 22 : 26,
          fontWeight: FontWeight.w600,
          height: 1.45,
        );
        final cover = Semantics(
          label: '播放 ${_selected.title}',
          button: true,
          child: AspectRatio(
            aspectRatio: Style.aspectRatio16x9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NewbiliCoverHero(
                  tag: _tag,
                  radius: 10,
                  child: _cover(_selected),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: _open,
                    borderRadius: BorderRadius.circular(10),
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .48),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_selected.duration > 0)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .64),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        DurationUtils.formatDuration(_selected.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selected.rcmdReason?.isNotEmpty == true
                  ? _selected.rcmdReason!
                  : '为你推荐',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selected.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(
                  Icons.account_box_outlined,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selected.owner.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${NumUtils.numFormat(_selected.stat.view)} 次观看   ·   ${NumUtils.numFormat(_selected.stat.danmu)} 条弹幕',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            if (_selected.desc?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                _selected.desc!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Flexible(
                  child: FilledButton.icon(
                    onPressed: _open,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text('播放视频'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox.square(
                  dimension: 48,
                  child: VideoPopupMenu(
                    iconSize: 22,
                    videoItem: _selected,
                    onRemove: widget.onRemove == null
                        ? null
                        : () => widget.onRemove!(_selected),
                  ),
                ),
              ],
            ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: colors.brightness == Brightness.dark
                              ? .12
                              : .08,
                          child: ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: 40,
                              sigmaY: 40,
                            ),
                            child: _cover(_selected),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    child: compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [cover, const SizedBox(height: 24), info],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(flex: 6, child: cover),
                              const SizedBox(width: 32),
                              Expanded(flex: 5, child: info),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '推荐视频',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('换一换'),
                  ),
                  IconButton(
                    onPressed: () => _move(-1),
                    tooltip: '上一组推荐',
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    onPressed: () => _move(1),
                    tooltip: '下一组推荐',
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            SizedBox(
              height:
                  218 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 3,
              child: Scrollbar(
                controller: _scroll,
                child: NotificationListener<ScrollUpdateNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.extentAfter < 400) {
                      widget.onLoadMore();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    itemCount: widget.items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final selected = identical(item, _selected);
                      return SizedBox(
                        width: 212,
                        child: Semantics(
                          selected: selected,
                          button: true,
                          label:
                              '${item.title}${selected ? '，再次点击播放' : '，查看详情'}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              key: ValueKey('tablet-recommendation-$index'),
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                if (selected) {
                                  _open();
                                  return;
                                }
                                setState(() => _selected = item);
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedContainer(
                                    duration: NewbiliMotion.duration(
                                      context,
                                      NewbiliMotion.feedback,
                                    ),
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        width: 2,
                                        color: selected
                                            ? colors.primary
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: AspectRatio(
                                        aspectRatio: Style.aspectRatio16x9,
                                        child: _cover(item),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.45,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: Text(
                                      index == widget.lastRefreshAt
                                          ? '上次看到这里'
                                          : item.owner.name ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
