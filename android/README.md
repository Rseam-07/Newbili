# Newbili Android

这是 Newbili 的 Android 客户端起点，采用 Jetpack/JetBrains Compose，并通过 `io.github.kyant0:backdrop:2.0.0` 使用 AndroidLiquidGlass 的公开 API。

- 窄屏使用底部玻璃导航，宽度达到 720dp 自动切换侧栏。
- 首页卡片和动态流会按窗口宽度自适应。
- 已接通 B 站 App 扫码登录、加密会话持久化，以及昵称、头像、UID、等级和经验进度刷新。
- Android 12 及以上的正常性能设备使用 Backdrop；低内存、省电模式、旧系统或用户关闭效果时自动切到高对比透明容器。
- 首页真实数据、动态接口、播放器和其余功能仍需继续从 iOS/PiliPlus 语义层迁移。

构建要求：JDK 17、Android SDK 37、Build Tools 37.0.0。

```bash
cd android
./gradlew :app:assembleDebug
```

AndroidLiquidGlass/Backdrop 为 Apache-2.0 许可，归属信息见仓库根目录 `THIRD_PARTY_NOTICES.md`。
