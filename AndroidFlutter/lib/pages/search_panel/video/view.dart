import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search_panel/video/controller.dart';
import 'package:PiliPlus/pages/search_panel/view.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class SearchVideoPanel extends CommonSearchPanel {
  const SearchVideoPanel({
    super.key,
    required super.keyword,
    required super.tag,
    required super.searchType,
  });

  @override
  State<SearchVideoPanel> createState() => _SearchVideoPanelState();
}

class _SearchVideoPanelState
    extends
        CommonSearchPanelState<
          SearchVideoPanel,
          SearchVideoData,
          SearchVideoItemModel
        > {
  @override
  late final SearchVideoController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      SearchVideoController(
        keyword: widget.keyword,
        searchType: widget.searchType,
        tag: widget.tag,
      ),
      tag: widget.searchType.name + widget.tag,
    );
    controller.scrollController.addListener(_loadNearEnd);
  }

  void _loadNearEnd() {
    if (controller.scrollController.hasClients &&
        controller.scrollController.position.extentAfter < 600) {
      controller.onLoadMore();
    }
  }

  @override
  void dispose() {
    controller.scrollController.removeListener(_loadNearEnd);
    super.dispose();
  }

  @override
  Widget buildHeader(ThemeData theme) {
    return const SliverToBoxAdapter(child: SizedBox(height: 12));
  }

  @override
  Widget buildList(ThemeData theme, List<SearchVideoItemModel> list) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: list.length + 1,
        itemBuilder: (context, index) {
          if (index == list.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: TextButton(
                onPressed: controller.isEnd ? null : controller.onLoadMore,
                child: Text(controller.isEnd ? '已经到底了' : '加载更多'),
              ),
            );
          }
          final item = list[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: VideoCardH(
              key: ValueKey(item.bvid),
              videoItem: item,
              compact: true,
              onRemove: () => controller.loadingState
                ..value.data!.remove(item)
                ..refresh(),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget get buildLoading => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    sliver: SliverList.builder(
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        height: VideoCardH.compactHeightOf(context),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: NewbiliFormStyle.card(context),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    ),
  );
}
