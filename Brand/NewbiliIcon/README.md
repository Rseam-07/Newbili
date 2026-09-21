# Newbili Material 图标源文件

图标以 1024 × 1024 画布设计。连续的 `N` 是 Newbili 的品牌首字母，中间挖出的播放三角表示视频；右上青色圆点是更新与弹幕的轻量提示。造型只使用单一轮廓、负形和 Material 3 色调，不依赖渐变、阴影或拟物细节，因此在 16–48 px 仍能辨认。

## 图层顺序

从后到前导入 Icon Composer：

1. `01-surface.svg`：深紫 Material 容器。
2. `02-n-play.svg`：粉色连续 N 与播放负形。
3. `03-accent.svg`：青色状态点。

`newbili-icon-master.svg` 是启动器、README 和宣传资源的完整矢量母版；`newbili-mark.svg` 使用透明画布与更深的品牌粉，可同时用于浅色和深色启动页；`newbili-icon-monochrome.svg` 用于 Android 主题图标。

系统圆形、方形和圆角方形遮罩由 Android 自适应图标与 Icon Composer 处理，母版自身不使用与系统遮罩竞争的装饰边框。
