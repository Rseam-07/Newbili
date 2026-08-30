import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
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

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);
    return Container(
      clipBehavior: .hardEdge,
      margin: const .symmetric(horizontal: Style.safeSpace),
      decoration: const BoxDecoration(borderRadius: Style.mdRadius),
      child: refreshIndicator(
        onRefresh: controller.onRefresh,
        child: CustomScrollView(
          controller: controller.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const .only(top: Style.cardSpace, bottom: 100),
              sliver: Obx(
                () => _buildBody(colorScheme, controller.loadingState.value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  late final gridDelegate = SliverGridDelegateWithExtentAndRatio(
    mainAxisSpacing: Style.cardSpace,
    crossAxisSpacing: Style.cardSpace,
    maxCrossAxisExtent: Pref.recommendCardWidth,
    childAspectRatio: Style.aspectRatio,
    mainAxisExtent: MediaQuery.textScalerOf(context).scale(90),
  );

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
            padding: const EdgeInsets.only(bottom: Style.cardSpace),
            child: FeaturedRecommendationCarousel(
              items: response.take(featuredCount).toList(growable: false),
            ),
          ),
        ),
        SliverGrid.builder(
          gridDelegate: gridDelegate,
          itemBuilder: (context, index) {
            if (index == itemCount - 1) {
              controller.onLoadMore();
            }
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
              final actualIndex =
                  featuredCount + (index > markerIndex ? index - 1 : index);
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
            } else {
              return VideoCardV(
                videoItem: response[index + featuredCount],
                onRemove: () => controller.loadingState
                  ..value.data!.removeAt(index + featuredCount)
                  ..refresh(),
              );
            }
          },
          itemCount: itemCount,
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
