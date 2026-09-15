import 'package:PiliPlus/common/widgets/selection_text.dart';
import 'package:material_ui/material_ui.dart';

class HttpError extends StatelessWidget {
  const HttpError({
    super.key,
    this.isSliver = true,
    this.errMsg,
    this.onReload,
    this.btnText,
    this.safeArea = true,
  });

  final bool isSliver;
  final String? errMsg;
  final VoidCallback? onReload;
  final String? btnText;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Column(
      mainAxisSize: .min,
      mainAxisAlignment: .center,
      crossAxisAlignment: .center,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            errMsg == null ? Icons.inbox_outlined : Icons.cloud_off_outlined,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const .symmetric(horizontal: 16, vertical: 8),
          child: SelectionText(
            errMsg ?? '没有数据',
            textAlign: .center,
            style: theme.textTheme.titleSmall,
          ),
        ),
        if (onReload != null)
          FilledButton.tonal(
            onPressed: onReload,
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 48),
              tapTargetSize: .padded,
            ),
            child: Text(
              btnText ?? '点击重试',
            ),
          ),
        if (safeArea)
          SizedBox(height: 24 + MediaQuery.viewPaddingOf(context).bottom),
      ],
    );

    return isSliver
        ? SliverToBoxAdapter(child: child)
        : SizedBox(width: double.infinity, child: child);
  }
}
