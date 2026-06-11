# MemBar

![macOS](https://img.shields.io/badge/macOS-15+-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![License](https://img.shields.io/badge/license-MIT-green)
[![Release](https://img.shields.io/badge/download-latest-brightgreen)](https://github.com/d8dzmf5mfn/MemBar/releases/latest)

**A lightweight macOS menu bar system monitor.** Real-time CPU, memory, network, and temperature — right in your menu bar.

轻量级 macOS 菜单栏系统监控工具。实时查看 CPU、内存、网速、温度，一目了然。

![MemBar](https://github.com/user-attachments/assets/38a3d01c-5e62-4835-ae95-4cb1bd450c7e)

---

## Features / 功能

### 📊 Menu Bar / 菜单栏

| Mode | Display |
|------|---------|
| **Memory** | Used memory (e.g. `8.2GB/16.0GB`) |
| **Network** | Real-time download speed (e.g. `1.2MB/s`) |
| **Temperature** | Thermometer icon + CPU thermal state (🟢正常 🟡温热 🔴较热) + battery temp |

### 🖱️ Dropdown Menu / 下拉菜单

Quick glance at key metrics:
- **Memory**: usage percentage + used bytes
- **Network**: instant download/upload speed, toggle smooth mode
- **Temperature**: thermal state + battery temperature in °C
- **Mode switcher**: toggle between memory/network display
- **Full window**: open the detailed monitoring window

### 🖥️ Full App Window / 完整应用窗口

NavigationSplitView with three modules:

#### CPU
- Xcode-style gauge with overall usage
- Donut chart: user / system / idle breakdown
- Per-core utilization bar chart
- Active process list (top CPU consumers)
- 60-point usage history chart

#### Memory
- Donut chart: used / wired / compressed / free
- Detailed breakdown with colored DataRows
- 60-point usage history chart

#### Network
- Download / upload speed cards (large display)
- Real-time ↔ Smooth mode toggle
- 60-point history chart for both directions

### 🎨 Design
- Paper texture background
- Custom handwritten fonts (Caveat, RockSalt)
- Torn edge card effects
- Dark/Light mode adaptive colors
- 2-second auto-refresh

---

## Installation / 安装

### Download / 下载

[**Download MemBar.dmg**](https://github.com/d8dzmf5mfn/MemBar/releases/download/v1.0.0/MemBar.dmg) (667 KB)

Or visit the [Releases page](https://github.com/d8dzmf5mfn/MemBar/releases).

### How to install / 安装步骤

1. Download `MemBar.dmg`
2. Open the DMG file
3. Drag **MemBar.app** into the **Applications** folder
4. Launch MemBar from Applications

> **Note**: On first launch, macOS may show an unidentified developer warning. Right-click MemBar.app in Applications and select "Open" to bypass.

> **注意**: 首次打开可能提示未识别的开发者，请在访达中右键点击 MemBar.app → 打开。

---

## Usage / 使用

1. Launch MemBar — it lives in the menu bar (top-right)
2. Click the menu bar item to see the dropdown
3. Click "打开完整窗口" to open the full app view
4. In the menu bar dropdown, you can switch between **Memory** and **Network** display modes

---

## Build / 构建

```bash
# Requires Xcode 15+ / macOS 15+
git clone https://github.com/d8dzmf5mfn/MemBar.git
cd MemBar/Monitor
open Monitor.xcodeproj
# Select target "Monitor" → Build & Run (⌘R)
```

---

## Tech Stack / 技术栈

- **Swift 6** with strict concurrency
- **SwiftUI** (MenuBarExtra, NavigationSplitView, Charts)
- **macOS 15+** native APIs (`host_statistics`, `proc_listpids`, `ioreg`, `task_info`)
- **No third-party dependencies**

---

## License

MIT
