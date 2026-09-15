import 'dart:ui' show lerpDouble;

import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Lazy, retained destinations. Interruptions continue from the current frame.
/// A jump from the first to the fifth destination never mounts the middle three.
class NewbiliDestinationView extends StatefulWidget {
  const NewbiliDestinationView({
    super.key,
    required this.index,
    required this.children,
    this.baseIndex,
    this.paneTitle,
    this.onClosePane,
  }) : assert(index >= 0 && index < children.length);

  final int index;
  final List<Widget> children;

  /// On a wide tablet, retain this destination beside the selected subpage.
  final int? baseIndex;
  final String? paneTitle;
  final VoidCallback? onClosePane;

  @override
  State<NewbiliDestinationView> createState() => _NewbiliDestinationViewState();
}

class _NewbiliDestinationViewState extends State<NewbiliDestinationView>
    with TickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: NewbiliMotion.container,
    value: 1,
  );
  late final Set<int> _visited = {widget.index};
  late Map<int, ({double opacity, double x})> _from = {
    widget.index: (opacity: 1, x: 0),
  };
  late Map<int, ({double opacity, double x})> _to = Map.of(_from);
  late final _paneController = AnimationController(
    vsync: this,
    duration: NewbiliMotion.container,
    value: _hasPane ? 1 : 0,
  );
  bool get _hasPane =>
      widget.baseIndex != null && widget.index != widget.baseIndex;

  @override
  void initState() {
    super.initState();
    _retainBase();
  }

  void _retainBase() {
    if (widget.baseIndex case final index?) {
      _visited.add(index);
      _from.putIfAbsent(index, () => (opacity: 1, x: 0));
      _to.putIfAbsent(index, () => (opacity: 1, x: 0));
    }
  }

  ({double opacity, double x}) _pose(int index) {
    final start = _from[index]!;
    final end = _to[index]!;
    final t = NewbiliMotion.emphasized.transform(_controller.value);
    return (
      opacity: lerpDouble(start.opacity, end.opacity, t)!,
      x: lerpDouble(start.x, end.x, t)!,
    );
  }

  @override
  void didUpdateWidget(NewbiliDestinationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _retainBase();
    if (NewbiliMotion.reduced(context)) {
      _paneController.value = _hasPane ? 1 : 0;
    } else {
      _paneController.animateTo(
        _hasPane ? 1 : 0,
        curve: NewbiliMotion.emphasized,
      );
    }
    if (oldWidget.index == widget.index) return;
    final direction = widget.index > oldWidget.index ? 1.0 : -1.0;
    final current = {for (final index in _visited) index: _pose(index)};
    _visited.add(widget.index);
    current.putIfAbsent(widget.index, () => (opacity: 0, x: 28 * direction));
    // An already visited, hidden page should enter from the requested direction.
    if (current[widget.index]!.opacity == 0) {
      current[widget.index] = (opacity: 0, x: 28 * direction);
    }
    _from = current;
    _to = {
      for (final index in _visited)
        index: index == widget.index
            ? (opacity: 1, x: 0)
            : (opacity: 0, x: -20 * direction),
    };
    if (NewbiliMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NewbiliMotion.reduced(context)) _controller.value = 1;
    if (NewbiliMotion.reduced(context)) {
      _paneController.value = _hasPane ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _paneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final index
              in _visited.toList()..sort(
                (a, b) => a == b
                    ? 0
                    : a == widget.baseIndex
                    ? -1
                    : b == widget.baseIndex
                    ? 1
                    : a.compareTo(b),
              ))
            AnimatedBuilder(
              key: ValueKey(index),
              animation: Listenable.merge([_controller, _paneController]),
              child: HeroMode(
                enabled: index == widget.index || index == widget.baseIndex,
                child: TickerMode(
                  enabled: index == widget.index || index == widget.baseIndex,
                  child: widget.children[index],
                ),
              ),
              builder: (context, child) {
                final pose = _pose(index);
                final isBase = index == widget.baseIndex;
                final pane = widget.baseIndex != null && !isBase;
                final active = index == widget.index || isBase;
                final paneWidth = (constraints.maxWidth * .30).clamp(
                  340.0,
                  400.0,
                );
                if (pane) {
                  final colors = ColorScheme.of(context);
                  child = Material(
                    color: colors.surfaceContainerLowest,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: colors.outlineVariant),
                        ),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.paneTitle ?? '',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: widget.onClosePane,
                                  tooltip: '收起副页',
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                size: Size(
                                  paneWidth,
                                  constraints.maxHeight - 56,
                                ),
                                padding: EdgeInsets.zero,
                                viewPadding: EdgeInsets.zero,
                              ),
                              child: child!,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Positioned(
                  top: 0,
                  bottom: 0,
                  left: pane
                      ? constraints.maxWidth - paneWidth * _paneController.value
                      : 0,
                  right: pane
                      ? null
                      : isBase
                      ? paneWidth * _paneController.value
                      : 0,
                  width: pane ? paneWidth : null,
                  child: Offstage(
                    offstage:
                        !isBase && pose.opacity == 0 && index != widget.index,
                    child: IgnorePointer(
                      ignoring: !active,
                      child: ExcludeSemantics(
                        excluding: !active,
                        child: Transform.translate(
                          offset: Offset(isBase || pane ? 0 : pose.x, 0),
                          child: Opacity(
                            opacity: isBase ? 1 : pose.opacity,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}
