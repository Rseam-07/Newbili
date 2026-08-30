# Newbili 1.1.0 (8)

这是首个同时提供 iOS/iPadOS 与完整 Android 客户端的 Newbili 版本。

## Android

- Android 不再使用只有外壳的早期 Compose 原型，改为基于 PiliPlus `44680b8a486a0518f366a2c9bff6242506cf8783` 的完整 Flutter 功能底座。推荐、热门、分区、番剧影视、动态、搜索、登录与多账号、视频/直播播放、弹幕、评论、收藏、下载、DLNA、后台音频、画中画和完整设置均保留。
- 视觉层使用 Fluent UI 的内容层级与亚克力思路、Material 3 的 Android 交互语义，并参考 BiliBili-UWP 的布局后重新适配移动端：手机使用底部导航和二级频道，平板使用侧栏，大横屏才启用辅助详情布局。
- 新增统一的 Fluent/MD3 主题 token、公共 GlassSurface 与性能档位。Android 13+ 使用增强玻璃，Android 12/12L 使用基础模糊；低内存、省电模式或用户关闭效果时自动退化为静态 MD3 材质。实时模糊集中于导航、播放器控制和关键浮层，滚动卡片使用静态材质以降低重复采样。
- 首页加入“为你推荐”焦点轮播，默认从推荐流取前五项、每六秒自动切换；系统开启“减少动态效果”时停止自动轮播。焦点内容不会在下方列表重复出现。
- 播放器底部控制条加入可降级液态玻璃；播放/暂停、全屏顶栏及点赞/投币/收藏等命中区扩大至至少 48dp。播放状态、按压、点赞成功和一键三连进度均有轻量动画；三连继续使用 1.2 秒进度弧、震动和取消保护。
- 账号 Hive box 使用随机密钥加密，密钥由 Android Keystore 中的不可导出密钥包装。覆盖旧 Compose 测试版时会尝试一次性迁移原有 Keystore 加密登录态，只有新账号写入成功后才删除旧记录。
- 更新检查改为比较语义版本，不再用 Release 创建时间判断，避免当前版本反复提示自己更新。下载资产按 ABI 命名，可正确匹配 `arm64-v8a`、`armeabi-v7a` 与 `x86_64`。

## iOS / iPadOS

- 在 1.0.6 的播放器、弹幕、后台播放、画中画、Apple Intelligence 本地总结和三套首页基础上，新增可重启生效的 Fluent UI 风格切换，并由共享设计 token 统一卡片、阴影、玻璃与导航表现。
- 优化播放器进入/退出、视频表面重绑定、首页图片预取及预加载策略，减少重复创建、无效预取与返回详情后的重新加载。
- 播放、点赞与一键三连进一步补齐按压、进度、成功和取消动效，同时保留“减少动态效果”与 VoiceOver 语义。

## 验证

- iOS/iPadOS：Xcode 27.0、iPhone Air（iOS 26.5）模拟器共 653 项，652 通过、0 失败、1 项因模拟器不支持系统画中画跳过。Release IPA 已核验为 `1.1.0 (8)`、arm64、压缩结构完整且未签名。
- Android：Flutter 3.47.2 全工程 analyze 为 0 error、0 warning（33 条上游弃用/风格 info）；10/10 单元测试通过。三个 Release APK 均为 `com.rseam07.newbili`、`1.1.0 (8)`、minSdk 31、targetSdk 37，通过 zipalign、APK v2 签名和 ABI 内容核验。

iOS IPA 为未签名包，需自行签名后安装。Android 公开仓库尚无正式发布私钥，本次 APK 沿用 v1.0.5 Android 测试包的同一 Debug 证书以保证覆盖升级，因此文件明确标为 `test`，不应视为应用商店生产签名。Android 12/13/17 实体设备上的扫码登录、真实视频取流、弹幕、下载、PiP、锁屏后台音频、蓝牙/耳机中断和高刷新率性能仍需继续验收；本说明不把编译成功等同于真机闭环。

## SHA-256

- `Newbili-1.1.0-8-unsigned.ipa`: `56ae10a6e74a8ffa0b23f576d575be5555b2067cf0f496f94d3b930ab63aa9ab`
- `Newbili-Android-1.1.0-8-arm64-v8a-test.apk`: `44e7db7837d4aa0e664fcaefe778e1bcc1f69905d013c4d6aa2fe1ad64bd155f`
- `Newbili-Android-1.1.0-8-armeabi-v7a-test.apk`: `39ec3bf565141a59b57ee91443049aba42052d944286d20531763a7f697352b4`
- `Newbili-Android-1.1.0-8-x86_64-test.apk`: `9b8aec7b93070514b2b085346f9313e09489d063a04cd88f8c2fc45edc3aa6c5`
