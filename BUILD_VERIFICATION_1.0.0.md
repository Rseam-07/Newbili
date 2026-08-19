# Newbili 1.0.0（1）构建验证

验证日期：2026-08-19

## 交付物

- 文件：`dist/Newbili-1.0.0-1-unsigned.ipa`
- 大小：18,096,773 字节
- SHA-256：`bc689cb4dff3e8b87e2703606b359626703c949b4a6b79c6901240a6e79602a7`
- 签名状态：未签名；不含 `_CodeSignature` 和 `embedded.mobileprovision`

## 应用元数据

- App / 可执行文件：`Newbili`
- Bundle ID：`com.rseam07.newbili`
- 版本：`1.0.0`（1）
- 最低系统：iOS / iPadOS 26.4
- 架构：arm64
- 构建工具：Xcode 27.0 beta（27A5228h）、iPhoneOS 27.0 SDK
- 主图标：`Newbili.icon`，Design Generation 27；产物包含 iPhone/iPad 图标及 `Assets.car`

## 自动测试

- 设备：iPhone 17 Pro 模拟器（iOS 26.5）
- 总数：483
- 通过：482
- 失败：0
- 跳过：1
- 结果：Passed
- 结果包：`/private/tmp/Newbili-Rseam07-Serial-1.1.0-273-Tests.xcresult`

完整串行回归测试在版本号重置前、相同功能源码上执行；随后只将营销版本和构建号调整为 `1.0.0 (1)`，并重新完成 Release 构建和下列包体检查。由于本轮运行环境的外部执行额度限制，没有重复生成仅版本号不同的测试结果包；这不是测试失败。

## 包体检查

- `unzip -t`：通过，压缩数据无错误
- `Info.plist`：名称、Bundle ID、版本、最低系统及图标键均符合预期
- Mach-O：arm64
- `codesign`：确认包体未签名
- 空 Framework 清理：0 个；包内没有无效空 Framework

## 尚需真机验证

未签名 IPA 需要使用安装者自己的证书和描述文件重新签名。登录态、高清/会员播放、发弹幕、发评论、AI 总结、动态、收藏及用户等级仍应在已登录真机上做最终端到端验证；本报告不把模拟器测试等同于真实账号验收。
