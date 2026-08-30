# Newbili Android

这是 Newbili 的完整 Android 客户端，基于 PiliPlus `44680b8a486a0518f366a2c9bff6242506cf8783`（2.1.2 系列，2026-08-30）修改。导入时保留了上游 Flutter 业务、数据、播放器、弹幕、下载、后台音频、画中画和路由层；Newbili 的主要改动位于主题、公共 Surface、移动/平板导航和交互表现层。

## 设计边界

- Fluent UI 提供信息层级、亚克力、描边、柔和光晕和宽屏主从布局。
- Material 3 保留 Android 导航、ripple、系统返回、触控语义和动态色行为。
- BiliBili-UWP 的桌面侧栏与 Master–Detail 只在足够宽的平板上采用；手机不复制桌面固定侧栏或常驻右栏。
- 固定导航、播放器控制和关键浮层可使用实时背景模糊；滚动视频卡使用静态半透明材质，避免每个列表项重复采样背景。
- Android 13+ 使用增强玻璃，Android 12/12L 使用基础模糊；低内存、省电模式或用户关闭时自动使用静态 MD3 Surface。
- 系统“减少动态效果”开启后，首页轮播和按压/状态动效会停用或即时完成。

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
Newbili-Android-1.1.0-8-armeabi-v7a-test.apk
Newbili-Android-1.1.0-8-arm64-v8a-test.apk
Newbili-Android-1.1.0-8-x86_64-test.apk
```

公开仓库没有正式 Android 私钥。为保持与 v1.0.5 测试 APK 的覆盖升级关系，本脚本只在显式开关下沿用同一台构建机的 Android Debug 证书，并将文件明确标记为 `test`；没有 `key.properties` 时，普通 release 构建会主动失败，不再静默退回 Debug 签名。

## 升级与隐私

- 包名保持 `com.rseam07.newbili`，versionCode 为 8，可覆盖公开的旧 Android 测试包（versionCode 2）。
- 首次覆盖旧 Compose 客户端时，会由 Android Keystore 解密旧会话；只有成功写入新的加密 Hive 账号 box 后才删除旧记录。
- 新账号 box 的 256-bit 随机密钥由 Android Keystore 中的不可导出密钥包装。
- 如果 APK 证书与既有 Debug 测试证书不同，Android 会拒绝覆盖安装；不要通过删除账号数据来掩盖签名不连续。

## 尚需实体设备验收

静态分析、单元测试与 APK 构建不能替代真机。发布说明会单列 Android 12/13/17 的真机验收状态，重点包括扫码登录、视频取流、弹幕、评论、下载、PiP、锁屏后台音频、蓝牙/耳机中断、120Hz 滚动与低内存降级。
