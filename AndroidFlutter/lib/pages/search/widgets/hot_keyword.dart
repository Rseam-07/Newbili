import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/models_new/search/search_trending/list.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

/// iOS's two-column search suggestions; slivers keep layout and semantics native.
class SliverHotKeyword extends StatelessWidget {
  const SliverHotKeyword({
    super.key,
    required this.hotSearchList,
    this.onClick,
  });
  final List<SearchTrendingItemModel> hotSearchList;
  final ValueChanged<String>? onClick;

  @override
  Widget build(BuildContext context) => SliverGrid.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      mainAxisExtent: (MediaQuery.textScalerOf(context).scale(16) + 26).clamp(
        48.0,
        double.infinity,
      ),
    ),
    itemCount: hotSearchList.length,
    itemBuilder: (context, index) {
      final item = hotSearchList[index];
      final keyword = item.keyword ?? '';
      return Material(
        color: NewbiliFormStyle.card(context),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onClick == null || keyword.isEmpty
              ? null
              : () => onClick!(keyword),
          child: Tooltip(
            message: [keyword, item.recommendReason].nonNulls.join(' · '),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                spacing: 4,
                children: [
                  Expanded(
                    child: Text(
                      keyword,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (item.showLiveIcon == true)
                    Icon(
                      Icons.graphic_eq,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                      semanticLabel: '直播',
                    ),
                  if (item.icon?.isNotEmpty == true)
                    CachedNetworkImage(
                      imageUrl: ImageUtils.thumbnailUrl(item.icon!),
                      height: 15,
                      width: 24,
                      fit: BoxFit.contain,
                      memCacheHeight:
                          (MediaQuery.devicePixelRatioOf(context) * 15).round(),
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
