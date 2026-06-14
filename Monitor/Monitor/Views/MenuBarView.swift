import SwiftUI
import Combine

/// The SwiftUI hierarchy displayed inside the NSPopover that opens when
/// the user clicks the menu bar icon.
///
/// Layout (top to bottom):
///   1. Picker — switches menu-bar icon between memory and network modes.
///   2. Donut chart — replaces the previous pixel whale. Shows memory
///      usage as a large clockwise arc; 0% = empty, 100% = full ring.
///   3. Data rows — 4 rows: memory / CPU / network / temperature.
///   4. Quit button.
///
/// The popover refresh mechanism is the same as the rest of the project:
/// a NotificationCenter post on every `SystemMonitor.refresh()` cycle
/// bumps `refreshCounter`, which `.id()` forces a full view rebuild.
struct MenuBarView: View {
    let monitor: SystemMonitor
    @State private var refreshCounter = 0

    private var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua]) != nil
    }

    private var cellText: Color { .primary }
    private var cellSecondary: Color { .secondary }
    private var normalColor: Color { .green }

    private var memoryFraction: Double {
        max(0, min(1, monitor.memory.usagePercent / 100.0))
    }

    // MARK: - Layout constants

    private let donutSize: CGFloat = 96
    private let donutStroke: CGFloat = 10
    private let barCount: Int = 14      // how many bars in the network chart
    private let barSpacing: CGFloat = 1.5  // pt between bars
    private let barChartHeight: CGFloat = 40  // total height of the bar chart row

    var body: some View {
        VStack(spacing: 0) {
            // ---- 1. Mode picker ----
            HStack {
                Picker("显示", selection: Bindable(monitor).menuBarMode) {
                    Text("内存占用").tag(SystemMonitor.MenuBarMode.memory)
                    Text("网速").tag(SystemMonitor.MenuBarMode.network)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(maxWidth: 200)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)

            // ---- 2. Mode-specific chart ----
            // Memory mode → large donut ring (replaces the pixel whale).
            // Network mode → Energy Impact-style 20-bar history chart.
            modeSection
                .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 12)

            // ---- 3. Data rows ----
            dataRows
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            // ---- 4. Footer / quit ----
            footer
        }
        .frame(width: 240)
        .id(refreshCounter)
        .onAppear { }
        .onReceive(NotificationCenter.default.publisher(for: .systemMonitorDidRefresh)) { _ in
            refreshCounter += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NSSystemColorsDidChangeNotification"))) { _ in
            refreshCounter += 1
        }
    }

    // MARK: - Mode-specific chart (memory or network)

    /// Switches between the donut (memory) and the bar chart (network)
    /// based on the Picker state. Both variants share the same HStack
    /// layout (chart on the left, text panel on the right) so the right-
    /// hand labels stay in the same position when the user toggles modes.
    @ViewBuilder
    private var modeSection: some View {
        switch monitor.menuBarMode {
        case .memory:
            donutSection
        case .network:
            networkSection
        }
    }

    // MARK: - Donut chart (memory mode)

    private var donutSection: some View {
        HStack(spacing: 16) {
            ZStack {
                // Track ring (faint)
                Circle()
                    .stroke(
                        Color.primary.opacity(isDarkMode ? 0.15 : 0.12),
                        lineWidth: donutStroke
                    )
                // Progress arc
                if memoryFraction > 0 {
                    Circle()
                        .trim(from: 0, to: memoryFraction)
                        .stroke(
                            Color.primary,
                            style: StrokeStyle(
                                lineWidth: donutStroke,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))  // start at 12 o'clock
                        .animation(.easeInOut(duration: 0.3), value: memoryFraction)
                }
            }
            .frame(width: donutSize, height: donutSize)

            VStack(alignment: .leading, spacing: 3) {
                Text(String(format: "%.1f%%", monitor.memory.usagePercent))
                    .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(cellText)
                Text("\(formatBytes(monitor.memory.usedBytes)) / \(formatBytes(monitor.memory.totalBytes))")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(cellSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Network history chart (network mode)

    /// Energy Impact-style 20-bar history chart. Each bar represents the
    /// download speed (or upload) for one `SystemMonitor.refreshInterval`
    /// (2 s) sample. Bar height is normalized to the maximum of the visible
    /// window so the tallest bar always reaches the top — matches the
    /// Activity Monitor "Energy Impact" feel.
    ///
    /// We keep `barCount` history points so the chart shows ~40 s of
    /// history (20 samples × 2 s), which is enough to see spikes but
    /// recent enough to feel "live".
    private var networkSection: some View {
        HStack(spacing: 16) {
            // ---- Bar chart (download) ----
            // The download chart fills the left, with a thin label above.
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.blue)
                    Text(formatSpeed(monitor.displayDownloadSpeed))
                        .font(.system(size: 11, design: .monospaced).weight(.semibold))
                        .foregroundStyle(cellText)
                }
                barChart(values: downloadSamples, color: .blue)
                    .frame(height: barChartHeight)
            }

            // ---- Bar chart (upload) ----
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.green)
                    Text(formatSpeed(monitor.displayUploadSpeed))
                        .font(.system(size: 11, design: .monospaced).weight(.semibold))
                        .foregroundStyle(cellText)
                }
                barChart(values: uploadSamples, color: .green)
                    .frame(height: barChartHeight)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
    }

    /// Take the last `barCount` samples from the full history. Newer samples
    /// go on the right (matches Activity Monitor orientation). The history
    /// arrays are in KB/s (see SystemMonitor.refresh: /1024.0).
    private var downloadSamples: [Double] {
        let history = monitor.downloadHistoryData   // KB/s
        return Array(history.suffix(barCount))
    }

    private var uploadSamples: [Double] {
        let history = monitor.uploadHistoryData     // KB/s
        return Array(history.suffix(barCount))
    }

    /// Render a single bar chart row. `values` are normalized to [0, 1]
    /// against the max in the window so the largest bar fills the height.
    @ViewBuilder
    private func barChart(values: [Double], color: Color) -> some View {
        GeometryReader { geo in
            // Determine the scale: the tallest bar in this window = full
            // height. Guard against division by zero when all values are 0.
            let maxValue = max(values.max() ?? 0, 1)
            let totalSpacing = barSpacing * CGFloat(max(0, barCount - 1))
            let barWidth = max(1, (geo.size.width - totalSpacing) / CGFloat(barCount))
            let usableHeight = geo.size.height

            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    // Right-align the newest sample on the right edge; if
                    // we have fewer than `barCount` samples (just-launched
                    // app), pad the left with empty bars.
                    let valueIndex = values.count - barCount + i
                    let value: Double = (valueIndex >= 0 && valueIndex < values.count)
                        ? values[valueIndex]
                        : 0
                    let ratio = CGFloat(value / maxValue)
                    let barHeight = max(1, usableHeight * ratio)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(value > 0 ? color : color.opacity(0.15))
                        .frame(width: barWidth, height: barHeight)
                        // Smooth height transitions when the value updates
                        .animation(.easeInOut(duration: 0.4), value: value)
                }
            }
        }
    }

    // MARK: - Data rows

    private var dataRows: some View {
        VStack(spacing: 6) {
            row(icon: "memorychip",
                label: "内存",
                value: String(format: "%.1f GB", Double(monitor.memory.usedBytes) / 1_073_741_824),
                extra: String(format: "%.1f%%", monitor.memory.usagePercent))
            row(icon: "cpu",
                label: "CPU",
                value: String(format: "%.1f%%", monitor.cpu.usagePercent),
                extra: nil)
            row(icon: "network",
                label: "网络",
                value: "↓ \(formatSpeed(monitor.displayDownloadSpeed))",
                extra: "↑ \(formatSpeed(monitor.displayUploadSpeed))")
            HStack(spacing: 5) {
                Image(systemName: "thermometer")
                    .font(.system(size: 10))
                    .foregroundStyle(cellSecondary)
                    .frame(width: 14)
                Text("温度")
                    .font(.system(size: 11))
                    .foregroundStyle(cellSecondary)
                Text(monitor.thermal.label)
                    .font(.system(size: 11).weight(.semibold))
                    .foregroundStyle(monitor.thermal.state == .nominal ? normalColor : .orange)
                if let t = monitor.thermal.batteryTempCelsius {
                    Text(String(format: "%.0f°C", t))
                        .font(.system(size: 11))
                        .foregroundStyle(cellSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func row(icon: String, label: String, value: String, extra: String?) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(cellSecondary)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(cellSecondary)
            Text(value)
                .font(.system(size: 11, design: .monospaced).weight(.semibold))
            if let extra {
                Text(extra)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(cellSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer(minLength: 0)
                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(cellSecondary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Formatters

    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes >= 1_073_741_824 {
            return String(format: "%.1fGB", Double(bytes) / 1_073_741_824)
        } else if bytes >= 1_048_576 {
            return String(format: "%.0fMB", Double(bytes) / 1_048_576)
        } else {
            return String(format: "%.0fKB", Double(bytes) / 1_024)
        }
    }

    private func formatSpeed(_ bps: Double) -> String {
        if bps >= 1_000_000_000 { return String(format: "%.1fGB/s", bps / 1_000_000_000) }
        if bps >= 1_000_000 { return String(format: "%.1fMB/s", bps / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0fKB/s", bps / 1_000) }
        return String(format: "%.0fB/s", bps)
    }
}
