import SwiftUI

struct MemoryDetailView: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var showHistory = false

    private var freePercent: Double { max(100 - monitor.memory.usagePercent, 0) }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 10) {
                    Spacer(minLength: 0)

                    LazyVGrid(columns: [
                        GridItem(.flexible(minimum: 160)),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        XcodeGaugeView(
                            value: Double(monitor.memory.usedBytes) / 1_073_741_824,
                            maxValue: Double(monitor.memory.totalBytes) / 1_073_741_824,
                            unit: "GB", color: .mbMemory
                        )
                        .frame(minHeight: 120)

                        memoryBreakdown
                    }
                    .padding(16)
                    .tornBackground()
                    .padding(.horizontal, 12)

                    Divider().padding(.horizontal, 12)

                    historyToggle

                    Spacer(minLength: 0)
                }
                .frame(minHeight: geo.size.height)
                .padding(.vertical, 8)
            }
        }
        .paperBackground()
        .navigationTitle("内存")
    }

    @ViewBuilder
    private var memoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            let t = monitor.memory.totalBytes
            let appPct = t > 0 ? Double(monitor.memory.appMemoryBytes) / Double(t) * 100 : 0
            let wiredPct = t > 0 ? Double(monitor.memory.wiredBytes) / Double(t) * 100 : 0
            let compPct = t > 0 ? Double(monitor.memory.compressedBytes) / Double(t) * 100 : 0
            let used = monitor.memory.usagePercent
            let otherPct = max(used - appPct - wiredPct - compPct, 0)
            let free = freePercent

            DonutChartView(segments: [
                .init(label: "App", value: appPct, color: .mbMemory,
                      startAngle: 0, endAngle: appPct / 100 * 360, percentage: appPct),
                .init(label: "Wired", value: wiredPct, color: .mbWired,
                      startAngle: appPct / 100 * 360,
                      endAngle: (appPct + wiredPct) / 100 * 360, percentage: wiredPct),
                .init(label: "压缩", value: compPct, color: .mbCompressed,
                      startAngle: (appPct + wiredPct) / 100 * 360,
                      endAngle: (appPct + wiredPct + compPct) / 100 * 360, percentage: compPct),
                .init(label: "其他", value: otherPct, color: .mbOther,
                      startAngle: (appPct + wiredPct + compPct) / 100 * 360,
                      endAngle: used / 100 * 360, percentage: otherPct),
                .init(label: "空闲", value: free, color: .mbIdle,
                      startAngle: used / 100 * 360, endAngle: 360, percentage: free),
            ], donutSize: 130, showLabels: false)
            .frame(maxWidth: .infinity)

            DataRow(label: "App", value: appPct, color: .mbMemory)
            DataRow(label: "Wired", value: wiredPct, color: .mbWired)
            DataRow(label: "压缩", value: compPct, color: .mbCompressed)
            DataRow(label: "其他", value: otherPct, color: .mbOther)
            DataRow(label: "空闲", value: freePercent, color: .mbIdle)
        }
    }

    @ViewBuilder
    private var historyToggle: some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) { showHistory.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showHistory ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.mbSecondaryLabel)
                Label("历史趋势", systemImage: "chart.xyaxis.line")
                    .font(.caption)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)

        if showHistory {
            LabelledChartView(data: monitor.memoryHistoryData,
                              color: .mbMemory, yLabel: "%")
                .padding(.horizontal, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
