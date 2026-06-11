import SwiftUI

struct SidebarView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Binding var selectedMetric: MetricType?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(Array(MetricType.allCases.enumerated()), id: \.element) { i, metric in
                        row(metric, index: i)
                    }
                } header: {
                    headerView
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationSplitViewColumnWidth(min: 260, ideal: 280)
    }

    private var headerView: some View {
        HStack(spacing: 4) {
            Image(systemName: "memorychip.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.mbSecondaryLabel)
            Text("MemBar")
                .font(.custom("RockSalt", size: 14))
                .foregroundStyle(Color.mbSecondaryLabel)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.mbBg)
    }

    private func row(_ metric: MetricType, index: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: metric.icon)
                .font(.body)
                .foregroundStyle(metric.color)
                .frame(width: 20)
                .symbolVariant(.fill)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(metric.label)
                        .font(.custom("Caveat", size: 14).weight(.semibold))
                    Spacer(minLength: 0)
                    Text(value(for: metric))
                        .font(.custom("Caveat", size: 15).weight(.bold))
                        .foregroundColor(selectedMetric == metric ? .mbLabel : .mbSecondaryLabel)
                }
                MiniBarChart(data: data(for: metric), color: metric.color)
                    .frame(height: 18)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(rowBg(for: metric, index: index))
        .contentShape(Rectangle())
        .onTapGesture { selectedMetric = metric }
    }

    @ViewBuilder
    private func rowBg(for metric: MetricType, index: Int) -> some View {
        if selectedMetric == metric {
            LinearGradient(
                colors: [Color.mbSelected, Color.mbSidebarEven],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            index % 2 == 0 ? Color.mbSidebarEven : Color.mbSidebarOdd
        }
    }

    private func value(for metric: MetricType) -> String {
        switch metric {
        case .cpu:    String(format: "%.1f%%", monitor.cpu.usagePercent)
        case .memory: formatBytes(monitor.memory.usedBytes)
        case .network:formatSpeed(monitor.displayDownloadSpeed)
        }
    }

    private func data(for metric: MetricType) -> [Double] {
        switch metric {
        case .cpu:    monitor.cpuHistoryData
        case .memory: monitor.memoryHistoryData
        case .network:monitor.downloadHistoryData
        }
    }

    private func formatBytes(_ b: UInt64) -> String {
        if b >= 1_073_741_824 {
            return String(format: "%.1fGB", Double(b) / 1_073_741_824)
        } else if b >= 1_048_576 {
            return String(format: "%.0fMB", Double(b) / 1_048_576)
        } else {
            return String(format: "%.0fKB", Double(b) / 1_024)
        }
    }

    private func formatSpeed(_ bps: Double) -> String {
        if bps >= 1_000_000 { return String(format: "%.1fMB/s", bps / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0fKB/s", bps / 1_000) }
        return String(format: "%.0fB/s", bps)
    }
}

enum MetricType: String, CaseIterable, Identifiable {
    case cpu, memory, network
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cpu:    "cpu"
        case .memory: "memorychip"
        case .network:"network"
        }
    }

    var color: Color {
        switch self {
        case .cpu:    .mbCpu
        case .memory: .mbMemory
        case .network:.mbNetworkUp
        }
    }

    var label: String {
        switch self {
        case .cpu:    "CPU"
        case .memory: "内存"
        case .network:"网络"
        }
    }
}
