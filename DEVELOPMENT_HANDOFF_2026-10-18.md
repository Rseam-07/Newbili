# Newbili 完整开发交接文档

更新：2026-10-18。面向用户、Codex、DeepSeek 和下一位维护者。本文件是**当前状态的入口**；任务优先级以[体验诊断与更新计划](NATIVE_UX_REVIEW_AND_UPDATE_PLAN_2026-10-18.md)为准。

## 1. 接手前必须知道的决定

1. **主仓库专注原生 iOS / iPadOS**，SwiftUI + UIKit + AVFoundation。Android 交给 [Newbili MD](https://github.com/Rseam-07/Newbili-MD)，不恢复旧 APK 管线。
2. 早期 Flutter Apple UI 实验被用户否定，已暂停。不要把它重新作为默认重写方向。
3. 用户认可原生浅色的基础结构，深色、反馈和动效可以大幅优化；目标是完整 Apple 设计体系，不是所有卡片都加玻璃。
4. 用户优先要求**完整批次代码**，之后统一检查和真机验收；不要每改一点就让用户装包，不以测试工作代替实现。
5. 原生卡顿、功能缺失、楼中楼异常和闪退都是实际用户问题。没有同设备性能采样，不应把原因归咎于 Swift，也不能声称新包已经彻底解决。
6. 用户希望 Codex 与 DeepSeek 共同开发。只通过明确补丁和共享契约合作，不能用旧工作区整仓覆盖新改动。
7. 源码存在、编译通过、单元测试通过、设备启动、端到端可用是不同状态，交付必须分别写清。

## 2. 当前工作区、分支与基线

### 2.1 哪个目录才是当前工程

| 位置 | 用途 | 接手方式 |
|---|---|---|
| `/Users/songkangcheng/Documents/ChatGPT/newbili/Newbili-Native` | **当前原生工作区** | 从这里继续，打开 `Newbili.xcodeproj` |
| `/Users/songkangcheng/Documents/ChatGPT/newbili/Newbili` | 暂停的 Flutter Apple 实验 | 只作历史参考，不覆盖当前工程 |
| `/Users/songkangcheng/Documents/newbili/Newbili-Native` | 用户提供的外部旧工作区，含 DeepSeek 排序补丁 | 本轮只读评审；挑选补丁移植 |
| `/Users/songkangcheng/Documents/newbili/Newbili` | 外部目录中的 Flutter 实验快照 | 不是当前 MD 主分支 |
| `/private/tmp/newbili-md-ux-2026-10-18` | 从固定 `md/main` 提取的只读对照 | 临时目录可能清理；可从 Git 重建 |

两个 `newbili` 父目录本身都不是原生 Git 仓库。执行 Git 命令前先确认当前目录，避免看错分支。

### 2.2 Git 状态与来源

| 项目 | 值 |
|---|---|
| 主仓库 | `https://github.com/Rseam-07/Newbili.git` |
| 恢复分支 | `codex/native-main-rescue` |
| 旧主线基线 | `74fee04386bfcb3b7428457b6aae9ed108f84eb7` |
| 本次公开预览源码提交 | **`f5ba7d446fb205ae9dd9fa8d1d9cd5b2b55927e4`** |
| MD remote | `https://github.com/Rseam-07/Newbili-MD.git` |
| 本次实际 MD 对照 | **`91fab3897705d2cc33c039ecf64d5a330a92fd91`** |
| 暂停实验 | `codex/flutter-apple-ui` / `1643be8` |
| 外部排序功能提交 | `3a3e5f49688968cd34e61d3e8d08374cb6cce835`，尚未移植 |

发布代码已上传恢复分支。上传后逐文件校验了远端树中的 1351 个文件，代码与本地一致；本地提交基线随后对齐公开预览提交，保留新文档。**这避免把先前约 150 个内容文件和 Android 删除再次当作未提交代码。** 本交接文件及其他文档属于随后文档提交，不改变已发布二进制。

默认 `main` 不因创建预览 Release 自动更新；恢复代码未在本轮直接合入 `main`。Android 退役、原生修复及文档都在恢复分支的可审查改动中，合入后才成为默认分支内容。不能把“有 Release”当作“已合并主线”。

### 2.3 为什么不直接合并 MD 仓库

MD 的主要业务和界面在 `AndroidFlutter/lib`。其仓库保留的旧 Swift 文件不是持续同步的新原生实现。对比基线时，大量 Swift 文件与旧原生相同，整仓合并不会把 Dart 里的成熟流程变成 Swift 功能。

正确方法是迁移端点、模型、分页/失败/身份语义和任务闭环，再接入原生 UI、系统播放与权限。不要通过复制 Flutter 目录或计算相同端点数量宣称功能已追平。

## 3. 版本、发布与设备必须区分

| 对象 | 包名 / 版本 | 实际状态 |
|---|---|---|
| 用户原正式 App | `com.rseam07.newbili`，旧版本 | 保留，未覆盖其数据 |
| 当前手机上的原生预览 | `com.rseam07.newbili.nativepreview`，1.0.7 (11) | 旧基线已安装；716 项测试对应这一批代码 |
| 本地完成的个人预览 | 同预览包名，1.0.7 (12) | Release、测试目标编译及严格签名检查通过；**未安装** |
| 本次公开 Release | `com.rseam07.newbili`，**1.0.9 (13)** | 正式最低系统 26.4；未签名预览 IPA，发布结果见下节 |

个人预览和正式包名不同，所以能共存。公开 IPA 需要使用者自行签名侧载，不是 TestFlight 或 App Store 分发，也不是可以直接点开安装的已签名包。不要把用户手机上 11 的表现误认为 13。

### 3.1 公开预览记录

- 目标 tag：`v1.0.9-ios-preview.1`。
- [Release 页面](https://github.com/Rseam-07/Newbili/releases/tag/v1.0.9-ios-preview.1)。
- [构建工作流](https://github.com/Rseam-07/Newbili/actions/runs/39091088787)，源码提交 `f5ba7d446fb205ae9dd9fa8d1d9cd5b2b55927e4`。
- 发布文件：`Newbili-iOS-1.0.9-13-unsigned.ipa`、`VALIDATION-1.0.9-13.json`、`SHA256SUMS-1.0.9-13.txt`。
- 发布状态：**待本轮最终核验后补记**。不能仅凭上传源码或工作流开始，就认定发布成功。
- 发布说明：[1.0.9 预览说明](RELEASE_NOTES_1.0.9-ios-preview.1.md)。它绑定实际发布提交；之后的文档更新不能冒充重新构建的包。

公开工作流检查包名、版本、构建号、最低系统，禁止包含描述文件、签名目录、P12/P8，并生成 SHA-256 和实际 Xcode/SDK 元数据。预览明确标记 prerelease，不把本轮未验收代码替换成稳定版承诺。

**符号注意**：本轮公开工作流保存构建日志、IPA 和验证文件，没有上传该次构建的 dSYM。个人构建 12 的 dSYM 只能匹配构建 12，不能用于公开构建 13。后续管线必须保留每次正式产物对应的 dSYM / UUID，见 G01。

## 4. 工程与运行环境

- 本机已安装并完成首次配置的 Xcode：`/Applications/Xcode-26.3.app`。
- 本地工具链：Xcode 26.3 / Swift 6.2 / iOS SDK 26.2；工程使用 Swift 5 语言模式与默认 MainActor 隔离设置。
- 正式部署目标：**iOS / iPadOS 26.4**。本轮未为了适配旧本地 SDK 降低正式最低系统。
- scheme：`Newbili`；测试模块引用 `@testable import bili`。
- 已配对的测试设备为用户 iPhone 16 Pro Max；上次记录系统 iOS 27.0。设备编号、个人 Team ID、描述文件不写入公开交接。
- 本地兼容脚本生成忽略的工程副本，最低系统匹配本机 SDK；因此本地预览编译证据与正式部署目标分别记录。
- GitHub 普通 CLI 未配置可用推送身份，本轮通过已连接 GitHub 工具上传 Git tree/commit/ref，再由 Actions 发布。不要让下一位开发者盲目重复 `git push` 或从浏览器提取令牌。

### 4.1 推荐命令

以下从当前原生仓库执行。先设置本机工具链；其他机器使用自己的真实路径。

```bash
export DEVELOPER_DIR=/Applications/Xcode-26.3.app/Contents/Developer
xcodebuild -version
xcodebuild -showsdks
git status --short
git branch --show-current
```

正式包的通用未签名 Release 构建与打包：

```bash
./Scripts/build-release-unsigned-ipa.sh
```

输出：`build/release-unsigned-ipa/Newbili-release-unsigned.ipa`；日志：`build/logs/release-unsigned-ipa.log`。它使用正式工程和最低系统，不加入个人签名。

本地 SDK 较旧时的模拟器**编译**：

```bash
./Scripts/build-native-preview.sh build
./Scripts/build-native-preview.sh build-for-testing
```

真机预览工程准备：

```bash
./Scripts/prepare-native-device-preview.sh
```

生成 `NativeDevicePreview.xcodeproj` 和本地 Info.plist。在副本中选择本人的开发团队，不修改正式工程中的签名配置。脚本重新运行会重新复制工程，个人签名设置可能需要在副本中重新选择。

优化配置下测试目标编译示例（替换设备 ID，示例本身不执行测试）：

```bash
xcodebuild build-for-testing \
  -project NativeDevicePreview.xcodeproj \
  -scheme Newbili -configuration Release \
  -destination 'platform=iOS,id=<LOCAL_DEVICE_ID>' \
  -derivedDataPath /private/tmp/newbili-device-next \
  -allowProvisioningUpdates
```

执行定向测试时先列出可用设备/模拟器，使用同一工程、配置、DerivedData 和目标，再加 `-only-testing:NewbiliTests/<Suite>`；`build-for-testing` 不是运行。不要直接沿用别人手机编号，也不要用 Debug 运行结果代表 Release 的体验。

若需要普通真机回归专用包，脚本支持 `./Scripts/prepare-native-device-preview.sh --regression`，生成独立 `NativeDeviceRegression.xcodeproj`，与日常预览数据分开。

## 5. 架构地图与修改入口

| 层 / 职责 | 主要入口 | 修改时要守住的边界 |
|---|---|---|
| 启动、依赖 | `App/NewbiliApp.swift`、`App/AppDependencies.swift` | 单元测试宿主不启动真实首页网络/后台任务 |
| 根导航与系统栏 | `App/RootTabView.swift`、`RootVideoNavigationHost.swift`、`VideoRouteLink.swift`、`VideoNavigationTransition.swift` | 来源属于卡片实例；导航和播放会话不是同一状态 |
| 返回手势 | `App/SystemBackGestureDelegateLease.swift`、根导航支持文件 | 手势取消必须恢复，不重新加入固定禁止点击计时 |
| 账号 | `Services/SessionStore.swift`、`MultiAccountSessionModels.swift` | 按用途取凭据快照；账号 MID + 凭据版本参与隔离 |
| 本地偏好/历史 | `Storage/LibraryStore.swift` | 无痕、账号和缓存上下文明确；不要让高频时钟广播整页 |
| HTTP / 签名 | `Services/BiliAPIClient.swift`、`WBISigner.swift` | WBI 与 app 签名不同；读写账号用途、失败/重试语义明确 |
| 首页 | `Features/Home/HomeViewModel*` | 缓存先呈现、请求代次、后台有界图片预取 |
| 搜索 | `Features/Search/SearchViewModel.swift`、`SearchVideoFilters*` | 查询身份包含类型/条件/时间快照；取消不代替代次校验 |
| PGC 浏览 | `HomePgcBrowseViewModel.swift`、`Models/PgcIndexConditions.swift` | 作品/条件/日历互不连带失败，页码成功才提交 |
| 详情编排 | `Features/VideoDetail/VideoDetailViewModel*` 与各 Actions 扩展 | 当前视频/CID/账号/请求代次；不是所有内容都等首帧 |
| 详情宿主 | `Features/VideoDetail/UIKitShell/` | SwiftUI/UIKit/播放器宿主之间几何所有权和生命周期交接 |
| 播放 | `Features/Player/PlayerViewModel*`、`AVPlayerHLSBridgeEngine.swift`、`PlayerRenderingEngine.swift` | 取流、准备、首帧、seek、回退和停止各有真实状态 |
| 音频 | `Features/Player/PlaybackAudioSessionCoordinator.swift` | 串行非主线程系统调用；租约防止旧页面释放新播放 |
| 弹幕 | `DanmakuOverlayView.swift`、`Services/DanmakuService.swift`、`DanmakuItemFilter.swift` | 轨道占用、时钟、筛选、缓存与发送分别处理 |
| 字幕 | `Features/Player/PlaybackSubtitleModel.swift`、`PlaybackSubtitleViews.swift` | 文档解析与索引离开 UI executor；时钟只更新叶子层 |
| 评论 | `Features/VideoDetail/VideoDetailComment*`、`CommentThreadServing.swift`、`VideoCommentSubmissionModel.swift` | root/dialog/目标回复身份、页码、取消、草稿与服务器回执 |
| 收藏 | `Features/Mine/FavoriteFolderEditor*`、详情 `FavoriteFolderSelection*` | 单一弹层、明确账号、失败保留选择/草稿 |
| 设计系统 | `DesignSystem/AppSurfaceColors.swift`、首页 `PressPreloadButtonStyle.swift` 等 | 语义色、系统材质、独立触控面积、减少动态/透明度 |
| 观测 | `PlayerMetricsLog` 与播放器/详情性能面板 | 已有阶段日志复用；日志不得记录 Cookie 或私信正文 |

上表省略的路径均位于 `Newbili/Sources/`。先用 `rg` 定位定义和调用方，不按文件名猜功能边界。大量扩展文件并不等于隔离良好，修改协议要一起检查实际调用方和 mock。

### 5.1 关键运行流

```text
卡片实例/来源
  → VideoRouteLink / 根导航
  → 详情模型（视频、CID、账号上下文）
      ├─ 播放 URL → 原生引擎/桥接 → item ready → 真正首帧
      ├─ 简介/分 P/相关内容
      ├─ 评论与楼中楼
      └─ UP / 点赞收藏关注状态
  → UIKit shell + SwiftUI 内容 + 独立播放/字幕/弹幕层
```

当前后两条支线在部分场景仍等待播放释放并固定延迟，A01/A02 要解除这一非必要依赖。不能在重构时把四条线再次捆成一个“整页 loading”。

## 6. 本轮已经写入的改动

以下说明代码状态，不替代设备验收。具体实现记录见 [10 月 18 日记录](NATIVE_IMPLEMENTATION_UPDATE_2026-10-18.md)。

### 6.1 响应与导航

- 音频 session 类别/激活/释放串行移出主线程；租约保护新旧播放交接；恢复播放受代次限制。
- 写操作按服务端回执结束忙碌，统计资料后台刷新；旧视频/账号/请求结果不应覆盖当前场景。
- 关注确认结果绑定 UP 与凭据版本，抵御晚到的旧资料；后续仍须检查跨页面/外部修改的失效规则，见 A06。
- 详情渲染合并 actor 回合，移除固定 16 ms 延迟；返回点击屏障跟随真实手势与转场，不再固定等待 450 ms。
- 卡片实例 UUID 的系统 zoom 来源与跨宿主上下文，加载封面承接到播放器；封面不是首帧。
- 首页响应先发内容、后图片预取；搜索视频和 UP 并行，旧请求/旧分页不回写。

### 6.2 评论、搜索与 PGC

- 楼中楼/对话使用 ID 回调和显式主线程异步闭包，模型内部解析目标；分页、服务器顺序、去重、缓存、取消、失败重试重新整理。
- 视频顶层评论、回复根评论、指定楼层回复接到真实提交接口；失败保留草稿、重复提交门控、切场景隔离。
- 搜索建议 host、输入法提交、历史/无痕、分页、分区/时长/相对日期筛选与签名条件补齐。
- PGC 条件读取、作品和日历独立加载，筛选代次与分页失败重试补齐。

### 6.3 播放与界面

- 弹幕按真实宽度、速度与剩余时间排轨；混合字号统一网格，固定弹幕按真实范围占位；暂停/倍速/首播恢复修正父图层时间。
- 系统导航玻璃与滚动边缘收敛；深色页面/卡片/正文层次统一；不再用大块不透明背景替代系统栏材质。
- 播放器至少 44 pt 独立触控区域，按宽度安排主次操作，隐藏开始即停止接收点击；中部控件参与布局避免重叠。
- 字幕轨道读取/下载/显示、语言/字号/时间校准、失败重试；切视频/CID/账号拒绝旧响应。PiP 字幕、外挂字幕和双轨翻译仍缺。
- 收藏夹创建/编辑/公开私密/删除，视频收藏弹层内创建夹后自动选中，保留其他待提交选择；账号凭据检查和失败草稿保留。
- 默认夹限制编辑/删除。排序和批量管理尚未进入此公开预览，DeepSeek 排序补丁单独评审。

## 7. 验证账本：证据只覆盖它对应的代码

| 批次 | 结果 | 可以说明什么 | 不可以说明什么 |
|---|---|---|---|
| 早期定向检查 | 90 项 + 后续取消补充，合计 93 个独立检查 | 搜索、PGC、弹幕等当时逻辑有覆盖 | 不覆盖后来所有代码，不代表真机体验 |
| 构建 11 | 624 XCTest + 92 Swift Testing，**716 通过** | 当时优化构建的手机回归完成 | 不覆盖 12/13 的新增字幕、音频、收藏和后续状态改动 |
| 构建 12 | Release 与测试目标编译成功；新增 13 项用例已编译未运行 | 当前新增逻辑能编译进 App/测试目标 | 不能写成新增测试全部通过 |
| 本地正式构建 13 | unsigned Release 编译成功，正式包名/1.0.9(13)/minOS26.4 检查一致 | 正式配置可以生成设备 App | 未在用户手机运行；本地 SDK26.2，不是所有正式系统场景 |
| 云端公开构建 13 | 以 Release 工作流最终结果为准 | 产物身份、签名材料排除、SHA 和源码可追溯 | 没有执行本批端到端或全量真机测试 |

### 7.1 本地证据位置

| 内容 | 位置 |
|---|---|
| 构建 12 App / dSYM / 签名与 UUID | `build/native-preview-12/`（被 Git 忽略，勿公开个人签名包） |
| 构建 12 Release 日志 | `/private/tmp/newbili-native-1018-final-build-2.log` |
| 构建 12 测试目标编译日志 | `/private/tmp/newbili-native-1018-test-compile-2.log` |
| 本地正式 13 Release 日志 | `/private/tmp/newbili-native-1.0.9-public-release-build.log` |
| 本地正式 13 产品 | `/private/tmp/newbili-native-public-release-derived/Build/Products/Release-iphoneos/` |
| 早期定向结果 | `/private/tmp/newbili-native-targeted-7.xcresult`、`newbili-native-cancellation.xcresult` |
| 本轮保留的日志副本 | `build/handoff-2026-10-18/`，随本地交接保留，不进入公开源码 |

临时目录和忽略目录不会随 Git clone 传给别人。需要迁移机器时，由用户安全复制必要的日志/符号/本地资料；不要因为文件没在 Git 里，就重新声称某项测试已执行。

### 7.2 已知崩溃与环境限制

- 旧设备记录 `Newbili-2026-10-14-215407.ips` 与当时 dSYM 匹配，主线程 `EXC_BAD_ACCESS` 定位到 `VideoDetailViewModel.loadMoreReplies(for:)`。已改 ID 回调和 actor 边界，但具体指针失效机制未最终证明，不能归咎编译器后宣布全部修复。
- 本地 iOS 26.2 模拟器曾出现 Swift actor / TaskLocal 合成析构崩溃。已经按堆栈做显式析构兼容处理；该环境异常和正式设备上的评论崩溃不是同一项证据。
- Swift 6.2 默认 MainActor 会影响测试 mock 的异步协议见证。当前本批通过显式 `@MainActor` 约束修正编译；新增协议实现时同步检查 mock。
- 个人预览 12 的符号 UUID 为 `E4D7B297-789F-3122-9519-3442C714C48E`，只匹配该次 App。代码一样但重编译，也不能假定 UUID 一样。
- 没有本批真实评论/投币/私信等服务器写入验收，没有 FPS 或首帧性能提升数字。

## 8. 还缺什么，不能对外说已经齐全

完整清单见[功能审查](NATIVE_RECOVERY_AND_FEATURE_AUDIT_2026-10-14.md)。优先级和完成条件见计划 A–E。

| 功能群 | 当前缺口 |
|---|---|
| 核心响应 | 评论首帧后 320 ms、UP/互动首帧后 350 ms；资料可选查询等待；首屏/返回缓存策略；布局与状态归属 |
| 播放 | 首帧阶段性能未测；密集弹幕与长播、PiP/后台/耳机/来电尚待本批真实验收 |
| 字幕 | 已有应用内字幕；系统 PiP、外挂、双轨翻译缺失 |
| 收藏/账号 | 排序待移植；跨夹批量移动/复制、完整关注分组、账号追番与云端记录管理不齐 |
| 评论 | 顶层/楼层发送已接；删除/举报/置顶等管理不齐，真实写入待用户选择执行 |
| 离线 | **完整视频离线下载缺失**；缓存图片/字幕/弹幕不算离线能力 |
| 内容 | 原生文章、独立音频/歌单、动态创作、PGC 评价尚不完整 |
| 工具/系统 | 云端弹幕管理、账号工具、WebDAV、DLNA/AirPlay 完整入口和实体设备链路不齐 |
| 消息/通知 | 私信高级设置有缺口；后台检查不是即时推送；未读和多账号需核对 |

不要把本地追更当账号追番，不把网页跳转当原生阅读，不把“有接口”当“用户能完成任务”。

## 9. 下一批具体从哪里开始

### 9.1 核心实现批次

1. **A01**：拆评论的播放门控和 320 ms。显式用户意图优先，保留身份/取消/代次。
2. **A02**：拆 UP/互动的门控和 350 ms；基础信息先到、统计后补。不能用未知值覆盖已确认的状态。
3. **A03/A04**：首页上下文缓存与详情并行加载状态，不以整页清空来表达刷新。
4. **A05/A06**：评论生命周期与跨页面写入状态，尤其审查关注确认的失效，防止永久压住外部新状态。
5. **B01/B04/B08**：宿主布局所有权、连续导航和深色系统规范，围绕一条完整用户链路交付。

这批代码完成再统一编译/定向回归，之后给用户一个清晰的设备验收单。不要再次停在换几个颜色和动画常量。

### 9.2 发布/工程后续 G 任务

| ID | 任务 | 原因 |
|---|---|---|
| G01 / P1 | 每次 Release 保存精确对应 dSYM 和 UUID，并把代码 SHA、Xcode/SDK、校验值写入可追溯清单 | 用户有闪退，不能依赖不同构建的符号 |
| G02 / P1 | 把发布 tag / 版本 / build 参数化，并在构建前检查 tag | 当前预览工作流固定 `v1.0.9-ios-preview.1`，后续代码推送不能复用旧 tag 或覆盖旧附件 |
| G03 / P1 | 普通 main 构建工作流的 runner/Xcode 选择修复 | 原 `unsigned-ipa.yml` 使用 `xcode-27` 标签；不能把预览工作流成功当作普通 main 管线已修好 |
| G04 / P2 | 建立两仓接口变更记录与匿名响应样本 | 共享业务契约，减少重复排错，不强行共享 UI |
| G05 / P2 | 把历史文档的状态指向当前交接与功能审查 | 避免旧 Flutter 方案、旧测试数字和旧功能宣传继续误导 |

## 10. Codex 与 DeepSeek 合作约定

### 10.1 建议分工

| 范围 | 首位负责人建议 | 交付要求 |
|---|---|---|
| 加载解耦、播放/导航生命周期、全局设计语义 | Codex 先处理 | A/B 任务 ID、状态和依赖图、完整场景实现、风险与验证记录 |
| 收藏排序修复移植、收藏/关注等边界明确模块 | DeepSeek 先处理 | 小补丁、接口契约、账号隔离、失败/重试与重进一致性 |
| 共享 API / Store 协议 | 当批集成者统一合入 | 先确认参数/返回/错误/隔离，不同时改大文件 |
| 交叉审查 | 另一位开发者 | 根据差异和证据评审，不凭模型名字打分 |

这是降低冲突的初始安排，用户可以调整。用户说将让 DeepSeek 一起开发，不代表当前助手已经启动或联络了外部 DeepSeek；本轮只提供文档与补丁审查。

### 10.2 每个任务开始前写清

```text
任务 ID：A01 / C01 …
基线：完整 SHA + 当前分支
用户流程：从哪个入口，完成什么
允许修改的文件：列明
共享接口：参数、返回、actor、身份、错误、取消
不属于本任务：写明，避免覆盖其他人的功能
完成条件：引用更新计划并补具体边界
```

每个任务完成时交付：

```text
实际修改文件与提交 SHA
用户行为前后变化
新增/修改接口及调用方
账号、取消、旧响应、重复提交、失败恢复如何处理
实际执行的检查：命令 / 配置 / 设备 / 结果 / 日志
未执行的检查和仍未实现的部分
与当前主分支的冲突位置和迁移建议
```

### 10.3 文件与合并纪律

- 同一时间只有一个集成者修改 `BiliAPIClient.swift`、`LibraryStore.swift`、`SessionStore.swift`、项目文件和全局 presentation。独立模块可以先提交接口提案，由集成者追加实现。
- 不用网盘旧快照或覆盖目录同步代码。每人独立分支/工作副本，提交小范围差异；有未提交修改先保留并记录，不清理别人的工作。
- 合并时读 `git diff`，按意图解决冲突。不能看到冲突就整文件选择 ours/theirs，尤其是账号、字幕、播放器和收藏选择。
- 新增 service 方法，同时维护实际实现、protocol、mock 和调用方。Swift 默认 actor 隔离要写明，不用随意添加 `@unchecked Sendable` 掩盖问题。
- 请求身份至少覆盖当前资源和账号版本；服务忽略取消时也拒绝旧结果。写操作已发出去，取消本地任务不代表服务器一定撤销。
- 非幂等操作不盲目自动重试；点赞/收藏等状态更新按回执应用，后台统计失败不诱导用户重复投币/发送。
- UI 尺寸和业务事实不能互相反复发布；时间/弹幕高频更新留在叶子层。
- 每次交付更新此交接的状态和相关任务清单，不能把“计划”改写成“已完成”却没有对应代码。

## 11. 外部 DeepSeek 补丁的准确接入方式

完整结论见[修改评价](DEEPSEEK_CHANGE_REVIEW_2026-10-18.md)。可以保留的主要新增为 `3a3e5f4`，不是其整个历史 checkpoint。

接入顺序：

1. 用当前恢复分支开独立任务分支，记录 SHA。
2. 对 `3a3e5f4` 做 `git show` 或生成 patch，不把其前一个大快照一起合入。
3. 修多索引移动落点和默认夹规则，明确未保存离开策略。
4. 手工合并同名 editor/API 文件，保留当前安全闭包捕获、账号选择和新增字幕/播放代码。
5. 更新协议、mock、请求契约和边界测试，统一编译。
6. 用户选择测试夹完成保存重读后，才把 C01 标为完成。

独立 `14312b5` 的具体类型默认参数修复当前已存在，无需重复应用。外部报告的 12 项排序测试通过不等于在当前新基线上通过。

## 12. 可直接交给 DeepSeek 的起始提示

```text
请先读 AGENTS.md、DEVELOPMENT_HANDOFF_2026-10-18.md、
NATIVE_UX_REVIEW_AND_UPDATE_PLAN_2026-10-18.md、
DEEPSEEK_CHANGE_REVIEW_2026-10-18.md。

当前主工程是 Newbili-Native，走 SwiftUI/UIKit/AVFoundation。
Android 已交给 Newbili-MD，早期 Flutter Apple 实验暂停。
请以当前 codex/native-main-rescue 最新 SHA 为基线，不覆盖旧目录。

先接 C01：修复并移植我之前的 3a3e5f4 收藏夹排序补丁。
只移植该小功能，不移入 7792e3b 整仓 checkpoint。
先修多索引移动 landing、默认收藏夹规则与显示一致性；
保留账号前后校验、失败草稿、单次保存和现有安全闭包捕获。
补实际请求契约，保留当前 API 文件里其他改动。

开始前列出基线 SHA、要改的文件、共享接口；
完成后给独立提交、实际检查记录、未验证项和冲突说明。
不要声称修复了播放器卡顿，也不要把旧测试数字算作当前通过。
用户要求完整批次代码后统一检查，不需要每改一点就让用户装包。
```

如用户分配不同任务，用对应 A–E 任务替换 C01 即可；接口和共享文件仍按上一节协调。

## 13. 设备验收和问题回传格式

此处为后续批次准备，本轮没有要求用户现在再次测试。先完成代码，再统一安装与验收。

建议顺序：

1. 关于页确认版本/build，确认打开的是正式 App 还是“原生预览”。
2. 首页冷启动/返回/滚动/慢网；搜索输入法、建议、筛选、翻页失败再试。
3. 视频首帧、评论不等播放、楼中楼/对话分页、快开快关/切 P。
4. 密集弹幕、暂停/倍速/seek、字幕、全屏/旋转/手势取消。
5. 用户自行选择账号和内容执行收藏、关注、评论、投币等写操作，再核对服务端与重进状态。
6. 锁屏、耳机、蓝牙、来电、后台、PiP 和回到同一会话。
7. 深浅色、大字、减少透明度/动态、iPad 宽度变化。

问题回传模板：

```text
App 名称 / 版本 / build：
设备型号 / 系统：
浅色或深色 / 字号 / 辅助设置：
入口 → 操作 → 实际表现 → 预期表现：
视频 BV / CID 或评论 ID（仅非私密内容）：
网络 / 是否登录 / 是否切账号：
是否必现 / 首次时间 / 截图或录屏：
崩溃 .ips 文件名 / 对应构建 dSYM UUID：
```

无需公开密码、Cookie、验证码、完整私信和账号令牌。崩溃必须与同一构建符号配对，不能拿构建 12 的符号猜公开 13 的地址。

## 14. 发布、数据与恢复

- 公开包使用正式包名，个人预览使用独立包名；保留两者数据，不自动卸载旧 App 或清 Keychain。
- 本地 Xcode 已登录并已有用户授权的调试签名设置；这些只保留在本地副本。不要把凭据、设备 profile、证书和 Keychain 内容交给其他开发者。
- 公开 release 只上传无个人签名的产物、校验和验证资料。Tag 一经发布不覆盖附件；新代码用新版本/build/tag。
- 原生恢复分支保留完整改动；旧 main、MD 和 Flutter 实验都在历史/各自分支。Android 源码从恢复分支移除，但 Git 历史和 MD 仓库仍可获取。
- 回退优先换回明确的旧构建/提交，不通过删除账号或清缓存掩盖问题。数据模型若新增持久化字段，先写兼容与迁移策略。
- 本地工作区未来若与远端不一致，先比较差异并备份；不要复制本文的某个旧 SHA 后执行 `reset --hard`。

## 15. 文档阅读顺序与过时内容

1. 本交接：当前位置、发布与证据、架构和合作规则。
2. [体验诊断与更新计划](NATIVE_UX_REVIEW_AND_UPDATE_PLAN_2026-10-18.md)：原因、设计、A–G 路线与完成标准。
3. [DeepSeek 修改评价](DEEPSEEK_CHANGE_REVIEW_2026-10-18.md)：具体补丁归属、缺陷和接入方式。
4. [完整功能审查](NATIVE_RECOVERY_AND_FEATURE_AUDIT_2026-10-14.md)：原生和 MD 的实际任务差距。
5. [本批实现记录](NATIVE_IMPLEMENTATION_UPDATE_2026-10-18.md)、[设备验收单](NATIVE_DEVICE_ACCEPTANCE_2026-10-15.md)、对应 Release 说明。

更早的 takeover / parity / performance / release 文档只是当时状态。尤其父目录早期优先 Flutter Apple 的方案已经被用户后续决定取代；旧测试通过、旧入口清单也不覆盖本批。不删除历史证据，但发生冲突时以本文件和实际代码/产物为准。

## 16. 交接完成检查

- [x] 当前原生目录、来源与暂停实验已区分。
- [x] Android 退役方案已进入恢复代码和 README，MD 定位明确。
- [x] 当前实现、明确缺口、优先级和设备验收边界分别记录。
- [x] DeepSeek 修改按实际提交评审，未误归属已有恢复工作。
- [x] 提供可执行的构建入口、架构地图、合作契约和起始提示。
- [ ] 公开 Release 的工作流成功、附件和摘要最终核验。
- [ ] 本批自动化执行和用户设备验收；此项属于下一轮验证，当前不标记通过。
- [ ] 恢复分支合入默认主线；此项不因预览发布而自动完成。
