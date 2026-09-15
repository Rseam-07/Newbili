import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/pages/home/home_header.dart';
import 'package:material_ui/material_ui.dart';

/// Wide playback retains the video's place while comments open beside it.
/// The player stays in one subtree as the panel's width changes.
class TabletPlayerStage extends StatefulWidget {
  const TabletPlayerStage({
    super.key,
    required this.playerBuilder,
    required this.details,
    this.related,
    this.secondary,
    required this.onSendDanmaku,
    this.backButton = const BackButton(),
  });
  final Widget Function(double width, double height) playerBuilder;
  final Widget details;
  final Widget? related;
  final Widget? secondary;
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
  bool _open = false;
  bool _visited = false;
  void _toggle() {
    setState(() {
      _open = !_open;
      _visited = true;
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
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
            child: Row(
              children: [
                widget.backButton,
                const SizedBox(width: 12),
                NewbiliWordmark(
                  compact: MediaQuery.textScalerOf(context).scale(14) > 20,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.onSendDanmaku,
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  label: const Text('发弹幕'),
                ),
                if (widget.secondary != null) ...[
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _toggle,
                    icon: Icon(
                      _open
                          ? Icons.close_rounded
                          : Icons.chat_bubble_outline_rounded,
                      size: 18,
                    ),
                    label: Text(_open ? '收起评论' : '评论与列表'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _pane,
              builder: (context, _) => Row(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final largeText =
                            MediaQuery.textScalerOf(context).scale(14) > 20;
                        final relatedHeight = widget.related == null
                            ? 0.0
                            : (230 +
                                      (MediaQuery.textScalerOf(context)
                                                  .scale(14) -
                                              14) *
                                          3)
                                  .clamp(230.0, box.maxHeight * .5);
                        return Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  12,
                                  24,
                                  16,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final width = constraints.maxWidth;
                                          final height = (width * 9 / 16).clamp(
                                            0.0,
                                            constraints.maxHeight,
                                          );
                                          return Align(
                                            alignment: Alignment.topCenter,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: widget.playerBuilder(
                                                width,
                                                height,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      flex: largeText ? 6 : 5,
                                      child: widget.details,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (widget.related != null) ...[
                              const Padding(
                                padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '接下来播放',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: relatedHeight,
                                child: widget.related,
                              ),
                            ],
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
                        width: 360,
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
                                child: _visited && widget.secondary != null
                                    ? LayoutBuilder(
                                        builder: (context, constraints) =>
                                            MediaQuery(
                                              data: MediaQuery.of(context)
                                                  .copyWith(
                                                    size: Size(
                                                      360,
                                                      constraints.maxHeight,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    viewPadding:
                                                        EdgeInsets.zero,
                                                  ),
                                              child: widget.secondary!,
                                            ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
