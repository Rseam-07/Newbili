import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/models/update_notifications.dart';
import 'package:PiliPlus/services/update_notification_service.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/permission_handler.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class UpdateNotificationPage extends StatelessWidget {
  const UpdateNotificationPage({super.key});
  @override
  Widget build(BuildContext context) {
    final service = UpdateNotificationService.instance;
    return Scaffold(
      backgroundColor: NewbiliFormStyle.background(context),
      appBar: AppBar(title: const Text('更新通知与追更')),
      body: Obx(
        () => UpdateNotificationContent(
          state: service.state.value,
          busy: service.busy.value,
          error: service.error.value,
          onSelectLevel: (level) async {
            await service.syncAccount(level);
            await service.refresh(manual: true);
          },
          onRequestPermission: service.requestPermission,
          onSystemSettings: openAppSettings,
          onRefresh: () => service.refresh(manual: true),
          onLibrary: () => Get.to(() => const TrackedSeriesPage()),
          onVideo: (bvid, page) => PiliScheme.routePush(
            Uri.parse('https://www.bilibili.com/video/$bvid?p=$page'),
          ),
        ),
      ),
    );
  }
}

class UpdateNotificationContent extends StatelessWidget {
  const UpdateNotificationContent({
    super.key,
    required this.state,
    required this.busy,
    this.error,
    required this.onSelectLevel,
    required this.onRequestPermission,
    required this.onSystemSettings,
    required this.onRefresh,
    required this.onLibrary,
    required this.onVideo,
  });
  final UpdateNotificationState state;
  final bool busy;
  final String? error;
  final ValueChanged<UploaderNotificationLevel> onSelectLevel;
  final VoidCallback onRequestPermission,
      onSystemSettings,
      onRefresh,
      onLibrary;
  final void Function(String bvid, int page) onVideo;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      MediaQuery.viewPaddingOf(context).bottom + 24,
    ),
    children: [
      NewbiliFormSection(
        title: '关注 UP',
        children: [
          for (final level in UploaderNotificationLevel.values)
            NewbiliSettingsRow(
              title: level.label,
              subtitle: level.explanation,
              icon: level == UploaderNotificationLevel.specialOnly
                  ? CupertinoIcons.star
                  : CupertinoIcons.bell,
              trailing: state.level == level
                  ? Icon(
                      CupertinoIcons.checkmark,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : const SizedBox.square(dimension: 24),
              onTap: () => onSelectLevel(level),
            ),
        ],
      ),
      if (!state.loggedIn && state.level != UploaderNotificationLevel.off)
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text('登录后才能读取关注动态与特别关注列表。'),
        ),
      NewbiliFormSection(
        title: '系统通知权限',
        children: [
          NewbiliSettingsRow(
            title: state.permission ? '系统通知已开启' : '开启系统通知',
            subtitle:
                '追更 ${state.seriesPermission ? '开启' : '关闭'} · 关注 UP ${state.upPermission ? '开启' : '关闭'}',
            icon: CupertinoIcons.bell,
            onTap: state.permission ? onSystemSettings : onRequestPermission,
          ),
          if (!state.permission)
            NewbiliSettingsRow(
              title: '前往系统设置',
              subtitle: '如果之前拒绝过通知，请在系统设置中开启',
              icon: CupertinoIcons.gear,
              onTap: onSystemSettings,
            ),
          NewbiliSettingsRow(
            title: busy
                ? '正在检查更新'
                : !state.permission
                ? '开启通知后可检查'
                : !state.hasTargets
                ? '添加追更后可检查'
                : '立即检查更新',
            icon: CupertinoIcons.arrow_clockwise,
            trailing: busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: !busy && state.permission && state.hasTargets
                ? onRefresh
                : null,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              error ?? state.status,
              style: TextStyle(
                color: error == null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
      NewbiliFormSection(
        children: [
          NewbiliSettingsRow(
            title: '我的追更',
            value: '${state.tracks.length} 项',
            subtitle: '自标记番剧与分 P 更新',
            icon: CupertinoIcons.tv,
            onTap: onLibrary,
          ),
        ],
      ),
      if (state.recent.isNotEmpty)
        NewbiliFormSection(
          title: '最近更新',
          children: [
            for (final item in state.recent.take(10))
              NewbiliSettingsRow(
                title: item['title'] as String,
                subtitle: item['body'] as String,
                icon: CupertinoIcons.play_rectangle,
                onTap: () =>
                    onVideo(item['bvid'] as String, item['page'] as int),
              ),
          ],
        ),
      Text(
        updateDeliveryNotice,
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

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
          Obx(
            () => IconButton(
              tooltip: '检查分 P 更新',
              icon: const Icon(CupertinoIcons.arrow_clockwise),
              onPressed: service.busy.value
                  ? null
                  : () => service.refresh(manual: true),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final state = service.state.value;
        return RefreshIndicator(
          onRefresh: () => service.refresh(manual: true),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.viewPaddingOf(context).bottom + 24,
            ),
            itemCount: state.tracks.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (state.tracks.isEmpty) ...[
                        const Text(
                          '还没有追更的视频',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('打开视频，在更多菜单中选择“标记为番剧”。标题、封面和分 P 会保存在这里。'),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        service.error.value ??
                            (!state.permission && state.tracks.isNotEmpty
                                ? '尚未开启系统通知，点击右上角铃铛设置提醒。'
                                : state.status),
                      ),
                      if (service.busy.value)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
                );
              }
              final item = state.tracks[index - 1];
              return TrackedSeriesTile(
                key: ValueKey(item.bvid),
                item: item,
                onOpen: () => PiliScheme.videoPush(null, item.bvid),
                onRemove: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('移除追更？'),
                      content: Text('“${item.title}”将从列表移除，也不再提醒新增分 P。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('保留'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('移除'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) await service.remove(item.bvid);
                },
              );
            },
          ),
        );
      }),
    );
  }
}

class TrackedSeriesTile extends StatelessWidget {
  const TrackedSeriesTile({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onRemove,
  });
  final TrackedSeries item;
  final VoidCallback onOpen, onRemove;
  @override
  Widget build(BuildContext context) => NewbiliFormSection(
    children: [
      InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              NetworkImgLayer(
                src: item.cover,
                width: 104,
                height: 65,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.pageCount} 个分 P · ${item.owner}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      NewbiliSettingsRow(
        title: '取消追更',
        icon: CupertinoIcons.trash,
        onTap: onRemove,
      ),
    ],
  );
}
