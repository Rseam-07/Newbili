# Android 界面：Material 与 BiliBili-UWP

## 主参考

[Richasy/BiliBili-UWP](https://github.com/Richasy/BiliBili-UWP)，固定源码版本 `7db7f44088d7de4ad38a6268d7a18c5766d9d216`。这是用户指定的原版仓库。

重点检查：

- [TabletMainPage](https://github.com/Richasy/BiliBili-UWP/blob/7db7f44088d7de4ad38a6268d7a18c5766d9d216/BiliBili-UWP/TabletMainPage.xaml)：上方导航、主内容和独立右侧副页。
- [RecommendPage](https://github.com/Richasy/BiliBili-UWP/blob/7db7f44088d7de4ad38a6268d7a18c5766d9d216/BiliBili-UWP/Pages-Tablet/Main/RecommendPage.xaml)：选中视频的展示区与横向推荐。
- [TabletVideoDetailBlock](https://github.com/Richasy/BiliBili-UWP/blob/7db7f44088d7de4ad38a6268d7a18c5766d9d216/BiliBili-UWP/Components/Controls/TabletVideoDetailBlock.xaml)：视频与简介并排，作者、统计和操作依次排列。
- [CoverVideoCard](https://github.com/Richasy/BiliBili-UWP/blob/7db7f44088d7de4ad38a6268d7a18c5766d9d216/BiliBili-UWP/Components/Controls/CoverVideoCard.xaml)：封面、时长、标题之间的关系。

辅助检索涵盖 Bili.Uwp、Bili.Copilot、BiliYou、PiliPala、BiliPai、BewlyBewly、wiliwili、biliuwp-lite、BiliFlora 的项目介绍与可见截图。最终构图以用户指定的原版为准。

## 实现

| 部分 | 当前行为 |
| --- | --- |
| 手机主界面 | 品牌/搜索入口，左对齐分类，无外框视频卡片，贴底自定义导航。没有自动轮播大横幅。 |
| 平板首页 | 顶部导航、封面与简介并列、横向推荐。选择条目更新展示区，点击播放进入现有视频路由。 |
| 平板副页 | 1100dp 起，在推荐区右侧展开动态等真实页面；主内容继续存在。快速切换与收起保留状态。 |
| 平板播放 | 840×600dp 起，视频与简介并列，下方横向相关推荐，评论/分集在右侧展开。沿用原播放控制器。 |
| Material 语言 | 中性内容表面、语义前景/背景色、品牌粉、压下反馈、明确的选中状态和连续空间运动。 |
| 动效 | 每张封面独立 Hero 身份，重复视频不冲突；返回恢复来源位置；动画中断保留当前位置；播放器不因侧栏或封面过渡重新挂载。 |
| 无障碍 | 主触控目标至少 48dp，系统缩放生效；大字体推荐改为单列，平板标题栏收起字标；减少动态效果立即完成切换。 |

常规反馈 160ms、容器/副页 300ms、进入路由 400ms、退出 280ms。参考 [Material Motion](https://m3.material.io/styles/motion/overview/how-it-works)，具体排布和时序属于本项目的适配设计。

没有复制 UWP 的业务代码。保留 Flutter 模型、接口、账号、播放器和 Get 路由的生命周期。导航枚举的已存储索引未移动。设置中移除失效的浮栏、玻璃、侧栏模板开关。

## 验证

- Flutter 3.47.2 / Dart 3.13.2；使用本工程要求的专用 SDK 和补丁依赖。
- 全量回归 **144 项通过**；逐帧输出测试另在渲染任务中执行，包含封面往返、预测返回取消/提交、延迟装载、快速切换、滚动保留、评论展开不重建播放器、840×600dp 三倍字体和明暗渲染。
- 静态分析：**0 error / 0 warning**；保留上游已有的 33 条 info。
- 输出：375dp 手机浅/深色、320dp 两倍字体、1024dp/1280dp 平板、右侧副页、平板播放布局，以及封面往返的逐帧 MP4。
- 截图由生产 UI 组件在 Flutter 测试渲染器中生成。封面、统计和副页内容是演示素材；不代表登录账号或线上推荐结果。播放器截图验证布局，未在截图测试中解码真实视频。

安装包与最终 CI 结果见 [Android 开发预览发布页](https://github.com/Rseam-07/Newbili/releases/tag/android-preview-2026.09.15)。**尚未完成 Android 实机的播放、旋转、预测返回、120Hz 帧耗时或跨账号验收。** 源码与组件测试通过不能代替这些证据。

## 复现

在 AndroidFlutter 目录运行，Flutter SDK 应已按项目脚本打好补丁：

```sh
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
flutter test --no-pub \
  --dart-define=NEWBILI_VISUAL_OUTPUT=/tmp/newbili-ui-preview \
  --dart-define=NEWBILI_VISUAL_FONT=/path/to/a/CJK-font.ttf \
  --dart-define=NEWBILI_VISUAL_COVERS=design/ui-review-2026-09-15/fixtures \
  test/widgets/material_visual_test.dart
```

预览素材来源见预览目录 README。普通测试无需素材文件或系统中文字体；可视化测试应显式提供二者。
