import 'package:PiliPlus/models/update_notifications.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

class TrackedPartsSheet extends StatefulWidget {
  const TrackedPartsSheet({super.key, required this.item});
  final TrackedSeries item;
  @override
  State<TrackedPartsSheet> createState() => _TrackedPartsSheetState();
}

class _TrackedPartsSheetState extends State<TrackedPartsSheet> {
  final _search = TextEditingController();
  bool _reverse = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final pages = widget.item.pages
        .where(
          (page) => query.isEmpty || page.label.toLowerCase().contains(query),
        )
        .toList(growable: false);
    final ordered = _reverse ? pages.reversed.toList(growable: false) : pages;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .9,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxHeight <
                  180 + MediaQuery.textScalerOf(context).scale(14) * 18;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '选集',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '关闭选集',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(CupertinoIcons.xmark),
                            ),
                          ],
                        ),
                        if (!compact) ...[
                          Text(
                            widget.item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _search,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: '搜索分 P',
                                  hintText: '集数或标题',
                                  border: const OutlineInputBorder(),
                                  floatingLabelStyle: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: scheme.onSurface,
                                      width: 2,
                                    ),
                                  ),
                                  suffixIcon: query.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: '清除分 P 搜索',
                                          onPressed: () =>
                                              setState(_search.clear),
                                          icon: const Icon(
                                            CupertinoIcons.xmark_circle_fill,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: _reverse ? '倒序 · 切换正序' : '正序 · 切换倒序',
                              isSelected: _reverse,
                              onPressed: () =>
                                  setState(() => _reverse = !_reverse),
                              icon: const Icon(CupertinoIcons.sort_down),
                              selectedIcon: const Icon(CupertinoIcons.sort_up),
                            ),
                          ],
                        ),
                        if (!compact)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${pages.length} / ${widget.item.pageCount} 个分 P',
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: ordered.isEmpty ? 1 : ordered.length,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemBuilder: (context, index) {
                        if (ordered.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('没有匹配的分 P，请更换关键词或清除搜索。'),
                          );
                        }
                        final page = ordered[index];
                        return ListTile(
                          key: ValueKey(page.cid),
                          minTileHeight: 56,
                          title: Text(page.label),
                          trailing: const Icon(CupertinoIcons.play_circle),
                          onTap: () => Navigator.pop(context, page),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
