import SwiftUI

struct CPUDetailView: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var showHistory = false

    private var freePercent: Double { max(100 - monitor.cpu.usagePercent, 0) }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 10) {
                    Spacer(minLength: 0)

                    LazyVGrid(columns: [
                        GridItem(.flexible(minimum: 160)),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        XcodeGaugeView(value: monitor.cpu.usagePercent,
                                       unit: "%", color: .mbCpu)
                            .frame(minHeight: 120)

                        VStack(alignment: .leading, spacing: 8) {
                            let u = monitor.cpu.userPercent
                            let s = monitor.cpu.systemPercent
                            let f = freePercent
                            DonutChartView(segments: [
                                .init(label: "用户", value: u, color: .mbUser,
                                      startAngle: 0, endAngle: u / 100 * 360, percentage: u),
                                .init(label: "系统", value: s, color: .mbSystem,
                                      startAngle: u / 100 * 360,
                                      endAngle: (u + s) / 100 * 360, percentage: s),
                                .init(label: "空闲", value: f, color: .mbIdle,
                                      startAngle: (u + s) / 100 * 360, endAngle: 360, percentage: f),
                            ], donutSize: 130, showLabels: false)
                            .frame(maxWidth: .infinity)

                            DataRow(label: "用户", value: monitor.cpu.userPercent, color: .mbUser)
                            DataRow(label: "系统", value: monitor.cpu.systemPercent, color: .mbSystem)
                            DataRow(label: "空闲", value: freePercent, color: .mbIdle)
                        }
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
        .navigationTitle("CPU")
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
            LabelledChartView(data: monitor.cpuHistoryData,
                              color: .mbCpu, yLabel: "%")
                .padding(.horizontal, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
