import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/pages/home/home_header.dart';
import 'package:material_ui/material_ui.dart';

/// Resizes the same live player while a nearby, independently scrolling pane
/// opens. Changing pane content never navigates away from playback.
class TabletPlayerStage extends StatefulWidget {
  const TabletPlayerStage({
    super.key,
    required this.playerBuilder,
    required this.details,
    this.related,
    this.secondary,
    this.extraPane,
    required this.onSendDanmaku,
    this.backButton = const BackButton(),
  });
  final Widget Function(double width, double height) playerBuilder;
  final Widget details;
  final Widget? related;
  final Widget? secondary;
  final Widget? extraPane;
  final VoidCallback onSendDanmaku;
  final Widget backButton;
  @override
  State<TabletPlayerStage> createState() => _TabletPlayerStageState();
}

class _TabletPlayerStageState extends State<TabletPlayerStage>
    with SingleTickerProviderStateMixin {
  late final _pane = AnimationController(
    vsync: this,
    duration: NewbiliMotion.container,
  );
  int? _selected;
  final _visited = <int>{};
  bool get _open => _selected != null;
  int _lastSelected = 0;

  void _select(int index) {
    setState(() {
      _selected = _selected == index ? null : index;
      _lastSelected = index;
      _visited.add(index);
    });
    if (NewbiliMotion.reduced(context)) {
      _pane.value = _open ? 1 : 0;
    } else {
      _pane.animateTo(_open ? 1 : 0, curve: NewbiliMotion.emphasized);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NewbiliMotion.reduced(context)) _pane.value = _open ? 1 : 0;
  }

  @override
  void dispose() {
    _pane.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return Material(
      color: colors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
            child: Row(
              children: [
                widget.backButton,
                const SizedBox(width: 12),
                NewbiliWordmark(
                  compact: MediaQuery.textScalerOf(context).scale(14) > 20,
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final paneWidth = (bounds.maxWidth * .34).clamp(300.0, 400.0);
                return AnimatedBuilder(
                  animation: _pane,
                  builder: (context, _) => Row(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final playerWidth = (box.maxWidth - 32).clamp(
                              0.0,
                              double.infinity,
                            );
                            final playerHeight = (playerWidth * 9 / 16).clamp(
                              0.0,
                              box.maxHeight * .62,
                            );
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: widget.playerBuilder(
                                      playerWidth,
                                      playerHeight,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 8,
                                    children: [
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          minimumSize: const Size(48, 48),
                                        ),
                                        onPressed: widget.onSendDanmaku,
                                        icon: const Icon(
                                          Icons.edit_note_rounded,
                                          size: 20,
                                        ),
                                        label: const Text('发弹幕'),
                                      ),
                                      if (widget.secondary != null)
                                        _paneButton(
                                          0,
                                          _selected == 0 ? '收起评论' : '评论与列表',
                                          Icons.chat_bubble_outline_rounded,
                                        ),
                                      if (widget.extraPane != null)
                                        _paneButton(
                                          1,
                                          _selected == 1 ? '收起动态' : '边看边逛动态',
                                          Icons.dynamic_feed_outlined,
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: widget.details),
                                        if (widget.related != null) ...[
                                          const SizedBox(width: 16),
                                          Expanded(child: widget.related!),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      ClipRect(
                        child: Align(
                          alignment: Alignment.centerRight,
                          widthFactor: _pane.value,
                          child: SizedBox(
                            width: paneWidth,
                            child: IgnorePointer(
                              ignoring: !_open,
                              child: ExcludeSemantics(
                                excluding: !_open,
                                child: TickerMode(
                                  enabled: _open,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainerLowest,
                                      border: Border(
                                        left: BorderSide(
                                          color: colors.outlineVariant,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 16,
                                            right: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _lastSelected == 0
                                                      ? '评论'
                                                      : '动态',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: '关闭侧栏',
                                                onPressed: () =>
                                                    _select(_lastSelected),
                                                icon: const Icon(
                                                  Icons.close_rounded,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: LayoutBuilder(
                                            builder: (context, constraints) => MediaQuery(
                                              data: MediaQuery.of(context)
                                                  .copyWith(
                                                    size: Size(
                                                      paneWidth,
                                                      constraints.maxHeight,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    viewPadding:
                                                        EdgeInsets.zero,
                                                  ),
                                              child: IndexedStack(
                                                index: _lastSelected,
                                                children: [
                                                  _visited.contains(0)
                                                      ? widget.secondary ??
                                                            const SizedBox.shrink()
                                                      : const SizedBox.shrink(),
                                                  _visited.contains(1)
                                                      ? widget.extraPane ??
                                                            const SizedBox.shrink()
                                                      : const SizedBox.shrink(),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _paneButton(int index, String label, IconData icon) => TextButton.icon(
    onPressed: () => _select(index),
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      backgroundColor: _selected == index
          ? ColorScheme.of(context).secondaryContainer
          : null,
    ),
    icon: Icon(icon, size: 20),
    label: Text(label),
  );
}
