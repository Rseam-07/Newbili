import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

/// Shared geometry from iOS MineContentView / SettingsNavigationRow.
abstract final class NewbiliFormStyle {
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF000000)
      : const Color(0xFFF2F2F7);
  static Color card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1C1C1E)
      : Colors.white;
}

class NewbiliPageTitle extends StatelessWidget {
  const NewbiliPageTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  static double heightOf(BuildContext context) =>
      28 +
      (MediaQuery.textScalerOf(context).scale(34) * 1.2).ceilToDouble().clamp(
        48.0,
        double.infinity,
      );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 34,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class NewbiliFormSection extends StatelessWidget {
  const NewbiliFormSection({
    super.key,
    this.title,
    required this.children,
    this.dividers = true,
  });
  final String? title;
  final List<Widget> children;
  final bool dividers;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Material(
          color: NewbiliFormStyle.card(context),
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (dividers && index > 0)
                  Divider(
                    height: .5,
                    thickness: .5,
                    indent: 56,
                    endIndent: 16,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                child,
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class NewbiliSettingsRow extends StatelessWidget {
  const NewbiliSettingsRow({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.value,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: subtitle == null ? 56 : 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            spacing: 13,
            children: [
              Icon(icon, size: 22, color: scheme.primary),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: subtitle == null ? 17 : 15,
                        fontWeight: subtitle == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (value != null)
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 15,
                  color: scheme.outline.withValues(alpha: .65),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
