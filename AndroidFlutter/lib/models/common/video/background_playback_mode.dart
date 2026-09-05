import 'package:PiliPlus/models/common/enum_with_label.dart';

enum BackgroundPlaybackMode with EnumWithLabel {
  off('关闭'),
  listenOnly('仅听视频'),
  always('始终继续');

  @override
  final String label;
  const BackgroundPlaybackMode(this.label);

  static BackgroundPlaybackMode restore(String? value, bool? legacy) =>
      switch (value) {
        'off' => off,
        'listenOnly' => listenOnly,
        'always' => always,
        _ => legacy == null ? listenOnly : (legacy ? always : off),
      };

  bool allows({required bool listening, bool pictureInPicture = false}) =>
      pictureInPicture || this == always || (this == listenOnly && listening);
}
