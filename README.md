# MemBar

![macOS](https://img.shields.io/badge/macOS-15+-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![License](https://img.shields.io/badge/license-MIT-green)
[![Release](https://img.shields.io/badge/download-latest-brightgreen)](https://github.com/d8dzmf5mfn/MemBar/releases/latest)

**A lightweight macOS menu bar system monitor.** A pixel-art pufferfish in the menu bar swells as memory fills — the fish IS the gauge. Click it for a compact popover with CPU, network, and thermal readings.

轻量级 macOS 菜单栏系统监控工具。菜单栏的像素风河豚随内存占用膨胀——鱼就是仪表盘。点击展开弹窗查看 CPU / 网络 / 温度。

---

## Screenshots / 截图

| Memory gauge (pufferfish) | Popover |
| :---: | :---: |
| A 24×16 pixel-art pufferfish with 4 stages: streamlined (0-30%), plump (30-60%), spiky warning (60-85%), and full-spike panic (85%+). Corner spikes throb on Stage 4. | Compact popover with memory mode / network mode / CPU / temperature readouts. |

---

## Features / 功能

### 📊 Menu Bar / 菜单栏
- **Pufferfish memory gauge** — a pixel-art pufferfish that swells across 4 stages as memory fills:
  - **0-30%** — streamlined "content mochi" with a single dot eye
  - **30-60%** — plumper "curious balloon" with an open mouth
  - **60-85%** — round + 4 spikes, flat eye "mildly flustered"
  - **85-100%** — full spikes + vertical panic eye + gaping mouth "maximum chonk"
- **Stage 4 corner spikes throb** every heartbeat (0.5s) — the fish is under pressure
- **Template-mode rendering** — the pufferfish picks up your system accent color automatically
- **Auto-tinting** with system appearance (light/dark mode)

### 🖱️ Popover / 弹窗
Click the pufferfish to open a compact popover:
- **Memory panel** — used / total bytes readout with a donut gauge
- **Network panel** — real-time download/upload speeds with history chart
- 4-row data table: **内存 / CPU / 网络 / 温度**
- **Color picker** — choose the pufferfish's accent color
- "退出" button to quit

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

1. Launch MemBar — a pixel-art pufferfish appears in the menu bar (top-right)
2. **Click** the pufferfish to open the popover
3. In the popover, use the **Picker** to switch between Memory and Network modes
4. Use the **color picker** to customize the pufferfish's accent color
5. **Right-click** the pufferfish for a "Quit MemBar" menu

The pufferfish auto-tints with your system's light/dark appearance. Enable macOS **Auto Dark Mode** (System Settings → Appearance → Auto) to make it follow the time of day automatically.

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
│   ├── MemBarApp.swift              # @main App, MenuBarExtra, NSStatusItem
│   ├── Models/
│   │   └── MetricsData.swift        # CPUSnapshot / MemorySnapshot / NetworkSnapshot / ThermalSnapshot
│   ├── MonitorEngine/
│   │   ├── CPUInfo.swift            # CPU usage via host_statistics
│   │   ├── MemoryInfo.swift         # Memory via vm_statistics64
│   │   ├── NetworkInfo.swift        # Network throughput via getifaddrs
│   │   ├── SystemMonitor.swift      # @MainActor @Observable, 2Hz refresh
│   │   └── TemperatureInfo.swift    # Battery temp via IORegistry
│   ├── Views/
│   │   ├── MenuBarView.swift        # NSPopover root: Picker + 4-row data
│   │   ├── PixelPufferfishView.swift # SwiftUI view rendering the pufferfish to NSImage
│   │   ├── PufferfishSprite.swift   # Pixel matrices + CGContext renderer for all 4 stages
│   │   ├── PufferfishPanel.swift    # Color picker panel
│   │   ├── PixelWhaleView.swift     # Legacy whale view (reserved)
│   │   └── WhaleSprite.swift        # Whale constants
│   ├── Assets.xcassets/             # AppIcon, AccentColor
│   └── Fonts/                       # Caveat-Regular, RockSalt-Regular (reserved)
├── scripts/
│   └── build-dmg.sh                 # DMG packaging script
└── MemBar.dmg                       # Pre-built disk image
```

~1,700 lines of Swift, all native, no third-party dependencies.

---

## Tech stack / 技术栈

- **Swift 6** with strict concurrency
- **SwiftUI** for the popover + menu bar icon (`MenuBarExtra`)
- **Core Graphics** for pixel-art rasterization (`CGContext`, hand-crafted 24×16 pixel matrices)
- **macOS 15+** native APIs: `host_statistics`, `vm_statistics64`, `getifaddrs`, `IORegistry`

---

## License

MIT
