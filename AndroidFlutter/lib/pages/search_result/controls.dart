import 'package:PiliPlus/common/widgets/newbili_glass.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/common/search/video_search_type.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

class SearchResultControls extends StatelessWidget {
  const SearchResultControls({
    super.key,
    required this.scope,
    required this.counts,
    required this.order,
    required this.onScope,
    required this.onOrder,
    required this.onFilter,
  });
  final SearchType scope;
  final List<int> counts;
  final ArchiveFilterType order;
  final ValueChanged<SearchType> onScope;
  final ValueChanged<ArchiveFilterType> onOrder;
  final VoidCallback onFilter;

  Widget _label(String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(CupertinoIcons.chevron_down, size: 13),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => NewbiliGlassSurface(
    role: NewbiliGlassRole.navigation,
    borderRadius: BorderRadius.circular(32),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: PopupMenuButton<SearchType>(
              tooltip: '搜索类型',
              initialValue: scope,
              onSelected: onScope,
              itemBuilder: (_) => [
                for (final type in SearchType.values)
                  PopupMenuItem(
                    value: type,
                    child: Text(
                      '${type.label}${counts[type.index] < 0 ? '' : ' · ${counts[type.index]}'}',
                    ),
                  ),
              ],
              child: _label(scope.label),
            ),
          ),
          if (scope == SearchType.video) ...[
            const SizedBox(height: 24, child: VerticalDivider(width: 1)),
            Expanded(
              child: PopupMenuButton<ArchiveFilterType>(
                tooltip: '搜索排序',
                initialValue: order,
                onSelected: onOrder,
                itemBuilder: (_) => [
                  for (final type in ArchiveFilterType.values)
                    PopupMenuItem(value: type, child: Text(type.desc)),
                ],
                child: _label(order.desc),
              ),
            ),
            SizedBox.square(
              dimension: 48,
              child: IconButton(
                tooltip: '时长、分区和发布时间筛选',
                icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 21),
                onPressed: onFilter,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
