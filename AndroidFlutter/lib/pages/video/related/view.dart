import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/pages/video/related/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class RelatedVideoPanel extends StatefulWidget {
  const RelatedVideoPanel({
    super.key,
    required this.heroTag,
    this.horizontal = false,
  });
  final String heroTag;
  final bool horizontal;
  @override
  State<RelatedVideoPanel> createState() => _RelatedVideoPanelState();
}

class _RelatedVideoPanelState extends State<RelatedVideoPanel> with GridMixin {
  late final RelatedController _relatedController;

  @override
  void initState() {
    super.initState();
    _relatedController = Get.putOrFind(
      RelatedController.new,
      tag: widget.heroTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.horizontal) {
      return Obx(() {
        final state = _relatedController.loadingState.value;
        if (state is Loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is Error) {
          return Center(
            child: TextButton.icon(
              onPressed: _relatedController.onReload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载相关推荐'),
            ),
          );
        }
        final items = state.data ?? <HotVideoItemModel>[];
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 16),
          itemBuilder: (context, index) => SizedBox(
            width: 212,
            child: VideoCardV(
              videoItem: _RelatedCard(items[index]),
              onOpen: (tag) =>
                  VideoCardH(videoItem: items[index])
                      .openVideo(context, coverHeroTag: tag),
              onRemove: () => _relatedController.loadingState
                ..value.data!.removeAt(index)
                ..refresh(),
            ),
          ),
        );
      });
    }
    return SliverPadding(
      padding: const EdgeInsets.only(top: 7, bottom: 100),
      sliver: Obx(() => _buildBody(_relatedController.loadingState.value)),
    );
  }

  Widget _buildBody(LoadingState<List<HotVideoItemModel>?> loadingState) {
    return switch (loadingState) {
      Loading() => gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  return VideoCardH(
                    videoItem: response[index],
                    onRemove: () => _relatedController.loadingState
                      ..value.data!.removeAt(index)
                      ..refresh(),
                  );
                },
                itemCount: response.length,
              )
            : const SliverToBoxAdapter(),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _relatedController.onReload,
      ),
    };
  }
}

class _RelatedCard extends BaseRcmdVideoItemModel {
  _RelatedCard(HotVideoItemModel item) {
    aid = item.aid;
    bvid = item.bvid;
    cid = item.cid;
    goto = 'av';
    cover = item.cover;
    title = item.title;
    duration = item.duration;
    owner = item.owner;
    stat = item.stat;
    pubdate = item.pubdate;
  }
}
