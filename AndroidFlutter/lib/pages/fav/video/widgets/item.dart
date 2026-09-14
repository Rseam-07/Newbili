import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/newbili_library.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/utils/bili_utils.dart';
import 'package:material_ui/material_ui.dart';

class FavVideoItem extends StatelessWidget {
  const FavVideoItem({
    super.key,
    this.onTap,
    this.onLongPress,
    required this.heroTag,
    required this.item,
  });

  final String heroTag;
  final FavFolderInfo item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => NewbiliLibraryTile(
    title: item.title,
    cover: item.cover,
    heroTag: heroTag,
    subtitle: item.intro,
    metadata: '${item.mediaCount}个内容 · ${BiliUtils.isPublicFavText(item.attr)}',
    onTap: onTap,
    onLongPress:
        onLongPress ??
        (onTap == null
            ? null
            : () => imageSaveDialog(title: item.title, cover: item.cover)),
  );
}
