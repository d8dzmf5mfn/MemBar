import SwiftUI
import CoreText

@main
struct MemBarApp: App {
    @State private var monitor: SystemMonitor = {
        let m = SystemMonitor()
        m.start()
        return m
    }()
    @State private var windowOpened = false

    init() {
        registerFonts()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(monitor)
        } label: {
            MenuBarLabel(monitor: monitor, windowOpened: $windowOpened)
        }
        .menuBarExtraStyle(.menu)

        WindowGroup("MemBar", id: "main") {
            ContentView()
                .environment(monitor)
        }
        .windowResizability(.contentSize)
    }

    private func registerFonts() {
        let fonts = ["RockSalt-Regular", "Caveat-Regular"]
        for name in fonts {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                print("Font not found: \(name)")
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

struct MenuBarLabel: View {
    let monitor: SystemMonitor
    @Binding var windowOpened: Bool

    private var label: String {
        switch monitor.menuBarMode {
        case .memory:
            String(format: "%.1fGB/%.0fGB",
                   Double(monitor.memory.usedBytes) / 1_073_741_824,
                   Double(monitor.memory.totalBytes) / 1_073_741_824)
        case .network:
            formatSpeed(monitor.displayDownloadSpeed)
        }
    }

    private var tempIcon: String {
        switch monitor.thermal.state {
        case .nominal:  "thermometer"
        case .fair:     "thermometer.medium"
        case .serious:  "thermometer.medium"
        case .critical: "thermometer.high"
        @unknown default: "thermometer"
        }
    }

    private var tempColor: Color {
        switch monitor.thermal.state {
        case .nominal:  .green
        case .fair:     .orange
        case .serious:  .red
        case .critical: .red
        @unknown default: .mbSecondaryLabel
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 13, design: .monospaced).weight(.bold))
                .foregroundColor(.mbLabel)

            HStack(spacing: 2) {
                Image(systemName: tempIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(tempColor)
                if let temp = monitor.thermal.batteryTempCelsius {
                    Text(String(format: "%.0f°", temp))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(tempColor)
                }
            }
        }
        .onAppear {
            guard !windowOpened else { return }
            windowOpened = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func formatSpeed(_ bps: Double) -> String {
        if bps >= 1_000_000_000 { return String(format: "%.1fGB/s", bps / 1_000_000_000) }
        if bps >= 1_000_000 { return String(format: "%.1fMB/s", bps / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0fKB/s", bps / 1_000) }
        return String(format: "%.0fB/s", bps)
    }
}
