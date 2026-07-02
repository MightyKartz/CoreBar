# UsageBar

[中文说明](README.zh-CN.md)

UsageBar is a small native macOS menu bar monitor for CPU, memory, and disk usage. It keeps the menu bar quiet: three compact labels, three thin usage bars, no large percentages until you click.

![UsageBar menu bar preview](docs/images/menu-bar-preview.svg)

## Highlights

- Native macOS menu bar app built with Swift, SwiftUI, and AppKit.
- One compact status item for CPU, memory, and disk.
- Click the menu bar item to see exact used, free, and total values.
- 60 second mini history sparklines in the popover.
- Automatic English or Chinese UI based on the system language.
- Local-only sampling. No analytics, account, or network service.

![UsageBar popover preview](docs/images/panel-preview.svg)

## Download

Download the latest macOS build from [GitHub Releases](https://github.com/MightyKartz/usage/releases/latest).

The first release is Developer ID signed, but it is not notarized yet. If macOS blocks the app on first launch, right-click the app and choose **Open**, or build it from source.

## Build From Source

Requirements:

- macOS 14 or later
- Xcode command line tools
- Swift 5.9 or later

Run locally:

```bash
swift test
./script/build_and_run.sh
```

Build a signed local app bundle when a Developer ID identity exists:

```bash
VERSION=0.1.0 CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./script/build_and_run.sh --verify
```

The app bundle is written to `dist/UsageBar.app`.

## Project Description

UsageBar is designed for people who want a quick system health signal without opening Activity Monitor. The menu bar item stays close to native macOS proportions, while the popover gives concrete CPU, memory, and disk details when needed.

## Privacy

UsageBar reads local system statistics only. It does not send data anywhere.
