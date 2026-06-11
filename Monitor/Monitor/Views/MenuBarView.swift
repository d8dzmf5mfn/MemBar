import SwiftUI

struct MenuBarView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            memoryRow
            Divider()
            networkRow
            Divider()
            temperatureRow
            footerView
        }
        .frame(width: 280)
    }

    private var headerView: some View {
        HStack(spacing: 4) {
            Image(systemName: "memorychip.fill")
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 12))
            Text("MemBar")
                .font(.custom("Caveat", size: 14).weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var memoryRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "memorychip")
                .font(.system(size: 12))
                .foregroundStyle(Color.mbMemory)
                .frame(width: 14)
            Text("内存")
                .font(.custom("Caveat", size: 13).weight(.semibold))
            Text(String(format: "%.1f%%", monitor.memory.usagePercent))
                .font(.custom("Caveat", size: 13).weight(.semibold))
                .foregroundColor(.mbLabel)
            Text(formatBytes(monitor.memory.usedBytes))
                .font(.custom("Caveat", size: 13).weight(.semibold))
                .foregroundColor(.mbLabel)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var networkRow: some View {
        Button {
            monitor.toggleNetworkSmooth()
        } label: {
            HStack(spacing: 5) {
                    Image(systemName: "network")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mbNetworkUp)
                        .frame(width: 14)
                Text("网络")
                    .font(.custom("Caveat", size: 13).weight(.semibold))
                    .foregroundColor(.primary)
                    if monitor.useSmoothNetwork {
                        Text("平滑")
                            .font(.custom("Caveat", size: 11))
                            .foregroundColor(.mbCpu)
                    }
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Color.mbNetworkDown)
                        Text(formatSpeed(monitor.displayDownloadSpeed))
                            .font(.custom("Caveat", size: 12).weight(.semibold))
                            .foregroundColor(.mbLabel)
                    }
                    HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Color.mbNetworkUp)
                        Text(formatSpeed(monitor.displayUploadSpeed))
                            .font(.custom("Caveat", size: 12).weight(.semibold))
                            .foregroundColor(.mbLabel)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
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

    private var temperatureRow: some View {
        HStack(spacing: 5) {
            Image(systemName: tempIcon)
                .font(.system(size: 12))
                .foregroundStyle(tempColor)
                .frame(width: 14)
                .symbolVariant(.fill)
            Text("温度")
                .font(.custom("Caveat", size: 13).weight(.semibold))
            Text(monitor.thermal.label)
                .font(.custom("Caveat", size: 13).weight(.semibold))
                .foregroundColor(tempColor)
            if let temp = monitor.thermal.batteryTempCelsius {
                Text(String(format: "%.0f°C", temp))
                    .font(.custom("Caveat", size: 13).weight(.semibold))
                    .foregroundColor(.mbLabel)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()

            Picker("菜单栏显示", selection: Bindable(monitor).menuBarMode) {
                ForEach(SystemMonitor.MenuBarMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Button {
                openWindow(id: "main")
            } label: {
                Label("打开完整窗口", systemImage: "macwindow")
                    .font(.system(size: 11))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .background(Color.mbCpu.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
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
