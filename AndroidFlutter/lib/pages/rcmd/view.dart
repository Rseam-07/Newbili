import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/floating_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/pages/rcmd/featured_recommendation.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class RcmdPage extends StatefulWidget {
  const RcmdPage({super.key});

  @override
  State<RcmdPage> createState() => _RcmdPageState();
}

class _RcmdPageState extends State<RcmdPage>
    with AutomaticKeepAliveClientMixin {
  final RcmdController controller = Get.put(RcmdController());
  final _featuredVisible = ValueNotifier(true);

  @override
  void dispose() {
    _featuredVisible.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);
    return Container(
      clipBehavior: .hardEdge,
      margin: const .symmetric(horizontal: 16),
      decoration: const BoxDecoration(borderRadius: Style.mdRadius),
      child: refreshIndicator(
        onRefresh: controller.onRefresh,
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (notification) {
            if (notification.depth == 0) {
              _featuredVisible.value =
                  notification.metrics.pixels <
                  FeaturedRecommendationCarousel.height(context);
              if (notification.metrics.extentAfter < 500) {
                controller.onLoadMore();
              }
            }
            return false;
          },
          child: CustomScrollView(
            controller: controller.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: .only(
                  top: 28,
                  bottom: FloatingNavigationBar.bottomContentInsetOf(context),
                ),
                sliver: Obx(
                  () => _buildBody(colorScheme, controller.loadingState.value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  late SliverGridDelegateWithExtentAndRatio gridDelegate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    gridDelegate = SliverGridDelegateWithExtentAndRatio(
      mainAxisSpacing: Style.cardSpace,
      crossAxisSpacing: Style.cardSpace,
      maxCrossAxisExtent: Pref.recommendCardWidth,
      childAspectRatio: Style.aspectRatio,
      mainAxisExtent: MediaQuery.textScalerOf(context).scale(90),
    );
  }

  Widget _buildBody(
    ColorScheme colorScheme,
    LoadingState<List<dynamic>?> loadingState,
  ) {
    return switch (loadingState) {
      Loading() => _buildSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? _buildRecommendations(response.cast<BaseRcmdVideoItemModel>())
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  Widget _buildRecommendations(List<BaseRcmdVideoItemModel> response) {
    final featuredCount = response.length.clamp(1, 5);
    final gridCount = response.length - featuredCount;
    final markerIndex = controller.lastRefreshAt == null
        ? null
        : (controller.lastRefreshAt! - featuredCount).clamp(0, gridCount);
    final itemCount = gridCount + (markerIndex == null ? 0 : 1);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ValueListenableBuilder(
              valueListenable: _featuredVisible,
              builder: (context, visible, _) => FeaturedRecommendationCarousel(
                isVisible: visible,
                items: response.take(featuredCount).toList(growable: false),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      const Text(
                        '继续发现',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '根据你的内容偏好持续更新',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        SliverGrid.builder(
          gridDelegate: gridDelegate,
          itemBuilder: (context, index) {
            if (markerIndex != null) {
              if (markerIndex == index) {
                return GestureDetector(
                  onTap: () => controller
                    ..animateToTop()
                    ..onRefresh(),
                  child: Card(
                    child: Container(
                      alignment: Alignment.center,
                      padding: const .symmetric(horizontal: 10),
                      child: Text(
                        '上次看到这里\n点击刷新',
                        textAlign: .center,
                        style: TextStyle(
                          color: ColorScheme.of(context).onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }
            }
            final actualIndex =
                featuredCount +
                index -
                (markerIndex != null && index > markerIndex ? 1 : 0);
            return VideoCardV(
              videoItem: response[actualIndex],
              onRemove: () {
                if (controller.lastRefreshAt != null &&
                    actualIndex < controller.lastRefreshAt!) {
                  controller.lastRefreshAt = controller.lastRefreshAt! - 1;
                }
                controller.loadingState
                  ..value.data!.removeAt(actualIndex)
                  ..refresh();
              },
            );
          },
          itemCount: itemCount,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: TextButton.icon(
              onPressed: controller.onLoadMore,
              style: Style.buttonStyle,
              icon: const Icon(Icons.expand_more),
              label: const Text('加载更多'),
            ),
          ),
        ),
      ],
    );
  }

  Widget get _buildSkeleton => SliverGrid(
    gridDelegate: gridDelegate,
    delegate: const SliverSingleChildDelegate(
      count: 10,
      child: VideoCardVSkeleton(),
    ),
  );
}
