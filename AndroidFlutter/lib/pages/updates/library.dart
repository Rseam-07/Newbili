import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/common/widgets/newbili_library.dart';
import 'package:PiliPlus/models/update_notifications.dart';
import 'package:PiliPlus/pages/updates/parts.dart';
import 'package:PiliPlus/pages/updates/view.dart';
import 'package:PiliPlus/services/update_notification_service.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class TrackedSeriesPage extends StatelessWidget {
  const TrackedSeriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = UpdateNotificationService.instance;
    return Scaffold(
      backgroundColor: NewbiliFormStyle.background(context),
      appBar: AppBar(
        title: const Text('我的追更'),
        actions: [
          IconButton(
            tooltip: '通知设置',
            icon: const Icon(CupertinoIcons.bell),
            onPressed: () => Get.to(() => const UpdateNotificationPage()),
          ),
        ],
      ),
      body: Obx(
        () => TrackedSeriesContent(
          state: service.state.value,
          loaded: service.loaded.value,
          busy: service.busy.value,
          error: service.error.value,
          pending: service.pending.toSet(),
          onRefresh: () => service.refresh(manual: true),
          onRemove: service.remove,
          onRestore: service.restore,
          onOpen: (item, page) {
            if (page == null) {
              PiliScheme.videoPush(null, item.bvid);
            } else {
              // Use the selected content ID, never its mutable position in a list.
              PageUtils.toVideoPage(
                bvid: item.bvid,
                cid: page.cid,
                title: item.title,
                cover: item.cover,
              );
            }
          },
        ),
      ),
    );
  }
}

class TrackedSeriesContent extends StatefulWidget {
  const TrackedSeriesContent({
    super.key,
    required this.state,
    this.loaded = true,
    required this.busy,
    this.error,
    this.pending = const {},
    required this.onRefresh,
    required this.onRemove,
    required this.onRestore,
    required this.onOpen,
  });
  final UpdateNotificationState state;
  final bool loaded, busy;
  final String? error;
  final Set<String> pending;
  final Future<void> Function() onRefresh;
  final Future<TrackedSeries?> Function(String) onRemove;
  final Future<bool> Function(TrackedSeries) onRestore;
  final void Function(TrackedSeries, TrackedPage?) onOpen;

  @override
  State<TrackedSeriesContent> createState() => _TrackedSeriesContentState();
}

class _TrackedSeriesContentState extends State<TrackedSeriesContent> {
  final _search = TextEditingController();
  TrackedSeries? _removed;
  bool _restoring = false;
  String? _undoError;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _remove(TrackedSeries item) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消追更？'),
        content: Text('“${item.title}”将从列表移除，不再提醒新增分 P。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('取消追更'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final removed = await widget.onRemove(item.bvid);
    if (removed == null || !mounted) return;
    setState(() {
      _removed = removed;
      _undoError = null;
    });
  }

  Future<void> _undo() async {
    final snapshot = _removed;
    if (snapshot == null || _restoring) return;
    setState(() => _restoring = true);
    final restored = await widget.onRestore(snapshot);
    if (!mounted) return;
    setState(() {
      _restoring = false;
      // Another removal can complete while this restoration is in flight.
      if (identical(_removed, snapshot)) {
        if (restored) _removed = null;
        _undoError = restored ? null : '恢复失败，请再次点击撤销';
      }
    });
  }

  Future<void> _selectParts(TrackedSeries item) async {
    final page = await showModalBottomSheet<TrackedPage>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => TrackedPartsSheet(item: item),
    );
    if (page != null && mounted) widget.onOpen(item, page);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;
    final query = _search.text.trim().toLowerCase();
    final items = state.tracks
        .where(
          (item) =>
              query.isEmpty ||
              '${item.title}\n${item.owner}\n${item.bvid}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList(growable: false);
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: CustomScrollView(
              key: const PageStorageKey('tracked-series'),
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: '搜索追更',
                            hintText: '标题、UP 主或 BV 号',
                            prefixIcon: const Icon(CupertinoIcons.search),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: '清除搜索',
                                    onPressed: () => setState(_search.clear),
                                    icon: const Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                    ),
                                  ),
                            border: const OutlineInputBorder(),
                            floatingLabelStyle: TextStyle(
                              color: scheme.onSurfaceVariant,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: scheme.onSurface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            widget.error ??
                                (widget.loaded ? state.status : '正在读取追更记录…'),
                            style: TextStyle(
                              color: widget.error == null
                                  ? scheme.onSurfaceVariant
                                  : scheme.error,
                            ),
                          ),
                        ),
                        if (!state.permission && state.tracks.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('系统通知已关闭，仍可手动检查并查看更新。'),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              foregroundColor: scheme.onSurface,
                            ),
                            onPressed: widget.busy ? null : widget.onRefresh,
                            icon: const Icon(CupertinoIcons.arrow_clockwise),
                            label: Text(widget.busy ? '正在检查' : '检查更新'),
                          ),
                        ),
                        if (widget.busy) const LinearProgressIndicator(),
                        if (widget.loaded && items.isEmpty) ...[
                          const SizedBox(height: 24),
                          Text(state.tracks.isEmpty ? '还没有追更的视频' : '没有匹配的追更'),
                          const SizedBox(height: 8),
                          Text(
                            state.tracks.isEmpty
                                ? '打开视频，在更多菜单中选择“标记为番剧”。'
                                : '试试标题、UP 主或 BV 号，也可以清除搜索。',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return NewbiliLibraryTile(
                      key: ValueKey(item.bvid),
                      title: item.title,
                      cover: item.cover,
                      subtitle: item.owner,
                      metadata: '${item.pageCount} 个分 P',
                      onTap: () => widget.onOpen(item, null),
                      trailing: widget.pending.contains(item.bvid)
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : PopupMenuButton<String>(
                              tooltip: '选集与追更选项：${item.title}',
                              icon: const Icon(CupertinoIcons.ellipsis),
                              onSelected: (action) {
                                switch (action) {
                                  case 'parts':
                                    _selectParts(item);
                                  case 'last':
                                    widget.onOpen(item, item.pages.last);
                                  case 'remove':
                                    _remove(item);
                                }
                              },
                              itemBuilder: (_) => [
                                if (item.pages.isNotEmpty) ...[
                                  const PopupMenuItem(
                                    value: 'parts',
                                    child: Text('选集'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'last',
                                    child: Text('播放最后一 P'),
                                  ),
                                ],
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('取消追更'),
                                ),
                              ],
                            ),
                    );
                  },
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.viewPaddingOf(context).bottom + 24,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_removed case final snapshot?)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: NewbiliFormSection(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _undoError ?? '已取消《${snapshot.title}》追更',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: scheme.onSurface,
                    ),
                    onPressed: _restoring ? null : _undo,
                    icon: const Icon(CupertinoIcons.arrow_uturn_left),
                    label: Text(_restoring ? '正在恢复' : '撤销'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
