# Newbili 图标源文件

图标以 1024 × 1024 画布设计，保留经典双天线小电视意象，但不复刻现有品牌的具体比例与表情。

## 图层顺序

从后到前导入 Icon Composer：

1. `01-atmosphere.svg`：背景气氛与色彩折射元素。
2. `02-tv-shell.svg`：小电视天线、外壳与支脚。
3. `03-screen.svg`：深色玻璃屏幕。
4. `04-signal.svg`：播放与弹幕信号图形。

`newbili-icon-master.svg` 是用于 README、宣传和传统 AppIcon 资源的完整矢量母版；`newbili-mark.svg` 使用透明画布，可用于启动页和应用内品牌标记。

启动标记不含任何矩形背景；系统遮罩、投影和材质高光由 Icon Composer 针对 Default、Dark、Mono 外观统一配置。
