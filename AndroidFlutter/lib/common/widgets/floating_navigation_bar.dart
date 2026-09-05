import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:material_ui/material_ui.dart';

/// iOS's whole-destination capsule, with Android focus and touch semantics.
class FloatingNavigationBar extends StatelessWidget {
  const FloatingNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static double heightOf(BuildContext context) =>
      66.0 + (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0.0, 24.0);

  static double bottomContentInsetOf(BuildContext context) =>
      heightOf(context) + 24 + MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : NewbiliMotion.container;
    final height = heightOf(context) - 8;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final (index, destination) in destinations.indexed)
            Expanded(
              child: Semantics(
                selected: selectedIndex == index,
                button: true,
                label: destination.label,
                child: Tooltip(
                  message: destination.label,
                  child: AnimatedContainer(
                    duration: duration,
                    height: height,
                    decoration: BoxDecoration(
                      color: selectedIndex == index
                          ? scheme.onSurface.withValues(alpha: .065)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => onDestinationSelected(index),
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            spacing: 2,
                            children: [
                              IconTheme(
                                data: IconThemeData(
                                  size: 28,
                                  color: selectedIndex == index
                                      ? scheme.primary
                                      : scheme.onSurface,
                                ),
                                child: selectedIndex == index
                                    ? destination.selectedIcon ??
                                          destination.icon
                                    : destination.icon,
                              ),
                              Text(
                                destination.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.1,
                                  fontWeight: FontWeight.w600,
                                  color: selectedIndex == index
                                      ? scheme.primary
                                      : scheme.onSurface,
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
  }
}
