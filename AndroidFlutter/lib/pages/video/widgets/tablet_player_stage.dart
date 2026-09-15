import 'dart:ui' show lerpDouble;

import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/common/widgets/newbili_destination_view.dart';
import 'package:PiliPlus/pages/home/home_header.dart';
import 'package:material_ui/material_ui.dart';

/// One surface grows from its circular entry into a right-hand content card.
/// The same animation pushes the live player into the remaining 70% of space.
class TabletPlayerStage extends StatefulWidget {
  const TabletPlayerStage({
    super.key,
    required this.playerBuilder,
    required this.details,
    this.secondary,
    this.extraPane,
    this.playlist,
    this.selectedPane,
    this.onPaneChanged,
    this.initialOpen = false,
    this.onOpenChanged,
    required this.onSendDanmaku,
    this.backButton = const BackButton(),
  });
  final Widget Function(double width, double height) playerBuilder;
  final Widget details;
  final Widget? secondary;
  final Widget? extraPane;
  final Widget? playlist;
  final String? selectedPane;
  final ValueChanged<String>? onPaneChanged;
  final bool initialOpen;
  final ValueChanged<bool>? onOpenChanged;
  final VoidCallback onSendDanmaku;
  final Widget backButton;
  @override
  State<TabletPlayerStage> createState() => _TabletPlayerStageState();
}

class _TabletPlayerStageState extends State<TabletPlayerStage>
    with SingleTickerProviderStateMixin {
  String _selected = '简介';
  late bool _open = widget.initialOpen;
  late bool _visited = _open;
  late final _expansion = AnimationController(
    vsync: this,
    value: _open ? 1 : 0,
    duration: NewbiliMotion.container,
  );

  void _toggle() {
    setState(() {
      _open = !_open;
      _visited = true;
    });
    widget.onOpenChanged?.call(_open);
    if (NewbiliMotion.reduced(context)) {
      _expansion.value = _open ? 1 : 0;
    } else {
      _expansion.animateTo(
        _open ? 1 : 0,
        duration: _open ? NewbiliMotion.container : NewbiliMotion.exit,
        curve: NewbiliMotion.emphasized,
      );
    }
  }

  void _select(String name) {
    setState(() => _selected = name);
    widget.onPaneChanged?.call(name);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NewbiliMotion.reduced(context)) _expansion.value = _open ? 1 : 0;
  }

  @override
  void dispose() {
    _expansion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    final panes = <String, Widget>{
      '简介': widget.details,
      if (widget.secondary != null) '评论': widget.secondary!,
      if (widget.extraPane != null) '动态': widget.extraPane!,
      if (widget.playlist != null) '选集': widget.playlist!,
    };
    final names = panes.keys.toList();
    final selected = names.indexOf(widget.selectedPane ?? _selected);
    final index = selected < 0 ? 0 : selected;
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _open) _toggle();
      },
      child: Material(
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
                builder: (context, box) {
                  final paneExtent = box.maxWidth * .3;
                  final card = Rect.fromLTWH(
                    box.maxWidth - paneExtent + 12,
                    12,
                    paneExtent - 24,
                    box.maxHeight - 24,
                  );
                  final ball = Rect.fromLTWH(
                    box.maxWidth - 76,
                    box.maxHeight * .5 - 28,
                    56,
                    56,
                  );
                  return AnimatedBuilder(
                    animation: _expansion,
                    builder: (context, _) {
                      final t = _expansion.value;
                      final bounds = Rect.lerp(ball, card, t)!;
                      final contentOpacity = ((t - .25) / .75).clamp(0.0, 1.0);
                      return Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            right: paneExtent * t,
                            child: ColoredBox(
                              color: Colors.black,
                              child: LayoutBuilder(
                                builder: (context, playerBox) =>
                                    widget.playerBuilder(
                                      playerBox.maxWidth,
                                      playerBox.maxHeight,
                                    ),
                              ),
                            ),
                          ),
                          Positioned.fromRect(
                            rect: bounds,
                            child: Material(
                              key: const ValueKey('tablet-content-surface'),
                              color: Color.lerp(
                                colors.secondaryContainer,
                                colors.surfaceContainerLow,
                                t,
                              ),
                              elevation: lerpDouble(4, 1, t)!,
                              shadowColor: colors.shadow.withValues(alpha: .24),
                              borderRadius: BorderRadius.circular(
                                lerpDouble(28, 20, t)!,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (_visited)
                                    IgnorePointer(
                                      ignoring: !_open || t < .99,
                                      child: ExcludeSemantics(
                                        excluding: !_open || t < .99,
                                        child: Opacity(
                                          opacity: contentOpacity,
                                          child: OverflowBox(
                                            alignment: Alignment.topRight,
                                            minWidth: card.width,
                                            maxWidth: card.width,
                                            minHeight: card.height,
                                            maxHeight: card.height,
                                            child: MediaQuery(
                                              data: MediaQuery.of(context)
                                                  .copyWith(
                                                    size: card.size,
                                                    padding: EdgeInsets.zero,
                                                    viewPadding:
                                                        EdgeInsets.zero,
                                                  ),
                                              child: ExcludeFocus(
                                                excluding: !_open,
                                                child: TickerMode(
                                                  enabled: _open,
                                                  child: _cardContent(
                                                    context,
                                                    panes,
                                                    index,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (t < .35)
                                    IgnorePointer(
                                      ignoring: _open,
                                      child: ExcludeSemantics(
                                        excluding: _open,
                                        child: Opacity(
                                          opacity: (1 - t / .35).clamp(
                                            0.0,
                                            1.0,
                                          ),
                                          child: Tooltip(
                                            message: '打开简介、评论与动态',
                                            child: InkWell(
                                              onTap: _toggle,
                                              child: Icon(
                                                Icons.forum_outlined,
                                                size: 26,
                                                color:
                                                    colors.onSecondaryContainer,
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
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardContent(
    BuildContext context,
    Map<String, Widget> panes,
    int index,
  ) {
    final colors = ColorScheme.of(context);
    final names = panes.keys.toList();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < names.length; i++)
                      Semantics(
                        selected: i == index,
                        button: true,
                        child: InkWell(
                          onTap: () => _select(names[i]),
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: 52,
                              minWidth: 64,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: i == index
                                      ? colors.primary
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              names[i],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: i == index
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: i == index
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: '收起内容卡片',
              onPressed: _toggle,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        Expanded(
          child: NewbiliDestinationView(
            key: ValueKey(names.join('|')),
            index: index,
            children: panes.values.toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: widget.onSendDanmaku,
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: const Text('发弹幕'),
            ),
          ),
        ),
      ],
    );
  }
}
