# Contributing to Newbili

感谢你愿意改进 Newbili。

## 提交前

1. 先搜索现有 Issue 和 Pull Request。
2. 缺陷请提供系统版本、设备型号、Newbili 版本、复现步骤、期望与实际结果。
3. 日志中必须移除 Cookie、`SESSDATA`、`bili_jct`、手机号、证书信息和设备标识。

## 开发约定

- 使用 `Newbili.xcodeproj` 与 `Newbili` scheme。
- 界面优先采用 SwiftUI/UIKit 原生控件和 Apple 设计语言。
- 播放器改动必须同时考虑弹幕、横竖屏、画中画、后台音频、恢复与错误状态。
- 从 PiliPlus 对齐功能时，在 PR 中注明对应上游页面/接口及对照提交。
- 新增行为或修复回归时补充 `NewbiliTests` 测试。
- 不提交 IPA、构建目录、账号数据、Cookie、证书、描述文件或本地签名配置。

## 验证

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild test \
  -project Newbili.xcodeproj \
  -scheme Newbili \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone Air'
```

至少确保受影响目标能够编译，相关测试通过，且 `rg -i 'cookie|sessdata|bili_jct|mobileprovision|BEGIN PRIVATE KEY'` 的结果中没有真实凭据。

## Pull Request

PR 描述应包含：目的、主要改动、测试证据、未验证范围和必要截图。请保持改动聚焦；不要把无关格式化或生成物混入同一 PR。

提交代码即表示你有权按 GPL-3.0-only 提供该贡献，并同意贡献随项目按该许可证分发。
