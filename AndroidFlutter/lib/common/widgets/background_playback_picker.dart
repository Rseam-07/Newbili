import 'package:PiliPlus/common/widgets/newbili_form.dart';
import 'package:PiliPlus/models/common/video/background_playback_mode.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

Future<void> showBackgroundPlaybackPicker(
  BuildContext context,
  BackgroundPlaybackMode selected,
  ValueChanged<BackgroundPlaybackMode> onSelected,
) async {
  final value = await showModalBottomSheet<BackgroundPlaybackMode>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: NewbiliFormStyle.background(context),
    builder: (context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: NewbiliFormSection(
          title: '后台播放',
          children: [
            for (final mode in BackgroundPlaybackMode.values)
              NewbiliSettingsRow(
                title: mode.label,
                subtitle: switch (mode) {
                  BackgroundPlaybackMode.off => '离开前台后暂停，返回继续；画中画不受影响',
                  BackgroundPlaybackMode.listenOnly => '仅在播放器开启“听视频”时继续音频',
                  BackgroundPlaybackMode.always => '视频和音频在后台继续播放',
                },
                icon: mode == BackgroundPlaybackMode.listenOnly
                    ? CupertinoIcons.headphones
                    : CupertinoIcons.play_circle,
                trailing: selected == mode
                    ? const Icon(CupertinoIcons.checkmark)
                    : null,
                onTap: () => Navigator.pop(context, mode),
              ),
          ],
        ),
      ),
    ),
  );
  if (value != null) onSelected(value);
}
