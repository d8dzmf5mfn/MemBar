import SwiftUI
import Combine

/// The SwiftUI hierarchy displayed inside the NSPopover that opens when
/// the user clicks the menu bar icon.
///
/// Layout (top to bottom):
///   1. Picker — switches menu-bar icon between memory and network modes.
///   2. Donut chart — memory mode. Large clockwise arc with a center
///      percentage readout, colored by usage level (green → orange → red).
///   3. Bar chart — network mode. Two stacked rolling-window bar charts
///      (download + upload) with a peak indicator.
///   4. Data rows — 内存 / CPU / 网络 / 温度.
///   5. Quit button.
///
/// Refresh strategy
/// ----------------
/// `SystemMonitor` posts a notification on each 2 s sample. The
/// `.onReceive` handler bumps a local `@State` counter, which forces
/// the body to re-evaluate — that re-reads the `@Observable` monitor
/// snapshot and feeds the new values into the value-driven
/// `.animation(_:value:)` modifiers below. We intentionally avoid
/// `.id(refreshCounter)` on the root view: a forced full view rebuild
/// would tear down in-flight transitions and make the gauge feel
/// "stepped" rather than fluid.
struct MenuBarView: View {
    let monitor: SystemMonitor
    @State private var refreshTick: Int = 0
    @State private var isDarkMode: Bool =
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua]) != nil

    // MARK: - Layout constants

    private let donutSize: CGFloat = 92
    private let donutStroke: CGFloat = 9
    /// Extra room around the ring so the end-cap dot at the 12 o'clock
    /// position can extend beyond the stroke without being clipped by
    /// the popover's rounded rect background.
    private let donutInset: CGFloat = 5
    private let barCount: Int = 16      // how many bars in the network chart
    private let barSpacing: CGFloat = 1.5
    private let barChartHeight: CGFloat = 40
    private let popoverWidth: CGFloat = 292

    var body: some View {
        VStack(spacing: 0) {
            modePicker
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

            chartSection
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(panelBackground)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

            dataRows
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(panelBackground)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

            footer
        }
        .frame(width: popoverWidth)
        .onReceive(NotificationCenter.default.publisher(for: .systemMonitorDidRefresh)) { _ in
            // Bump a local @State so the body re-evaluates on every
            // refresh tick. @Observable tracking is brittle inside
            // popover contexts in some macOS releases, so the
            // notification is the reliable trigger. Animations are
            // driven by the value-based `.animation(_:value:)` modifiers
            // on the individual views, not by this state change.
            refreshTick &+= 1
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didChangeScreenParametersNotification
            )
        ) { _ in
            // Appearance flips don't post our refresh notification, so
            // update the cached isDarkMode flag here and let SwiftUI
            // diff the next refresh tick in the new color.
            isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua]) != nil
        }
        .animation(.smooth(duration: 0.32), value: monitor.menuBarMode)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.primary.opacity(isDarkMode ? 0.07 : 0.045))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(isDarkMode ? 0.08 : 0.055), lineWidth: 1)
            )
    }

    // MARK: - Picker

    private var modePicker: some View {
        Picker("显示", selection: Bindable(monitor).menuBarMode) {
            Text("内存使用").tag(SystemMonitor.MenuBarMode.memory)
            Text("网速").tag(SystemMonitor.MenuBarMode.network)
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
    }

    // MARK: - Mode switch

    @ViewBuilder
    private var chartSection: some View {
        ZStack {
            switch monitor.menuBarMode {
            case .memory:
                donutSection
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            case .network:
                networkSection
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
    }

    // MARK: - Donut chart (memory mode)

    private var donutSection: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                // Track ring (faint) — explicit frame so the ring stays
                // at `donutSize` even though the ZStack is padded for the
                // end-cap dot.
                Circle()
                    .stroke(
                        Color.primary.opacity(isDarkMode ? 0.14 : 0.10),
                        lineWidth: donutStroke
                    )
                    .frame(width: donutSize, height: donutSize)
                // Progress arc — color depends on usage level.
                if memoryFraction > 0.001 {
                    Circle()
                        .trim(from: 0, to: memoryFraction)
                        .stroke(
                            ringColor,
                            style: StrokeStyle(
                                lineWidth: donutStroke,
                                lineCap: .round
                            )
                        )
                        .frame(width: donutSize, height: donutSize)
                        .rotationEffect(.degrees(-90))  // start at 12 o'clock
                        .shadow(
                            color: ringColor.opacity(memoryFraction > 0.85 ? 0.45 : 0),
                            radius: 4
                        )
                }
                // End-of-arc dot that rides the trim end for a polished
                // "live" feel. Positioned on a copy of the trim that we
                // use only to derive the on-circle coordinates via
                // rotation; the dot is a separate primitive.
                endCapDot
            }
            .frame(width: donutSize + 2 * donutInset, height: donutSize + 2 * donutInset)
            .drawingGroup()  // GPU-render the stroked shape, smoother on retina
            .animation(.smooth(duration: 0.5), value: memoryFraction)
            .animation(.easeInOut(duration: 0.25), value: ringColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(formatPercent(monitor.memory.usagePercent))
                    .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.primary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.45), value: monitor.memory.usagePercent)
                Text("\(formatBytes(monitor.memory.usedBytes)) / \(formatBytes(monitor.memory.totalBytes))")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(ringCaption)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ringColor)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
    }

    /// A small filled circle that sits at the leading edge of the
    /// progress arc. Built by trimming a 1-px stroke from 0 to fraction
    /// on a hidden Circle (same ZStack geometry), then animating a
    /// `.position` along the path. We achieve this with a rotated dot
    /// that we push to the edge of the ring using a frame + offset.
    @ViewBuilder
    private var endCapDot: some View {
        if memoryFraction > 0.001 && memoryFraction < 0.999 {
            // The Circle is centered in a ZStack that is `donutSize` wide
            // and padded by `donutInset` on each side. The Circle's center
            // therefore sits at (donutInset + donutSize/2, donutInset +
            // donutSize/2); pushing the dot up by `donutSize/2` lands it
            // on the stroke at 12 o'clock, and the rotation effect then
            // carries it around the ring as `memoryFraction` advances.
            let radius = donutSize / 2
            Circle()
                .fill(ringColor)
                .frame(width: donutStroke + 2, height: donutStroke + 2)
                .offset(y: -radius)
                .rotationEffect(.degrees(360 * memoryFraction))
                .opacity(0.95)
                .animation(.smooth(duration: 0.5), value: memoryFraction)
        }
    }

    // MARK: - Bar chart (network mode)

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            barChartRow(
                title: "下载",
                symbol: "arrow.down",
                tint: .blue,
                value: monitor.displayDownloadSpeed,
                samples: downloadSamples
            )
            barChartRow(
                title: "上传",
                symbol: "arrow.up",
                tint: .green,
                value: monitor.displayUploadSpeed,
                samples: uploadSamples
            )
        }
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private func barChartRow(
        title: String,
        symbol: String,
        tint: Color,
        value: Double,
        samples: [Double]
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // Left label column
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Image(systemName: symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(formatSpeed(value))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.45), value: value)
            }
            .frame(width: 72, alignment: .leading)

            // Right chart
            barChart(samples: samples, tint: tint)
                .frame(height: barChartHeight)
        }
    }

    private var downloadSamples: [Double] {
        Array(monitor.downloadHistoryData.suffix(barCount))
    }

    private var uploadSamples: [Double] {
        Array(monitor.uploadHistoryData.suffix(barCount))
    }

    /// Renders a horizontal rolling-window bar chart. Each bar
    /// represents one `SystemMonitor.refreshInterval` (2 s) sample.
    /// Bar height is normalized to the max value in the window so the
    /// tallest bar always reaches the top — matches the Activity
    /// Monitor "Energy Impact" feel.
    ///
    /// Only the rightmost (latest) bar is wrapped in a TimelineView so
    /// it can pulse between 2 s data samples; the other 15 bars are
    /// static and only re-render on the real refresh tick.
    @ViewBuilder
    private func barChart(samples: [Double], tint: Color) -> some View {
        let maxValue = max(samples.max() ?? 0, 1)
        let baselineColor = Color.primary.opacity(isDarkMode ? 0.08 : 0.06)

        GeometryReader { geo in
            let totalSpacing = barSpacing * CGFloat(max(0, barCount - 1))
            let barWidth = max(1.5, (geo.size.width - totalSpacing) / CGFloat(barCount))
            let usableHeight = geo.size.height

            ZStack(alignment: .bottomLeading) {
                // Faint baseline rule — anchors the eye when traffic is
                // near zero (otherwise the chart looks empty).
                Rectangle()
                    .fill(baselineColor)
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                HStack(alignment: .bottom, spacing: barSpacing) {
                    // Historical bars: value-driven, no per-frame work.
                    ForEach(0..<(barCount - 1), id: \.self) { i in
                        barView(
                            value: sampleValue(samples: samples, index: i),
                            maxValue: maxValue,
                            barWidth: barWidth,
                            usableHeight: usableHeight,
                            tint: tint
                        )
                    }
                    // Latest bar: live pulse on top of value changes.
                    LiveBar(
                        value: sampleValue(samples: samples, index: barCount - 1),
                        maxValue: maxValue,
                        barWidth: barWidth,
                        usableHeight: usableHeight,
                        tint: tint,
                        refreshInterval: monitor.refreshInterval
                    )
                }
            }
        }
    }

    /// Look up a sample at logical index `i` within the rolling window.
    /// When the history buffer is short (just-launched app), the missing
    /// leftmost positions read back as zero so the right edge always
    /// holds the most recent sample.
    private func sampleValue(samples: [Double], index: Int) -> Double {
        let valueIndex = samples.count - barCount + index
        return (valueIndex >= 0 && valueIndex < samples.count) ? samples[valueIndex] : 0
    }

    /// Static bar — animates height changes via the value-driven
    /// `.animation` modifier. Used for all bars except the rightmost,
    /// which is `LiveBar` and gets the timeline-driven pulse.
    @ViewBuilder
    private func barView(
        value: Double,
        maxValue: Double,
        barWidth: CGFloat,
        usableHeight: CGFloat,
        tint: Color
    ) -> some View {
        let ratio = CGFloat(value / maxValue)
        let barHeight = max(value > 0 ? 2 : 0, usableHeight * ratio)
        let barColor: Color = tint.opacity(value > 0 ? 0.78 : 0.22)

        RoundedRectangle(cornerRadius: 1.8, style: .continuous)
            .fill(barColor)
            .frame(width: barWidth, height: barHeight)
            .animation(.smooth(duration: 0.45), value: value)
    }

    // MARK: - Data rows

    private var dataRows: some View {
        VStack(spacing: 5) {
            row(icon: "memorychip",
                label: "内存",
                primary: formatBytes(monitor.memory.usedBytes),
                secondary: String(format: "%.1f%%", monitor.memory.usagePercent),
                accent: ringColor)
            row(icon: "cpu",
                label: "CPU",
                primary: String(format: "%.1f%%", monitor.cpu.usagePercent),
                secondary: nil,
                accent: usageColor(monitor.cpu.usagePercent))
            row(icon: "network",
                label: "网络",
                primary: "↓ \(formatSpeed(monitor.displayDownloadSpeed))",
                secondary: "↑ \(formatSpeed(monitor.displayUploadSpeed))",
                accent: .primary)
            temperatureRow
        }
    }

    @ViewBuilder
    private func row(
        icon: String,
        label: String,
        primary: String,
        secondary: String?,
        accent: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 14, alignment: .center)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            Text(primary)
                .font(.system(size: 11.5, design: .monospaced).weight(.semibold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.45), value: primary)
            if let secondary {
                Text(secondary)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.45), value: secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var temperatureRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "thermometer.medium")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(monitor.thermal.state == .nominal ? .green : .orange)
                .frame(width: 14, alignment: .center)
            Text("温度")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            Text(monitor.thermal.label)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(monitor.thermal.state == .nominal ? .green : .orange)
            if let t = monitor.thermal.batteryTempCelsius {
                Text(String(format: "%.0f°C", t))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary)
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
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Color helpers

    /// Green below 60%, orange 60–85%, red 85%+. Drives both the ring
    /// color and the "稳定/偏高/告急" caption next to the percentage.
    private var ringColor: Color {
        usageColor(monitor.memory.usagePercent)
    }

    private func usageColor(_ percent: Double) -> Color {
        if percent < 60 { return .green }
        if percent < 85 { return .orange }
        return .red
    }

    private var ringCaption: String {
        let p = monitor.memory.usagePercent
        if p < 60 { return "稳定" }
        if p < 85 { return "偏高" }
        return "告急"
    }

    // MARK: - Math

    private var memoryFraction: Double {
        max(0, min(1, monitor.memory.usagePercent / 100.0))
    }

    // MARK: - Formatters

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

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

// MARK: - LiveBar
// =====================================================
// Rightmost (most recent) bar of the network chart. Instead of a
// frozen bar that only jumps at each 2 s sample, this view interpolates
// from the previous value to the new value using an ease-out quadratic
// curve, so the bar smoothly "fills" between refreshes.
// =====================================================
private struct LiveBar: View {
    let value: Double
    let maxValue: Double
    let barWidth: CGFloat
    let usableHeight: CGFloat
    let tint: Color
    let refreshInterval: TimeInterval

    @State private var previousValue: Double = 0
    @State private var lastUpdate: Date = .now

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(lastUpdate)
            let progress = min(elapsed / max(refreshInterval, 0.1), 1.0)
            // Ease-out quadratic: fast start, gentle finish
            let easedProgress = 1.0 - (1.0 - progress) * (1.0 - progress)
            let effectiveValue = previousValue + (value - previousValue) * easedProgress

            let ratio = maxValue > 0 ? CGFloat(effectiveValue / maxValue) : 0
            let barHeight = max(effectiveValue > 0 ? 2 : 0, usableHeight * ratio)
            let barColor: Color = effectiveValue > 0 ? tint : tint.opacity(0.22)

            RoundedRectangle(cornerRadius: 1.8, style: .continuous)
                .fill(barColor)
                .frame(width: barWidth, height: barHeight)
        }
        .onChange(of: value) { old, new in
            // When SystemMonitor pushes a new sample, we record the
            // old value as the interpolation start point and reset the
            // clock. The bar then smoothly transitions from old → new
            // over the next 2 seconds. Skipping very small changes so
            // the bar doesn't glitch on noise.
            guard abs(new - old) > 0.001 else { return }
            previousValue = old
            lastUpdate = .now
        }
    }
}
