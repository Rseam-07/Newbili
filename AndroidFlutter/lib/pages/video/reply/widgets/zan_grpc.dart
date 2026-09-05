import 'package:PiliPlus/common/theme/newbili_theme.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:PiliPlus/http/reply.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

({int action, int likeDelta}) replyReactionTransition(
  int previous, {
  required bool dislike,
}) {
  final target = dislike ? 2 : 1;
  final action = previous == target ? 0 : target;
  return (
    action: action,
    likeDelta: (action == 1 ? 1 : 0) - (previous == 1 ? 1 : 0),
  );
}

class ZanButtonGrpc extends StatefulWidget {
  const ZanButtonGrpc({super.key, required this.replyItem});
  final ReplyInfo replyItem;

  @override
  State<ZanButtonGrpc> createState() => _ZanButtonGrpcState();
}

class _ZanButtonGrpcState extends State<ZanButtonGrpc> {
  // null = idle; false = like in flight; true = dislike in flight.
  bool? _pendingDislike;

  Future<void> _react({required bool dislike}) async {
    if (_pendingDislike != null) return;
    final item = widget.replyItem;
    final transition = replyReactionTransition(
      item.replyControl.action.toInt(),
      dislike: dislike,
    );
    setState(() => _pendingDislike = dislike);
    try {
      feedBack();
      final result = dislike
          ? await ReplyHttp.hateReply(
              type: item.type.toInt(),
              oid: item.oid.toInt(),
              rpid: item.id.toInt(),
              action: transition.action == 2 ? 1 : 0,
            )
          : await ReplyHttp.likeReply(
              type: item.type.toInt(),
              oid: item.oid.toInt(),
              rpid: item.id.toInt(),
              action: transition.action,
            );
      if (result.isSuccess) {
        // Keep the captured reply, not a potentially recycled row's new item.
        item.like += fixnum.Int64(transition.likeDelta);
        item.replyControl.action = fixnum.Int64(transition.action);
        if (mounted) {
          SmartDialog.showToast(
            transition.action == 0
                ? '已取消'
                : dislike
                ? '点踩成功'
                : '点赞成功',
          );
        }
      } else if (mounted) {
        result.toast();
      }
    } catch (_) {
      if (mounted) SmartDialog.showToast('操作未完成，请稍后重试');
    } finally {
      if (mounted) setState(() => _pendingDislike = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = widget.replyItem.replyControl.action.toInt();
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : NewbiliMotion.feedback;
    Widget button({required bool dislike}) {
      final selected = action == (dislike ? 2 : 1);
      final pending = _pendingDislike == dislike;
      final label = dislike
          ? (selected ? '取消点踩' : '点踩')
          : (selected ? '取消点赞' : '点赞');
      return Semantics(
        label: label,
        selected: selected,
        child: TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            tapTargetSize: MaterialTapTargetSize.padded,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            foregroundColor: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: _pendingDislike == null
              ? () => _react(dislike: dislike)
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              AnimatedSwitcher(
                duration: duration,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: pending
                    ? const SizedBox.square(
                        key: ValueKey('pending'),
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        dislike
                            ? (selected
                                  ? Icons.thumb_down
                                  : Icons.thumb_down_outlined)
                            : (selected
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_outlined),
                        key: ValueKey((dislike, selected)),
                        size: 18,
                      ),
              ),
              if (!dislike)
                Text(
                  NumUtils.numFormat(widget.replyItem.like.toInt()),
                  style: theme.textTheme.labelMedium,
                ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        button(dislike: true),
        button(dislike: false),
      ],
    );
  }
}
