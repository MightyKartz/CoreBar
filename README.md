# CoreBar

[中文说明](README.zh-CN.md)

CoreBar is a quiet macOS menu bar monitor for CPU, memory, and disk usage. It stays compact in the menu bar, keeps its background presence light, and shows exact numbers only when you click.

![CoreBar menu bar preview](docs/images/menu-bar-preview.svg)

## What It Shows

- CPU, memory, and disk usage in one native menu bar item.
- Compact labels with slim usage bars, tuned for light and dark mode.
- A glass-style popover with exact used, free, and total values.
- 60-second mini history sparklines for quick trend checks.
- Automatic English or Chinese UI based on your system language.
- Local-only system readings. No account, tracking, or cloud service.

![CoreBar popover preview](docs/images/panel-preview.svg)

## Why CoreBar

CoreBar is for people who want a quick system signal without opening Activity Monitor. It is small enough to leave running all day, with the detail hidden until you need it.

## Download

Download the latest macOS build from [GitHub Releases](https://github.com/MightyKartz/CoreBar/releases/latest).

Release builds are Developer ID signed, but they are not notarized yet. If macOS blocks the app on first launch, right-click the app and choose **Open**, or build it from source.

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
VERSION=0.1.4 CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./script/build_and_run.sh --verify
```

The app bundle is written to `dist/CoreBar.app`.

## Privacy

CoreBar reads local system statistics only. It does not send data anywhere.
