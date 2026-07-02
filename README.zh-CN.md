# CoreBar

[English README](README.md)

CoreBar 是一个安静的 macOS 菜单栏用量监控工具，用来查看 CPU、内存和磁盘状态。它在菜单栏里保持紧凑，适合长期放在后台运行，点击后再显示具体数字。

![CoreBar 菜单栏预览](docs/images/menu-bar-preview.svg)

## 显示内容

- 在一个原生菜单栏项目里显示 CPU、内存和磁盘用量。
- 小字标签搭配细横条，自动适配浅色和深色模式。
- 点击后打开磨砂玻璃风格面板，显示已用、剩余和总量。
- 每组指标都有 60 秒 mini history sparkline，方便快速看趋势。
- 自动根据系统语言显示中文或英文。
- 只读取本机系统状态，不需要账号，不做追踪，不连接云服务。

![CoreBar 弹出面板预览](docs/images/panel-preview.svg)

## 为什么做 CoreBar

CoreBar 面向只想快速判断系统状态、但不想频繁打开活动监视器的用户。它足够轻，可以一直留在菜单栏；需要细节时，再点开查看。

## 下载

从 [GitHub Releases](https://github.com/MightyKartz/CoreBar/releases/latest) 下载最新 macOS 构建。

发布构建已使用 Developer ID 签名，但暂未做 Apple notarization 公证。如果 macOS 首次启动时拦截，可以右键点击应用并选择 **打开**，或者从源码自行构建。

## 从源码构建

要求：

- macOS 14 或更高版本
- Xcode Command Line Tools
- Swift 5.9 或更高版本

本地运行：

```bash
swift test
./script/build_and_run.sh
```

如果本机有 Developer ID 证书，可以构建签名版：

```bash
VERSION=0.1.4 CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./script/build_and_run.sh --verify
```

应用会生成在 `dist/CoreBar.app`。

## 隐私

CoreBar 只读取本机系统统计信息，不会把数据发送到任何地方。
