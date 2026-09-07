# CoreBar 开发指南

适用于整个仓库。这里记录稳定的开发入口与行为约定；用户明确要求调整行为时，同步更新实现、相关测试与本文件。

## 项目定位与代码入口

CoreBar 是轻量的 macOS 菜单栏系统监控应用，使用 SwiftUI 和 AppKit，读取本机 CPU、内存、磁盘和网络统计。保持本地读取、无账号、不收集或上传用户数据的产品与隐私约定。

| 路径 | 职责 |
| --- | --- |
| `Sources/CoreBar/App/CoreBarApp.swift` | 应用入口与生命周期 |
| `Sources/CoreBar/App/AppSettings.swift`、`Sources/CoreBar/App/SettingsView.swift` | 偏好持久化、外观与共享设置界面 |
| `Sources/CoreBar/App/StatusItemController.swift` | 菜单栏项目、面板导航、原生窗口及事件监听 |
| `Sources/CoreBar/Services/` | `SystemSampler` 读取系统数据；`SystemMonitor` 管理定时采样、快照与历史 |
| `Sources/CoreBar/Models/` | 指标、快照及历史数据结构 |
| `Sources/CoreBar/Views/`、`Sources/CoreBar/Support/` | 面板、图表、共享样式、格式化、本地化与健康规则 |
| `Tests/CoreBarTests/` | 单元测试与行为回归测试 |
| `CoreBar/`、`CoreBar.xcodeproj/` | 应用资源、Info.plist、权限与 Xcode 构建配置 |

## 构建与运行

- 最低运行系统为 macOS 14；构建需要 Xcode 26 或更高版本、macOS 26 SDK 及配套 Swift 工具链。使用 `xcode-select -p` 核对选中的开发工具目录。
- Xcode 工程是完整应用资源、版本、签名和沙盒权限的构建入口。SwiftPM 用于快速单测，不能替代完整 `.app` 验证。
- 新增、移动或删除 Swift 源码及测试时，同步维护 `CoreBar.xcodeproj/project.pbxproj` 的文件引用与相应 target 成员。
- 以下命令从仓库根目录执行：

```bash
swift test
swift test --filter SystemSamplerTests
./script/build_and_run.sh --build-only
CONFIGURATION=Release ./script/build_and_run.sh --build-only
```

`--filter` 按改动范围选择测试类。脚本默认生成 `dist/CoreBar.app`，使用 Debug 配置和 ad hoc 本地签名；`--build-only` 不停止或启动应用，但会替换目标目录中的构建产物。

需要运行或检查启动时使用：

```bash
./script/build_and_run.sh
CONFIGURATION=Release ./script/build_and_run.sh --verify
```

这两个命令会在构建及签名验证成功后停止同名 CoreBar 进程，再替换并启动产物。`--verify` 只检查启动后的进程存在，不代表完成 UI 或采样正确性验收。更改 `DIST_DIR` 会改变实际替换位置。

签名与构建覆盖参数见 [README.md](README.md#build-from-source)。Developer ID 签名构建不等于 Apple 公证或发布 GitHub Release。保持“先构建并验证，再替换”的顺序，以及构建失败保留旧应用的行为。

## 状态与采样约定

- `AppSettings` 管理偏好，`SystemMonitor` 管理发布的快照和历史，`SystemSampler` 管理系统计数基线。登录启动状态以 `SMAppService` 为准，页面由导航模型管理。保留当前主线程串行状态更新，避免在视图中建立第二套采样或偏好状态。
- 保持现有 UserDefaults 键、枚举存储值及应用 bundle identifier 的升级兼容性。例如界面显示“卡片”，持久化值仍为 `controlCenter`。
- CPU、内存、磁盘中至少保留一项菜单栏指标；网络仅显示在面板。设置页需要解释最后一个菜单栏指标不能关闭的原因。
- 刷新间隔使用发布事件携带的新值；重复值不重建 Timer，失效 Timer 的排队回调不能追加样本。采样 Timer 保持在主 RunLoop 的 common modes。
- `@Published` 在属性存储更新前发布。直接消费新值时使用事件载荷；需要读取整份设置刷新 UI 时，等属性更新后再执行，避免旧值驱动窗口尺寸或外观。
- 打开或切换面板复用当前快照，不额外触发差分采样。历史表示最近 30 次采样，时间跨度随刷新间隔变化。
- CPU 差分需处理各个 32 位累计计数回绕。内存百分比是本地压力估算，已用容量单独展示，不能宣称与活动监视器压力信号一致；避免重复计算 speculative 页面。
- 网络使用每个接口的 64 位字节计数与独立基线，处理接口加入、移除、计数重置和读取失败恢复；统计包含启用的非回环虚拟接口。网络时间差及磁盘缓存使用单调时钟。
- 整体健康状态包含隐藏的 CPU、内存压力和磁盘指标。隐藏告警来源必须有文字提示，关闭阈值颜色不应隐藏告警含义。

## UI 与交互约定

- 经典、卡片及独立设置入口复用设置组件。设置按钮、开关和分段选择器使用 macOS 原生样式及中性色；设置中的色调作用域不能覆盖概览指标的语义颜色。
- 浅色模式的面板与设置内容背景保持不透明；深色保留系统材质，减少透明度或增强对比度时回退为实色。不要将内容背景不透明等同于圆角承载窗口的 `isOpaque = true`；保留减少动态效果及不依赖颜色区分的适配。
- macOS 26 API 使用可用性判断，保留 macOS 14 的运行回退。
- 经典和卡片面板内的设置可通过“返回用量”和 `⌘[` 返回概览；面板设置中点击菜单栏同样返回概览，概览中再次点击则关闭。Escape 应能关闭面板。
- 页面及可见指标变更时同步原生窗口尺寸，返回概览保持顶部锚点，避免设置页错误套用概览高度。尺寸与颜色优先复用 `DesignTokens`，不在多处复制常量。
- 用户文案集中在 `AppText`，同步中英文；数字与单位应完整可读，长错误信息可完整查看，紧凑表单按需滚动。网络主数值明确为收发合计，趋势图说明最近采样数量及网络自动缩放。
- 内存指标标题统一为“内存 / Memory”；标题简化不改变百分比的压力估算含义，相关说明应保持准确。
- 面板事件监听避免强引用循环，关闭及控制器释放时清理监听和窗口。
- 应用图标保持正方形、满版、不透明、外缘直角；原图位于 `output/imagegen/corebar-icon-v2.png`，应用尺寸资源位于 `CoreBar/Assets.xcassets/AppIcon.appiconset/`。更新时检查所有资源槽位与小尺寸辨识度；菜单栏动态图标由 `StatusIconRenderer` 独立绘制。

## 按改动范围验证

- 采样、定时器、偏好或计算逻辑变更：运行相关测试；跨模块变更再运行完整 `swift test`。为修复补充能复现问题的行为回归测试，避免只重复实现细节。
- 测试偏好使用独立 `UserDefaults` suite 并清理；无需应用外观时使用 `AppSettings(defaults: ..., appliesSystemAppearance: false)`。UI 验证使用独立测试偏好，避免污染日常设置及登录启动项。
- 应用源码、资源或工程配置变更：完成相应 Xcode 应用构建。涉及发布配置、签名或构建脚本时验证 Release 产物；SwiftPM 测试通过不能证明资源或权限正确。
- UI 变更按影响范围检查经典与卡片、中英文、深浅色、指标数量变化、长数值、返回操作和 Escape；检查相关辅助功能名称、状态与回退。
- 纯文档变更核对路径、命令和事实，并运行 `git diff --check`，无需重新构建应用。交付时区分已执行验证、历史证据和尚未覆盖的环境。

## 文档与交付

- 用户可见行为或构建方式变化时同步 `README.md` 与 `README.zh-CN.md`；隐私行为变化时检查 `PRIVACY.md`。
- 历史测试结果、性能测量与验证局限保留在 [docs/maintenance-validation.md](docs/maintenance-validation.md)。不要把固定测试数量、本机性能数字、临时路径或个人签名信息复制到本指南。
- 提交只包含任务相关文件与必要资产；不提交 `.build/`、`dist/`、`release/`、临时截图、日志或测试应用。保留已有用户改动，不用丢弃文件的方式清理工作树。
