import 'package:PiliPlus/common/widgets/floating_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/newbili_glass.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

/// Shares the root navigation's capsule, motion and accessible touch targets.
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

  static double contentInsetOf(BuildContext context) =>
      FloatingNavigationBar.heightOf(context) + 24;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 352),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: NewbiliGlassSurface(
            role: NewbiliGlassRole.navigation,
            borderRadius: BorderRadius.circular(36),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => FloatingNavigationBar(
                destinations: [
                  for (final (index, label) in labels.indexed)
                    NavigationDestination(
                      label: label == '简介' ? '详情' : label,
                      icon: Icon(
                        index == 0
                            ? CupertinoIcons.text_alignleft
                            : label == '评论'
                            ? CupertinoIcons.chat_bubble_2_fill
                            : CupertinoIcons.list_bullet,
                      ),
                    ),
                ],
                selectedIndex: controller.index,
                onDestinationSelected: (index) {
                  if (index == controller.index) {
                    onReselect();
                  } else {
                    controller.animateTo(
                      index,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : null,
                    );
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        NewbiliGlassSurface(
          role: NewbiliGlassRole.toolbar,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox.square(
            dimension: 48,
            child: PopupMenuButton<int>(
              tooltip: '弹幕操作',
              icon: const Icon(CupertinoIcons.ellipsis, size: 22),
              onSelected: (action) =>
                  action == 0 ? onSendDanmaku() : onToggleDanmaku(),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 0, child: Text('发弹幕')),
                PopupMenuItem(
                  value: 1,
                  child: Text(showsDanmaku ? '隐藏弹幕' : '显示弹幕'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
