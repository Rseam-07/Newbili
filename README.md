<p align="center">
  <img src="Newbili/Assets.xcassets/AppIcon.appiconset/newbili-icon.png" width="168" alt="Newbili app icon">
</p>

# Newbili

Newbili（简称 **nb**）是一个以 SwiftUI、UIKit 和 AVFoundation 编写的第三方 iOS 客户端。项目目标是在尽量覆盖 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 功能与接口行为的同时，用 Apple 原生控件、导航与 Liquid Glass 设计语言重新实现 iPhone/iPad 体验。

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%2026.4%2B-lightgrey.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5%20%2F%206-orange.svg)](https://www.swift.org/)

项目主页：[github.com/Rseam-07/Newbili](https://github.com/Rseam-07/Newbili) · 维护者：[Serge（@Rseam-07）](https://github.com/Rseam-07)

> Newbili 与哔哩哔哩无隶属、授权或背书关系。本项目仅用于学习、研究与个人使用，不提供破解内容、账号凭据、签名证书或私有密钥。使用者应自行遵守目标平台服务条款和当地法律法规。

## 当前能力

- 首页推荐、热门、完整分区榜单、番剧/影视索引与更新日历、搜索、多类型搜索结果和 UP 主空间；首页可选默认沉浸式新版或简约信息流，实时玻璃光晕默认开启并可单独切换。
- 视频详情、分 P、清晰度/编码/线路选择、续播、点赞、投币、收藏、评论与分享。
- 默认使用自研播放器控件，保留弹幕、全屏手势、画中画、听视频、SponsorBlock 等能力；设置中可切换为 iOS 原生播放控件。
- 动态流、动态详情、评论互动、图文/视频/转发动态展示。
- 直播首页、分区、搜索、房间播放与直播弹幕。
- 二维码、短信和网页登录，多账号实验；登录后显示用户等级。
- 观看记录、收藏夹、稍后再看及基础账号消息/私信界面。
- 原生标签页、导航栈、菜单、表单、材质与 Liquid Glass 外观。
- 首页、图片缓存、音频浮条与弹幕渲染采用低分配和精确状态订阅策略，在保留动画、实时模糊和全部功能的前提下降低滚动与播放时的主线程负担。

Newbili 仍在持续补齐 PiliPlus 的长尾功能。PGC 高级筛选与完整追番管理、离线下载、WebDAV、DLNA、完整专栏/音频、动态发布和私信高级能力尚未全部达到一比一覆盖；请以 [功能对照基线](UPSTREAM_PARITY_2026-08-19.md) 为准，避免把“已有入口”误认为“完整闭环”。

## 播放器设计

设置 → 播放设置中可以选择控件模式：

- **Newbili 控件（默认）**：播放器、弹幕层、全屏手势和玻璃控件处于同一渲染层级，优先保证弹幕流畅度与完整交互。
- **iOS 原生控件**：使用系统播放控件，适合更偏好系统交互的用户；受系统全屏层级限制，部分覆盖层体验可能不同。

## iOS 27 分层图标

主图标使用 Apple Icon Composer 制作，包含 Atmosphere、TV Shell、Screen、Signal 四层，并启用 Design Generation 27。Xcode 直接编译 `Newbili/Newbili.icon`，由系统生成 Default、Dark 与 Mono 外观。

- 可编辑 Icon Composer 工程：`Brand/NewbiliIcon/Newbili.icon`
- 分层 SVG 和备用 PNG：`Brand/NewbiliIcon/`
- 经典小电视造型为 Newbili 全新绘制，不沿用旧项目文字标志。

## 开发环境

- macOS
- Xcode 27.0 beta 或更新版本（构建 Design Generation 27 分层图标）
- iOS / iPadOS 26.4+
- Swift 5 语言模式，兼容 Swift 6 工具链

打开 `Newbili.xcodeproj`，选择 `Newbili` scheme 即可运行。命令行示例：

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild \
  -project Newbili.xcodeproj \
  -scheme Newbili \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone Air' \
  build
```

## 测试

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild test \
  -project Newbili.xcodeproj \
  -scheme Newbili \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone Air'
```

测试覆盖服务解码、账号会话、播放器恢复、HLS Bridge、弹幕、评论、稍后再看、PGC 路由和主要设置持久化。登录态接口仍需使用测试账号在真机上做端到端验证。

## 构建未签名 IPA

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
./Scripts/build-release-unsigned-ipa.sh
```

输出位于 `build/release-unsigned-ipa/Newbili-release-unsigned.ipa`。未签名 IPA 不能直接安装，需要使用自己的 Apple 证书/描述文件或合规侧载工具签名。

仓库内置 `.github/workflows/unsigned-ipa.yml`，推送到 `main` / `master` 或手动触发时会生成 Release 未签名 IPA artifact。
工作流使用 GitHub Actions 的 `xcode-27` 预览运行器，以便正确编译 Design Generation 27 图标。

## 使用自己的证书安装

交互式脚本不会把 P12 密码写进项目或配置文件：

```bash
./Scripts/sign-install-unsigned-ipa.sh --configure
```

也可以双击 `Scripts/nb-install-ipa.command`。本机生成的配置默认保存在 `~/.config/newbili/`，已被设计为仓库外文件。不要提交 `.p12`、`.mobileprovision`、Cookie、`SESSDATA`、`bili_jct` 或任何账号凭据。

## 项目结构

```text
Newbili/                 App 源码、资源与分层主图标
NewbiliTests/            单元与回归测试
Newbili.xcodeproj/       Xcode 工程与共享 Scheme
Brand/NewbiliIcon/       图标 SVG、PNG 和 Icon Composer 源工程
Config/                  非敏感构建配置
Scripts/                 构建、签名与验证脚本
.github/workflows/       未签名 IPA 自动构建
```

项目不依赖 CocoaPods 或 Swift Package；运行时主要使用 SwiftUI、UIKit、AVFoundation、AVKit、VideoToolbox、Metal、Network、WebKit、AuthenticationServices、PhotosUI、Compression 与系统 zlib。

## 致谢与第三方项目

Newbili 的原生实现由本仓库维护，但功能语义、接口行为、交互思路与工具链得到了以下项目的直接帮助。感谢所有作者和贡献者：

| 项目 | 在 Newbili 中的作用 | 许可证/说明 |
| --- | --- | --- |
| [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) | 最主要的功能、接口参数与行为对照上游 | GPL-3.0 |
| [PiliPalaX](https://github.com/orz12/PiliPalaX) | PiliPlus 的上游演进链路 | GPL-3.0 |
| [PiliPala](https://github.com/guozhigq/pilipala) | PiliPalaX / PiliPlus 的原始上游链路 | GPL-3.0 |
| [AniShelf](https://github.com/samuelhe52/AniShelf) | 番剧、动漫与影视页面的沉浸背景、海报卡片和信息层级设计参考 | Apache-2.0；Newbili 已按自身导航与播放链路重新实现 |
| [MiniBili-WEB](https://github.com/ResistanceTo/MiniBili-WEB) | Apple 平台产品呈现与界面参考 | MIT |
| [PiliPod](https://github.com/BPTPW/PiliPod) | Swift 原生客户端与播放器交互参考 | GPL-3.0 |
| [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect) | 公开接口文档与字段语义参考 | 仓库未声明标准开源许可证；仅作资料引用 |
| [BilibiliSponsorBlock](https://github.com/hanydd/BilibiliSponsorBlock) | SponsorBlock 分段查询/上报 API 与社区数据 | GPL-3.0；数据/API 条款以其项目为准 |
| [SponsorBlock](https://github.com/ajayyy/SponsorBlock) | SponsorBlock 原始理念和协议上游 | GPL-3.0；数据库/API 另有条款 |
| [FFmpeg](https://github.com/FFmpeg/FFmpeg) | 可选 AV1 VideoToolbox 研究/拉取脚本；默认 App 不捆绑 FFmpeg 二进制 | LGPL/GPL 取决于构建选项 |
| [actions/checkout](https://github.com/actions/checkout) | GitHub Actions 中检出源码 | MIT |
| [actions/upload-artifact](https://github.com/actions/upload-artifact) | GitHub Actions 中上传未签名 IPA 构建产物 | MIT |

更完整的归属与使用边界见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。Apple、iOS、Swift、SwiftUI、Xcode、Icon Composer 等名称和商标归各自权利人所有。

## 隐私与安全

- 登录态保存在设备 Keychain；调试日志应避免输出完整 Cookie 和 Token。
- `.gitignore` 排除 IPA、证书、描述文件、私钥、环境文件、构建目录和本地配置。
- 提交或发布前应运行密钥扫描并检查 Git 历史；仅删除工作区文件不能撤回已经推送的凭据。
- 若凭据曾出现在公开位置，请立即在对应服务吊销/刷新，而不是只从代码中删除。

安全问题请参阅 [SECURITY.md](SECURITY.md)。普通缺陷和功能建议可在 [Issues](https://github.com/Rseam-07/Newbili/issues) 提交。

## 参与贡献

欢迎 Issue、测试反馈和 Pull Request。请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)，并为行为改动补充测试。对 PiliPlus 功能移植时，应在 PR 中注明对应页面/接口、加载与错误状态、登录态验证范围。

## 许可证

Newbili 采用 [GNU General Public License v3.0](LICENSE)（GPL-3.0-only）开源。复制、修改或分发本项目及其二进制时，请遵守 GPLv3，包括保留版权与许可声明、提供对应源代码，并在适用时以同一许可证开放衍生作品。

第三方项目、API 服务和社区数据保留各自版权、许可证与服务条款；本项目的 GPLv3 不会替代它们。

## 支持

Star、Issue、测试日志、代码贡献和分享都能帮助项目继续改进。赞助完全自愿，不会改变开源许可证，也不承诺优先支持或路线图决定权。详情见 [SUPPORT.md](SUPPORT.md)。
