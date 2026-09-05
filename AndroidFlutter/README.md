# Newbili Android

这是 Newbili 的 Android 工程，基于 PiliPlus `44680b8a486a0518f366a2c9bff6242506cf8783`（2.1.2 系列，2026-08-30）修改。保留上游 Flutter 业务、数据、播放器、弹幕、下载、后台音频、画中画和路由层，使用现有 iOS 客户端作为界面与交互对齐基准。当前尚未完成全部 iOS 功能和二级页面的对齐，不能把基础工程的完整性等同于跨端功能一致。

## 设计边界

- iOS 的实际源代码与模拟器画面是设计基准：品牌粉 `#EE719E`、居中分类、问候语、轮播、默认双列视频卡、五项胶囊导航、个人页分组和搜索热词。
- 复用 Flutter 业务实现和统一组件，不另建删减功能的 Swift/Skip 演示壳；Material 底层保留 Android 系统返回、焦点、触控与无障碍语义。
- 根导航与播放器详情/评论导航共用胶囊组件；个人页和设置入口共用分组、行与路由映射。大字号与底部安全区参与高度计算。
- 固定导航、播放器控制和关键浮层可使用实时背景模糊；滚动视频卡使用静态半透明材质，避免每个列表项重复采样背景。
- Android 13+ 使用增强玻璃，Android 12/12L 使用基础模糊；低内存、省电模式或用户关闭时自动使用静态 MD3 Surface。
- 系统“减少动态效果”开启后，首页轮播和按压/状态动效会停用或即时完成。
- 播放器控制条使用深色玻璃，以保证白色控件在浅色主题和明亮视频上仍清楚可见；列表项不各自做模糊。

v1.0.7 进一步对齐搜索结果、通知与追更、后台播放三档设置。代码、回归证据及尚未达到完全对齐的部分见根目录 `PERFORMANCE_PARITY_2026-09-05.md`；版本说明见 `RELEASE_NOTES_1.0.7.md`。不恢复已撤回的 1.1.0 发布。

## 构建

需要 Flutter 3.47.2、JDK 17、Android SDK 37、NDK `28.2.13676358` 和 CMake 3.22.1。PiliPlus 对固定 Flutter SDK 与 `material_ui` 有补丁，必须使用一次性或专用 SDK：

```bash
export FLUTTER_BIN=/path/to/flutter-3.47.2/bin/flutter
export ANDROID_SDK_ROOT=/path/to/android-sdk
Scripts/prepare-android-flutter.sh
Scripts/build-android-apk.sh
```

脚本会执行 analyze、单元测试、按 ABI 构建、包名/minSdk/签名核验，并把以下文件写到 `dist/`：

```text
Newbili-Android-1.0.7-10-armeabi-v7a-test.apk
Newbili-Android-1.0.7-10-arm64-v8a-test.apk
Newbili-Android-1.0.7-10-x86_64-test.apk
```

公开仓库没有正式 Android 私钥。为保持与既有测试 APK 的覆盖升级关系，本脚本只在显式开关下沿用同一台构建机的测试证书，并将文件明确标记为 `test`。这是开启优化的 Release 构建，不是 Debug 运行模式；没有 `key.properties` 时，普通 release 构建会主动失败，不再静默退回测试签名。

## 升级与隐私

- 包名保持 `com.rseam07.newbili`，versionCode 为 10；沿用既有测试签名，可覆盖相同签名、版本号更低的测试包，不需要删除账号数据。
- 首次覆盖旧 Compose 客户端时，会由 Android Keystore 解密旧会话；只有成功写入新的加密 Hive 账号 box 后才删除旧记录。
- 新账号 box 的 256-bit 随机密钥由 Android Keystore 中的不可导出密钥包装。
- 如果 APK 证书与既有 Debug 测试证书不同，Android 会拒绝覆盖安装；不要通过删除账号数据来掩盖签名不连续。

## 通知与后台播放

- 设置 → 更新通知与追更：关闭、仅特别关注、全部关注。只有显式开启关注通知才向原生后台检查服务同步当前账号凭据；凭据用 AES-GCM 加密，密钥由 Android Keystore 包装。关闭或退出账号后清除后台副本。
- 视频更多菜单 → 标记为番剧 / 追更；我的 → 我的追更。记录已有 CID，新分 P 才提醒，删除或重排不误报。首次关注检查只建立基线，不推送旧投稿。
- 原生 JobScheduler 周期检查，不启动额外 Flutter 引擎，不与前台同时写账号 Hive。并发前后台检查共享结果，接口失败保留上一次状态供重试。
- 后台周期最短 15 分钟，且受省电、网络和系统调度影响，不承诺即时到达。返回前台和手动刷新也能触发检查。Android 系统或应用通知被关闭时，页面显示对应状态。
- 后台播放为“关闭 / 仅听视频 / 始终继续”，默认仅听视频；旧用户明确保存的开关自动迁移。系统 PiP 属于仍然可见的播放，不因关闭后台音频而暂停。

## 尚需实体设备验收

静态分析、单元测试与 APK 构建不能替代真机。发布说明会单列 Android 12/13/17 的真机验收状态，重点包括扫码登录、视频取流、弹幕、评论、下载、PiP、锁屏后台音频、蓝牙/耳机中断、120Hz 滚动与低内存降级。
