# CoreBar 维护与验证记录

日期：2026-09-05。范围：完善现有行为，不新增产品功能。

## 修复与行为约定

- 刷新间隔直接采用 `@Published` 发出的新值；设置保存、运行中的 Timer 和重新启动后的 Timer 使用相同间隔。重复设置不重建 Timer，失效 Timer 的排队回调不会追加采样。
- 采样在主 RunLoop 的 common modes 运行。打开面板复用当前快照，避免额外的短间隔 CPU/网络差分和历史采样。
- CPU 按各个 32 位累计状态计算回绕增量。内存不再重复计入 speculative 页面，页面数在求和前转换为 64 位。
- 内存百分比保留原来的本地压力估算，明确标为“内存压力”；已用容量单独展示，不宣称与活动监视器的压力信号一致。
- 网络从 `NET_RT_IFLIST2` 读取 64 位字节计数，按接口维护基线，处理接口加入、移除、计数重置及读取失败恢复。仍包含已启用的虚拟接口。
- 网络速率和磁盘缓存使用单调时钟，不受系统日期调整影响。历史仍保留最近 30 次采样；CPU、网络显示趋势，内存、磁盘显示进度条。
- 中英文按系统首选语言顺序选择。原生设置控件提供名称及选中状态；长登录启动错误在有限高度内可滚动查看。
- 浮动面板可以成为 key window；事件监听弱引用面板，关闭及控制器释放时清理窗口和监听。
- `AppSettings` 和设置视图从服务及应用入口中拆出，保持原有偏好键兼容。

## 构建与发布

Xcode 工程统一管理应用资源、版本、Info.plist 和沙盒权限；SwiftPM 用于快速单测。脚本从任意工作目录调用，并在构建和签名验证成功后替换产物。构建失败保留旧应用。

已验证 Debug、Release、默认版本 `1.0 (2)` 以及显式版本覆盖。两种构建均包含图标和 arm64/x86_64 可执行代码；Release 本地签名的实际权限仅包含 App Sandbox，没有调试权限。

```bash
swift test
./script/build_and_run.sh --build-only
CONFIGURATION=Release ./script/build_and_run.sh --verify
```

本次未使用 Developer ID 证书签名、提交公证或发布线上版本。构建工具链为 Xcode 26.6；macOS 14 的兼容分支未在另一台旧系统上运行验收。

## 验证结果

- 最终单元测试：56 个通过，0 失败；覆盖新增的定时器切换/释放、旧回调丢弃、语言顺序、CPU 回绕、内存去重、网络超过 4 GiB、接口变化、读取恢复和墙钟跳变。
- Xcode 的测试构建通过；Debug/Release 应用构建及本地签名检查通过；Release 应用启动并持续运行。
- 使用相同沙盒权限的临时采样程序成功读取 16 个启用接口，并产生非零上下行速度。该程序复用生产采样源码。
- 临时常规窗口复用生产视图和 `StatusItemController`，使用独立偏好，不改变用户设置。实际检查了深浅色设置布局、长错误滚动至末尾、原生面板的 Escape 关闭、控制器释放以及设置辅助功能树中的名称和选中状态。未开启系统 VoiceOver 做完整听读测试。
- 优化编译的采样基准：磁盘缓存命中时 500 次采样中位约 0.040 ms，P95 约 0.046 ms；三次沙盒实时采样约 0.4–0.7 ms。未观察到需要迁移到后台线程的采样阻塞，因此保留串行主线程状态更新。
- 最终 Release 应用在面板关闭时观测 20 秒：CPU 时间增加 1.31 ms（平均约 0.007%），物理内存占用保持约 16.38 MiB；中断唤醒增加 54 次。临时验证窗口已关闭，额外生成的 Xcode 构建缓存已清理。

这些性能数字是本机短时测量，不能替代长期驻留或不同硬件上的性能测试。

## 后续外观调整

按用户提供的设置页参考，所有设置入口保留原生 Toggle 和分段 Picker，并统一为中性色控件；概览指标的语义颜色保持原有规则。浅色模式的经典面板、系统默认面板和独立设置窗口均改用不透明的系统背景，深色继续使用系统材质。

已用生产视图叠在红/青棋盘背景上验证两种风格的浅色概览、浅色设置页及独立设置窗口均不透底，并检查深色设置控件。56 个现有测试再次通过，Release 已重新构建并启动。

## UI/UX 完善（2026-09-05）

- 经典与卡片设置页都提供原生“返回用量”按钮及 `⌘[` 快捷键。从设置点菜单栏同样返回概览；再次点概览才关闭。浮动面板补上 AppKit `cancelOperation`，让 Escape 不依赖 SwiftUI 当前焦点。
- 卡片概览按行数定高：一至两项为 288 pt，三至四项为 458 pt；设置固定 452 pt。卡片保持 160 pt 行高，经典行留出 96 pt 显示两行容量或网络速率。页面发布事件会同步更新原生窗口，设置变更不会把设置页缩成概览尺寸。
- 整体健康状态继续包含隐藏指标。异常来源未显示时，状态胶囊补充“未显示 / Hidden”，并提供汇总范围的悬停与辅助功能说明；关闭阈值颜色不影响这条说明。
- 磁盘剩余容量与总容量分行，内存已用容量与总容量分行；经典网络分别显示完整下载、上传速率，避免单位断行。网络主数值标明收发合计，趋势图说明最近 30 次采样及网络自动缩放。
- 设置中的“至少保留一项菜单栏指标”说明占固定高度，最后一个开关禁用时仍能看到原因。“跟随系统”和“卡片”区分外观与布局含义，原有偏好键和 `controlCenter` 存储值保持兼容。

验证使用两套独立偏好的临时应用，复用生产视图及 `StatusItemController`：普通预览读取真实采样；英文边界预览使用明确的固定数据（内存压力 96%、120/128 GB、磁盘 960 GB 空闲/2 TB、上下行各约 123.5 MB/s）。没有改变日常应用的显示、语言或登录启动设置。

已检查中英文设置、深浅色原生控件、卡片一至四项组合、经典列表、两种设置风格双向迁移、返回按钮及 `⌘[`、卡片概览/设置与经典弹层的 Escape 关闭。单卡返回保持同一个原生窗口，上边缘均为屏幕 y=36；改变菜单栏指标数量后横向位置随菜单栏图标锚点更新。隐藏告警来源在关闭阈值颜色后仍有文字，重新显示来源后标记消失。

本轮的尺寸回归测试覆盖一/两行概览、独立设置高度及设置中隐藏指标后返回。尚未做完整 VoiceOver 听读、不同系统键盘导航偏好及多屏缩放矩阵；上述检查不代表全面无障碍认证。

最终 `swift test` 通过全部 56 项；`CONFIGURATION=Release ./script/build_and_run.sh --verify` 完成签名校验、Release 构建和启动验证。英文经典列表在最后调整后重新运行检查，上下行数值和单位均保持完整。临时测试应用已退出并清理各自的测试偏好。

## 精密指标图形与详情（2026-10-14）

概览共用 1.75 pt 趋势线，经典/卡片容量条分别为 3/4 pt，带低对比度主刻度和磁盘阈值标记。内存主百分比明确为压力估算，容量条独立按已用/总容量计算；容量条不采用压力告警配色。提高容量、速率和更新时间文字的可读性。点击栏目或原生箭头进入 CPU、内存、磁盘或网络详情，可通过返回按钮、`⌘[` 返回概览。

历史新增同次采样时间戳与上下行序列，均沿用最近 30 次采样窗口；详情显示真实时间跨度和近期均值/峰值。网络上下行共用尺度，上传始终为虚线；关闭阈值颜色仍保留线型区分。绘图区支持悬停、方向键及辅助功能增减检视，选中采样按时间戳保持，退出历史窗口后清除选择。导航不触发额外采样。

验证结果与范围：

- `swift test`：61 项通过。回归覆盖容量与压力不同、缺失容量、时间戳及网络序列同窗裁剪、上下行与合计对齐、零历史窗口、不等间距时间映射、详情尺寸独立与返回当前布局。
- `CONFIGURATION=Release ./script/build_and_run.sh --build-only`：完成 Xcode Release 构建与严格签名验证，未替换或启动已安装应用。
- 用户要求后台测试前，独立偏好及固定样本的临时验证应用检查了中文经典/卡片深色概览、内存与网络详情、设置中切换布局、辅助功能增减、Tab＋方向键检视与 `⌘[` 返回；单独的窗口截图不完整保留玻璃的背后混合，另取得了经典概览的桌面区域截图。临时应用已退出、测试偏好已清理。
- 用户要求后台测试后，使用隐藏窗口中的生产视图完成中英文、经典/卡片、深浅色、四种详情的离屏渲染。每次渲染均检查窗口不可见。检查了 120/128 GB 内存、960 GB/2 TB 磁盘和上下行各 123.5 MB/s 的长数值及单位；这些是布局测试样本。普通 `ImageRenderer` 无法完整绘出滚动内容，其空白结果已弃用，改用隐藏 `NSHostingView` 原生缓存绘制。
- 离屏验证使用实色背景检查内容布局，不模拟原生玻璃合成。未进行最终玻璃多背景对比、真实鼠标悬停、Escape/菜单栏重复点击的本轮完整复测、VoiceOver 听读、多屏或 macOS 14–26 实机验收；这些交互的实现与回退另经代码检查。无障碍树和键盘检查不代表完整无障碍认证。

## 面板圆角外黑边修复（2026-09-26）

macOS 26 及以上的概览与设置共用透明浮动窗口。移除这一路径的 AppKit 窗口阴影，避免它在原生玻璃圆角外形成深色轮廓；macOS 14–15 的窗口阴影与经典 NSPopover 行为保持不变。`swift test` 的 57 项测试通过；Debug 与 Release 应用构建、签名验证及 `git diff --check` 均通过。未取得修复后面板的可视截图，因此深浅色与不同背景下的边缘效果仍需实机目视确认。

## 统一深色系统玻璃表面（2026-09-15）

macOS 26 及以上的经典布局改用与卡片布局相同的透明浮动窗口，避免在 NSPopover 自带材质上叠加第二层玻璃。经典仍是连续列表，设置和概览在同一窗口内切换；macOS 14–15 的经典 NSPopover 路径保留。浮动窗口按当前布局和页面计算高度，设置中切换布局不会改变设置页的高度。

深色使用单层原生 `.regular` 玻璃，由系统绘制折射和边缘高光；移除其上的额外描边及 SwiftUI 外部阴影，改由 AppKit 窗口负责外部阴影，并在窗口尺寸变化后刷新阴影。浅色、减少透明度和增强对比度继续优先走实色分支，实色及旧材质分支保留边界线。设置按钮和开关仍使用原生中性色样式。

验证结果：

- `swift test`：57 项通过，0 失败。新增回归覆盖设置中切换经典/卡片、返回对应概览及隐藏指标后的尺寸选择。
- `CONFIGURATION=Release ./script/build_and_run.sh --build-only` 成功，完整 `.app` 的严格签名校验通过。
- 运行环境为 macOS 27.0（26A428），构建工具为 Xcode 26.6 / macOS 26.5 SDK。独立临时应用复用生产视图和 `StatusItemController`，注入固定快照及独立 UserDefaults suite，没有替换已安装应用或改变日常偏好。
- 中文检查了经典与卡片深色概览、设置中双向切换布局、返回按钮、`⌘[`、Escape，以及经典从四项缩为一项后的高度和隐藏告警提示。浅色经典概览与设置背景保持实色，最后一项菜单栏指标的开关保持禁用并显示原因。
- 共享生产表面在白色、深色和彩色棋盘测试背景中检查。窗口单独截图不能完整保留背后窗口的混合效果，因此也检查了同一背景窗口内的生产视图；该检查不等同于多窗口、多屏幕环境的完整材质验收。
- 英文经典概览检查了 120/128 GB 内存、960 GB/2 TB 磁盘及上下行各 123.5 MB/s 的固定边界数据，文字与单位完整显示。这些数值仅用于布局验证，不代表实际系统读数。

英文概览验证后主机锁屏，未继续英文设置、菜单栏重复点击及点击外部关闭的本轮手动复测。未切换系统级减少透明度或增强对比度设置，也未做完整 VoiceOver、多屏或 macOS 14–26 实机验证；这些回退目前依据代码检查及已有测试，不宣称已完成实际系统验收。临时验证进程与测试偏好在检查后清理。

### 2026-10-14 — External volumes and hidden detail scroll indicators

- Detail scroll indicators are hidden without disabling scrolling. Disk details list mounted local external volumes and each partition separately, with names, mount paths and independent capacity bars. Missing capacity remains unavailable rather than zero usage.
- Volume metadata shares the 60-second disk cache. Workspace mount, unmount and rename notifications invalidate it for the next regular sample; navigation does not sample. Overview history and overall alerts retain their home-volume scope.
- `swift test`: 63 tests passed, including injected external-volume cache, removal, rename and missing/invalid capacity cases. Release Xcode build and strict signature verification passed.
- A background-only probe signed with the app's existing sandbox entitlement enumerated the attached external `Untitled` volume and read its capacity without additional entitlements. No file contents were read. Physical reconnect/rename notifications were not manually exercised.
- Hidden-window rendering covered classic/cards, light/dark and Chinese/English, using external-volume fixtures. All windows remained unshown. Solid offscreen captures do not establish native glass compositing, real pointer scrolling or complete VoiceOver behavior.

### 2026-10-14 — Capacity-first disk detail layout

- Disk details now show the home volume name above the main percentage, then home/external capacity information, followed by a 64-point home-volume history chart (other detail charts remain 130 points). Name metadata shares the existing disk cache and falls back to localized home-volume wording when unavailable.
- `swift test`: 64 tests passed, including home-volume name propagation, cache reuse and invalidation. Release Xcode build passed. Hidden-window classic/cards, Chinese/English and light/dark renders passed; the inspected default-size disk view showed the main volume and first external volume capacities before the fold. No test window was shown.
- These captures validate solid content layout, not native glass blending or real pointer interaction. External volumes still have independent current capacity values; the historical chart continues to represent only the home volume.

### 2026-10-14 — Sample inspection correctness and update cost

- Pointer selection now writes SwiftUI state only when its nearest sample timestamp changes. Mouse and keyboard selections are separate; keyboard movement clears pointer priority, leaving the plot preserves keyboard inspection, losing keyboard focus clears it, and evicted dates are removed. No timer or additional system sampling was introduced.
- Inspection uses semantic labels for CPU usage, estimated memory pressure, home-volume capacity and combined traffic. Network details retain separate download/upload lines. Single-sample plots show inspectable points; missing or misaligned timestamp/value series do not fabricate hints.
- Hint space is reserved within chart layout, with horizontal edge clamping. Overview hints have two lines, network detail hints three. Classic row minimum is 128 points and card minimum 188 points; plot line/bar widths and data scale are retained. Light/reduced-transparency/increased-contrast callout backgrounds are solid; normal dark callouts use system material.
- `swift test`: 66 tests passed, including single-sample geometry, nearest actual timestamp at plot edges and throughout one sample's hit region, accurate pressure/combined labels, and paired network values. Release Xcode build, strict signature verification and diff whitespace checks passed.
- Background hidden-window renders covered classic/cards, Chinese/English and light/dark. Selected-hint captures used a temporary source copy differing only in initial keyboard selection and a deterministic fixture clock; this establishes displayed layout rather than real pointer/focus behavior. Inspected captures showed readable compact hints and multi-line network hints within their reserved space.
- Real pointer interaction, full VoiceOver behavior, native glass compositing and hover CPU/GPU increments were not measured. The earlier background CPU observation is not a before/after hover benchmark.

### 2026-10-14 — Plain-text inspection hints

- Per user request, visual inspection hints now show only metric labels and values; the timestamp row, fill/material background and padding are removed. Network detail upload/download remain separate lines. Real timestamps continue to locate samples and describe them for accessibility.
- Reserved hint slots shrink to 16 points in overview and 32 in details; classic rows and cards use 116/176-point minimums. Plot heights and selection logic are unchanged.
- 66 unit tests, Release application build, strict signature verification and whitespace checks passed. Hidden-window selected-hint renders covered classic/cards, English/Chinese and light/dark; the inspected card overview displayed only text, without hint time or background. Selection was seeded in a temporary source copy as described above; no real pointer or glass compositing verification was performed and no test window was shown.

### 2026-10-14 — Numeric overview value columns

- Overview primary value columns now show numbers and units only. Classic memory's pressure caption moves below the title on the left; classic network identifies combined traffic in the left title. Card network's combined caption moves below its left title. Pressure calculations, capacity bars and sampling behavior are unchanged.
- Release application build, strict signature verification and diff whitespace checks passed. Hidden-window rendering covered classic/cards, Chinese/English and light/dark with long capacity/rate fixtures. Inspected classic dark Chinese and card light English captures retained readable numeric values and left-aligned semantic descriptions. No test window was shown; native glass blending and pointer interactions were not exercised.
- This is a text/layout change; unit tests were not rerun. The preceding 66-test result remains historical evidence, not a new test run for this revision.

### 2026-10-14 — Shared native icon-only back button

- Details and embedded settings now share a native borderless icon-only `chevron.backward` button at the top left, with a 28-point label hit area, localized Back to Usage tooltip/accessibility name and Command-[ shortcut. The settings title moves to the right to match detail headers. Navigation actions are reused unchanged.
- Release application build, strict signature verification and whitespace checks passed. Hidden-window rendering covered classic/cards, English/Chinese and light/dark detail/settings pages. Inspected Chinese dark network details and English light card settings show only the arrow at the left, with titles at the right. No test window was displayed.
- This is a shared control/layout change; unit tests were not rerun. Real clicks, keyboard shortcuts, VoiceOver and native glass compositing were not exercised in this round; prior validation records are not new evidence for this revision.

### 2026-10-14 — Left-aligned title as return target

- Detail and embedded settings headers now use one left-aligned title with a small back chevron, replacing the separate back icon/right-aligned title arrangement. Clicking the whole title invokes the existing overview action. Back to Usage help, a page-specific accessibility name and Command-[ remain.
- Release build, strict signature verification and whitespace checks passed. Hidden-window renders covered classic/cards, Chinese/English and light/dark detail/settings pages. The inspected Chinese dark network header shows the unified title at the left and an empty right side. Test windows remained unshown.
- Unit tests were not rerun for this control/layout-only change. Real clicking/shortcuts, full VoiceOver and native glass compositing were not exercised in this round.

### 2026-10-14 — Overview without settings icon

- The shared overview header no longer displays the gear button. Removed the unused settings callback chain from overview/header components; the status-item context menu still provides Settings. Header size and metric navigation are unchanged.
- Release application build, strict signature verification and whitespace checks passed. Hidden-window classic/cards, Chinese/English and light/dark renders completed; the inspected classic dark overview had an empty top-right header area. No test window was displayed.
- This is a reversible header/control removal; unit tests were not rerun. The context-menu action was checked in source, not exercised in the foreground. Native glass compositing, real pointer and full accessibility behavior were not verified in this round.
