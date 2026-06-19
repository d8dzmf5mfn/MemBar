# MemBar

![macOS](https://img.shields.io/badge/macOS-15+-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![License](https://img.shields.io/badge/license-MIT-green)
[![Release](https://img.shields.io/badge/download-latest-brightgreen)](https://github.com/d8dzmf5mfn/MemBar/releases/latest)

**A lightweight macOS menu bar system monitor.** A donut gauge in the menu bar fills as memory pressure rises. Click it for a popover with a big ring chart, live network throughput, CPU, and battery temperature.

轻量级 macOS 菜单栏系统监控工具。菜单栏小圆环随内存压力填充,点开是带大圆环、实时网速、CPU 和电池温度的弹窗。

---

## Screenshots / 截图

| Menu bar | Popover (memory mode) | Popover (network mode) |
| :---: | :---: | :---: |
| 16-pt donut + percentage (or `↓X ↑Y` in network mode), auto-tinted by system appearance. | 92-pt color-coded ring, end-cap dot that follows the trim, percentage in the center, used/total bytes, status caption. | Two stacked 16-bar rolling charts (download / upload) with the latest bar pulsing between samples. |

---

## Features / 功能

### 📊 Menu bar / 菜单栏
- **Live donut gauge** — 16-pt ring, system-foreground tint via `NSImage.isTemplate = true`, redrawn at 2 Hz.
- **Two display modes**:
  - *memory* — percentage text alongside the ring
  - *network* — `↓1.2MB ↑234KB` download/upload text
- Mode is picked from the popover and persisted to `UserDefaults`.
- Re-renders on appearance change (light ⇄ dark, Auto Dark Mode).

### 🖱️ Popover / 弹窗
Click the menu bar icon to open a 280 × 280 SwiftUI popover:
- **Mode picker** — segmented control at the top: 内存占用 / 网速.
- **Memory mode** — a 92-pt ring with a 10-pt stroke:
  - Color shifts **green → orange → red** at 60 % / 85 %
  - A small **end-cap dot** rides the trim end (`.rotationEffect` driven by the same fraction)
  - The percentage is centered as a 22-pt rounded monospaced number with `.contentTransition(.numericText())` so the digits roll over smoothly
  - A subtle **shadow halo** appears above 85 %
  - Used / total bytes and a `稳定 / 偏高 / 告急` status caption round out the row
  - The whole ring is GPU-rendered via `.drawingGroup()` for retina crispness
- **Network mode** — two stacked rolling-window bar charts (download in blue, upload in green):
  - 16 bars per chart, 2 s per sample, history ≈ 32 s
  - Each bar's height is normalized to the window's max, so spikes always fill the chart
  - The **rightmost (latest) bar** runs a `TimelineView` that nudges its height ±8 % at ~0.88 Hz, so the chart feels alive between samples (no frozen gap)
  - 1-pt baseline rule under each row keeps the eye anchored when traffic is near zero
- **Data table** — 内存 / CPU / 网络 / 温度, with monospaced values and per-row accent color.
- **退出** button to quit.

### ⚙️ Engineering / 实现
- Swift 6 + strict concurrency; `@MainActor @Observable` `SystemMonitor` posts a `systemMonitorDidRefresh` notification on each 2 s tick.
- Native macOS APIs only — no third-party dependencies:
  - `host_statistics` for CPU
  - `vm_statistics64` for memory
  - `getifaddrs` for network throughput (delta between samples)
  - `IORegistry` for battery temperature
- All charts animate via value-driven `.animation(.easeInOut, value:)` modifiers — the popover root does **not** use `.id(refreshCounter)`, so in-flight transitions are never torn down by a forced rebuild.
- ~1,200 lines of Swift.

---

## Installation / 安装

### Download / 下载

[**Download MemBar.dmg**](https://github.com/d8dzmf5mfn/MemBar/releases/latest) from the Releases page.

Or via Homebrew (planned):
```bash
brew install --cask membar
```

### How to install / 安装步骤

1. Download `MemBar.dmg` from the latest release
2. Open the DMG file
3. Drag **MemBar.app** into the **Applications** folder
4. Launch MemBar from Applications — the donut appears in the menu bar

> **Note**: On first launch, macOS may show an unidentified developer warning. Right-click MemBar.app in Applications and select "Open" to bypass.
>
> **注意**: 首次打开可能提示未识别的开发者, 请在访达中右键点击 MemBar.app → 打开。

---

## Usage / 使用

1. Launch MemBar — the donut gauge appears in the menu bar (top-right).
2. **Click** the donut to open the popover.
3. In the popover, use the **picker** to switch between 内存占用 and 网速.
4. The picker choice is remembered between launches.
5. **Right-click** the donut for a "Quit MemBar" menu.

The gauge auto-tints with your system's light / dark appearance. Enable macOS **Auto Dark Mode** (System Settings → Appearance → Auto) to make it follow the time of day automatically.

---

## Build from source / 从源码构建

```bash
# Requires Xcode 27+ and macOS 15+
git clone https://github.com/d8dzmf5mfn/MemBar.git
cd MemBar/Monitor
open Monitor.xcodeproj
# Select target "Monitor" → Build & Run (⌘R)
```

Or from the command line (with Xcode-beta):
```bash
cd MemBar/Monitor
DEVELOPER_DIR="$HOME/Downloads/Xcode-beta.app/Contents/Developer" \
  xcodebuild -project Monitor.xcodeproj -scheme Monitor -configuration Release build
# Built .app will be in DerivedData
```

### Building a DMG locally

```bash
./scripts/build-dmg.sh
# Produces MemBar.dmg in the current directory
```

The build script:
1. Runs `xcodebuild` in Release configuration
2. Locates the built `MemBar.app` in DerivedData
3. Creates a `MemBar.dmg` using `hdiutil` with a drag-to-Applications layout

---

## Project structure / 项目结构

```
Monitor/
├── Monitor.xcodeproj/
├── Monitor/
│   ├── MemBarApp.swift              # @main App, AppDelegate, NSStatusItem,
│   │                               # StatusBarIconView, MenuBarRenderer
│   │                               # (Core Graphics donut for the menu bar)
│   ├── Models/
│   │   └── MetricsData.swift        # CPUSnapshot / MemorySnapshot /
│   │                               # NetworkSnapshot / ThermalSnapshot
│   ├── MonitorEngine/
│   │   ├── CPUInfo.swift            # host_statistics
│   │   ├── MemoryInfo.swift         # vm_statistics64
│   │   ├── NetworkInfo.swift        # getifaddrs
│   │   ├── SystemMonitor.swift      # @MainActor @Observable, 2 Hz refresh,
│   │   │                           # posts .systemMonitorDidRefresh
│   │   └── TemperatureInfo.swift    # IORegistry
│   ├── Views/
│   │   └── MenuBarView.swift        # popover: mode picker, donut + bar
│   │                               # charts, data rows, quit button
│   └── Assets.xcassets/             # AppIcon, AccentColor
└── scripts/
    └── build-dmg.sh                 # DMG packaging script
```

---

## Tech stack / 技术栈

- **Swift 6** with strict concurrency
- **SwiftUI** for the popover (`@Observable` + `Bindable`)
- **AppKit** for `NSStatusItem` + the menu bar renderer (`CGContext` donut rasterized to a template-mode `NSImage`)
- **Core Graphics** for the menu bar pixel rendering
- **macOS 15+** native APIs: `host_statistics`, `vm_statistics64`, `getifaddrs`, `IORegistry`

---

## License

MIT
