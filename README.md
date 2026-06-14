# MemBar

![macOS](https://img.shields.io/badge/macOS-15+-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![License](https://img.shields.io/badge/license-MIT-green)
[![Release](https://img.shields.io/badge/download-latest-brightgreen)](https://github.com/d8dzmf5mfn/MemBar/releases/latest)

**A lightweight macOS menu bar system monitor.** A single donut chart in the menu bar shows memory usage at a glance; click it for a compact popover with CPU, network, and thermal readings.

轻量级 macOS 菜单栏系统监控工具。菜单栏用一个圆环显示内存占用,点击展开弹窗查看 CPU / 网络 / 温度。

---

## Screenshots / 截图

| Memory mode | Network mode |
| :---: | :---: |
| Donut chart grows clockwise from 12 o'clock as memory fills. | 20-bar Energy Impact-style history chart for download (blue) and upload (green). |

---

## Features / 功能

### 📊 Menu Bar / 菜单栏
- **Donut chart** that grows clockwise from 12 o'clock as memory fills (0% = empty, 100% = full ring)
- **Two display modes**, switchable from the popover:
  - **Memory** — donut + percentage (e.g. `57%`)
  - **Network** — donut + speeds (e.g. `↓19KB/s ↑13KB/s`)
- **Auto-tinting** with system appearance (light/dark mode)

### 🖱️ Popover / 弹窗
Click the menu bar icon to open a compact popover:
- **Memory mode** — large 96pt donut + used / total bytes readout
- **Network mode** — 14-bar history chart (Energy Impact style) for download and upload, plus current speed
- 4-row data table: **内存 / CPU / 网络 / 温度**
- "退出" button to quit
- 0.3s animated transitions between values

### ⚙️ System / 系统
- 2-second refresh interval
- Native macOS APIs only — no third-party dependencies
- ~1,200 lines of Swift total

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
4. Launch MemBar from Applications — the donut chart appears in the menu bar

> **Note**: On first launch, macOS may show an unidentified developer warning. Right-click MemBar.app in Applications and select "Open" to bypass.
>
> **注意**: 首次打开可能提示未识别的开发者, 请在访达中右键点击 MemBar.app → 打开。

---

## Usage / 使用

1. Launch MemBar — a donut chart appears in the menu bar (top-right)
2. **Click** the donut to open the popover
3. In the popover, use the **Picker** to switch between Memory mode (donut) and Network mode (bar chart)
4. **Right-click** the donut for a "Quit MemBar" menu

The donut auto-tints with your system's light/dark appearance. Enable macOS **Auto Dark Mode** (System Settings → Appearance → Auto) to make it follow the time of day automatically.

---

## Build from source / 从源码构建

```bash
# Requires Xcode 27+ and macOS 15+
git clone https://github.com/d8dzmf5mfn/MemBar.git
cd MemBar/Monitor
open Monitor.xcodeproj
# Select target "Monitor" → Build & Run (⌘R)
```

Or from the command line:
```bash
cd MemBar/Monitor
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
│   ├── MemBarApp.swift           # NSStatusItem + AppDelegate + MenuBarRenderer
│   ├── Models/
│   │   └── MetricsData.swift     # CPUSnapshot / MemorySnapshot / NetworkSnapshot / ThermalSnapshot
│   ├── MonitorEngine/
│   │   ├── CPUInfo.swift         # CPU usage via host_statistics
│   │   ├── MemoryInfo.swift      # Memory via vm_statistics64
│   │   ├── NetworkInfo.swift     # Network throughput via getifaddrs
│   │   ├── SystemMonitor.swift   # @MainActor @Observable, 2Hz refresh
│   │   └── TemperatureInfo.swift # Battery temp via IORegistry
│   ├── Views/
│   │   └── MenuBarView.swift     # NSPopover root: Picker + donut/bar chart + 4-row data
│   ├── Assets.xcassets/          # AppIcon, AccentColor
│   └── Fonts/                    # Caveat-Regular, RockSalt-Regular (reserved)
└── scripts/
    └── build-dmg.sh              # DMG packaging script
```

~1,200 lines of Swift, all native, no third-party dependencies.

---

## Tech stack / 技术栈

- **Swift 6** with strict concurrency
- **SwiftUI** for the popover
- **AppKit** (`NSStatusItem`, `NSStatusBar`, `NSPopover`, `NSHostingController`)
- **Core Graphics** for rasterizing the menu-bar donut (`CGContext`, `addArc` Y-flip math)
- **CoreText** for the menu-bar label
- **macOS 15+** native APIs: `host_statistics`, `vm_statistics64`, `getifaddrs`, `IORegistry`

---

## License

MIT
