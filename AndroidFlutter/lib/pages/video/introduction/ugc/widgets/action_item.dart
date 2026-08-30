import 'package:PiliPlus/common/widgets/custom_arc.dart';
import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

class ActionItem extends StatefulWidget {
  const ActionItem({
    super.key,
    required this.icon,
    this.selectIcon,
    this.onTap,
    this.onLongPress,
    this.text,
    this.selectStatus = false,
    required this.semanticsLabel,
    this.expand = true,
    this.animation,
    this.onStartTriple,
    this.onCancelTriple,
  }) : assert(!selectStatus || selectIcon != null),
       _isThumbsUp = onStartTriple != null;

  final Icon icon;
  final Icon? selectIcon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? text;
  final bool selectStatus;
  final String semanticsLabel;
  final bool expand;
  final Animation<double>? animation;
  final VoidCallback? onStartTriple;
  final void Function([bool])? onCancelTriple;
  final bool _isThumbsUp;

  @override
  State<ActionItem> createState() => _ActionItemState();
}

class _ActionItemState extends State<ActionItem> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    late final primary = !widget.expand && colorScheme.isLight
        ? colorScheme.inversePrimary
        : colorScheme.primary;
    Widget child = AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : NewbiliMotion.feedback,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: .72, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Icon(
        widget.selectStatus ? widget.selectIcon!.icon! : widget.icon.icon,
        key: ValueKey(widget.selectStatus),
        size: 20,
        color: widget.selectStatus
            ? primary
            : widget.icon.color ?? colorScheme.outline,
      ),
    );

    if (widget.animation != null) {
      child = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: widget.animation!,
            builder: (context, child) => Arc(
              size: 34,
              color: primary,
              progress: -widget.animation!.value,
            ),
          ),
          child,
        ],
      );
    } else {
      child = SizedBox.square(dimension: 34, child: child);
    }

    child = Semantics(
      button: true,
      label: widget.semanticsLabel,
      toggled: widget.selectIcon == null ? null : widget.selectStatus,
      child: AnimatedScale(
        scale: reduceMotion || !_isPressed ? 1 : .9,
        duration: reduceMotion ? Duration.zero : NewbiliMotion.feedback,
        curve: Curves.easeOutCubic,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: NewbiliMetrics.minTouchTarget,
            minHeight: NewbiliMetrics.minTouchTarget,
          ),
          child: Material(
            type: .transparency,
            child: InkWell(
              borderRadius: const .all(.circular(14)),
              onTap: widget._isThumbsUp ? null : widget.onTap,
              onLongPress: widget._isThumbsUp ? null : widget.onLongPress,
              onSecondaryTap: PlatformUtils.isMobile || widget._isThumbsUp
                  ? null
                  : widget.onLongPress,
              onTapDown: (details) {
                _setPressed(true);
                if (widget._isThumbsUp) widget.onStartTriple!();
              },
              onTapUp: (details) {
                _setPressed(false);
                if (widget._isThumbsUp) widget.onCancelTriple!(true);
              },
              onTapCancel: () {
                _setPressed(false);
                if (widget._isThumbsUp) widget.onCancelTriple!();
              },
              child: widget.expand
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [child, _buildText(theme)],
                    )
                  : Center(child: child),
            ),
          ),
        ),
      ),
    );
    return widget.expand ? Expanded(child: child) : child;
  }

  Widget _buildText(ThemeData theme) {
    final hasText = widget.text != null;
    final child = Text(
      hasText ? widget.text! : '-',
      key: hasText ? ValueKey(widget.text!) : null,
      style: TextStyle(
        color: widget.selectStatus
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
        fontSize: theme.textTheme.labelSmall!.fontSize,
      ),
    );
    if (hasText) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: child,
      );
    }
    return child;
  }
}
