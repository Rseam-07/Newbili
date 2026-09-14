import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/newbili_library.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/pages/fav/video/controller.dart';
import 'package:PiliPlus/pages/fav/video/widgets/item.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class FavVideoPage extends StatefulWidget {
  const FavVideoPage({super.key});

  @override
  State<FavVideoPage> createState() => _FavVideoPageState();
}

class _FavVideoPageState extends State<FavVideoPage>
    with AutomaticKeepAliveClientMixin {
  final FavController _favController = Get.find<FavController>();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return refreshIndicator(
      onRefresh: _favController.onRefresh,
      child: CustomScrollView(
        controller: _favController.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: 7,
              bottom: 100 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            sliver: Obx(
              () => _buildBody(_favController.loadingState.value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(LoadingState<List<FavFolderInfo>?> loadingState) {
    return switch (loadingState) {
      Loading() => const NewbiliLibrarySkeleton(),
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverList.builder(
                itemBuilder: (BuildContext context, int index) {
                  if (index == response.length - 1) {
                    _favController.onLoadMore();
                  }
                  final item = response[index];
                  String heroTag = Utils.makeHeroTag(item.fid);
                  return FavVideoItem(
                    key: ValueKey(item.id),
                    heroTag: heroTag,
                    item: item,
                    onTap: () async {
                      final res = await Get.toNamed(
                        '/favDetail',
                        arguments: item,
                        parameters: {
                          'heroTag': heroTag,
                          'mediaId': item.id.toString(),
                        },
                      );
                      final folders = _favController.loadingState.value.data;
                      if (res == true && folders != null) {
                        folders.removeWhere((folder) => folder.id == item.id);
                        _favController.loadingState.refresh();
                      }
                    },
                  );
                },
                itemCount: response.length,
              )
            : HttpError(onReload: _favController.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _favController.onReload,
      ),
    };
  }
}
