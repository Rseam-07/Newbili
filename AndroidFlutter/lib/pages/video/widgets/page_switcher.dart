import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Secondary tabs attach to the player; actions never cover the page content.
class PlayerPageSwitcher extends StatelessWidget {
  const PlayerPageSwitcher({
    super.key,
    required this.controller,
    required this.labels,
    required this.onSendDanmaku,
    required this.onToggleDanmaku,
    required this.showsDanmaku,
    required this.onReselect,
  });

  final TabController controller;
  final List<String> labels;
  final VoidCallback onSendDanmaku;
  final VoidCallback onToggleDanmaku;
  final bool showsDanmaku;
  final VoidCallback onReselect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: onSendDanmaku,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('发弹幕'),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
        ),
        IconButton(
          tooltip: showsDanmaku ? '隐藏弹幕' : '显示弹幕',
          isSelected: showsDanmaku,
          onPressed: onToggleDanmaku,
          icon: const Icon(Icons.subtitles_off_outlined),
          selectedIcon: const Icon(Icons.subtitles_rounded),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
      ],
    );
    return Material(
      color: scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final selectedIndex = controller.index;
              final tabs = TabBar.secondary(
                controller: controller,
                isScrollable: largeText || labels.length > 2,
                tabAlignment: largeText || labels.length > 2
                    ? TabAlignment.start
                    : TabAlignment.fill,
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                labelColor: scheme.primary,
                unselectedLabelColor: scheme.onSurfaceVariant,
                dividerHeight: 0,
                tabs: [
                  for (final label in labels)
                    Tab(
                      height: (MediaQuery.textScalerOf(context).scale(14) + 24)
                          .clamp(48.0, double.infinity),
                      text: label == '简介' ? '详情' : label,
                    ),
                ],
                onTap: (index) {
                  if (index == selectedIndex) {
                    onReselect();
                  } else if (NewbiliMotion.reduced(context)) {
                    controller.animateTo(index, duration: Duration.zero);
                  }
                },
              );
              if (largeText || labels.length > 2) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    tabs,
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: tabs),
                  actions,
                ],
              );
            },
          ),
          Divider(height: 1, color: scheme.outlineVariant),
        ],
      ),
    );
  }
}
