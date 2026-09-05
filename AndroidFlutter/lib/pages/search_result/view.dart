import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/common/widgets/newbili_glass.dart';
import 'package:PiliPlus/models/common/search/video_search_type.dart';
import 'package:PiliPlus/pages/search_panel/video/controller.dart';
import 'package:PiliPlus/pages/search_result/controls.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/pages/search/controller.dart';
import 'package:PiliPlus/pages/search_panel/article/view.dart';
import 'package:PiliPlus/pages/search_panel/live/view.dart';
import 'package:PiliPlus/pages/search_panel/pgc/view.dart';
import 'package:PiliPlus/pages/search_panel/user/view.dart';
import 'package:PiliPlus/pages/search_panel/video/view.dart';
import 'package:PiliPlus/pages/search_result/controller.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({super.key});

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage>
    with SingleTickerProviderStateMixin {
  late SearchResultController _searchResultController;
  late TabController _tabController;
  final String _tag = DateTime.now().millisecondsSinceEpoch.toString();
  final bool _isFromSearch = Get.arguments?['fromSearch'] ?? false;
  SSearchController? sSearchController;

  @override
  void initState() {
    super.initState();
    _searchResultController = Get.put(
      SearchResultController(),
      tag: _tag,
    );

    _tabController = TabController(
      vsync: this,
      initialIndex: Get.arguments?['initIndex'] ?? 0,
      length: SearchType.values.length,
    );

    if (_isFromSearch) {
      try {
        sSearchController = Get.find<SSearchController>(
          tag: Get.parameters['tag'],
        );
        _tabController.addListener(listener);
      } catch (_) {}
    }
  }

  void listener() {
    sSearchController?.initIndex = _tabController.index;
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(listener)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchHeight = (MediaQuery.textScalerOf(context).scale(16) + 16)
        .clamp(48.0, double.infinity);
    return SimpleScaffold(
      backgroundColor: NewbiliFormStyle.background(context),
      appBar: AppBar(
        toolbarHeight: searchHeight + 8,
        shape: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        title: GestureDetector(
          onTap: () {
            if (_isFromSearch) {
              Get.back();
            } else {
              Get.offNamed(
                '/search',
                parameters: {'text': _searchResultController.keyword},
              );
            }
          },
          behavior: HitTestBehavior.opaque,
          child: NewbiliGlassSurface(
            role: NewbiliGlassRole.toolbar,
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: double.infinity,
              height: searchHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.search, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _searchResultController.keyword,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: ViewSafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: tabBarView(
                controller: _tabController,
                children: SearchType.values
                    .map(
                      (item) => switch (item) {
                        // SearchType.all => SearchAllPanel(
                        //   tag: _tag,
                        //   searchType: item,
                        //   keyword: _searchResultController.keyword,
                        // ),
                        SearchType.video => SearchVideoPanel(
                          tag: _tag,
                          searchType: item,
                          keyword: _searchResultController.keyword,
                        ),
                        SearchType.media_bangumi ||
                        SearchType.media_ft => SearchPgcPanel(
                          tag: _tag,
                          searchType: item,
                          keyword: _searchResultController.keyword,
                        ),
                        SearchType.live_room => SearchLivePanel(
                          tag: _tag,
                          searchType: item,
                          keyword: _searchResultController.keyword,
                        ),
                        SearchType.bili_user => SearchUserPanel(
                          tag: _tag,
                          searchType: item,
                          keyword: _searchResultController.keyword,
                        ),
                        SearchType.article => SearchArticlePanel(
                          tag: _tag,
                          searchType: item,
                          keyword: _searchResultController.keyword,
                        ),
                      },
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.viewPaddingOf(context).bottom + 12,
              ),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) => Obx(() {
                  final counts = _searchResultController.count.toList();
                  final tag = SearchType.video.name + _tag;
                  final controller =
                      Get.isRegistered<SearchVideoController>(tag: tag)
                      ? Get.find<SearchVideoController>(tag: tag)
                      : null;
                  return SearchResultControls(
                    scope: SearchType.values[_tabController.index],
                    counts: counts,
                    order:
                        controller?.selectedType.value ??
                        ArchiveFilterType.totalrank,
                    onScope: (scope) {
                      if (_tabController.index == scope.index) {
                        _searchResultController.toTopIndex.value = scope.index;
                        _searchResultController.toTopIndex.refresh();
                      } else {
                        _tabController.animateTo(scope.index);
                      }
                    },
                    onOrder: (order) {
                      final video = Get.find<SearchVideoController>(tag: tag);
                      if (video.selectedType.value != order) {
                        video
                          ..order = order.name
                          ..selectedType.value = order
                          ..onSortSearch(getBack: false);
                      }
                    },
                    onFilter: () =>
                        Get.find<SearchVideoController>(tag: tag)
                            .onShowFilterDialog(context),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
