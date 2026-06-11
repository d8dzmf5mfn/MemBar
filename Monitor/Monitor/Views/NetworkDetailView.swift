import SwiftUI

struct NetworkDetailView: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var showHistory = false

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 10) {
                    Spacer(minLength: 0)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        NetworkCard(value: monitor.displayDownloadSpeed,
                                    label: "下载", icon: "arrow.down.circle.fill",
                                    color: .mbNetworkDown)
                        NetworkCard(value: monitor.displayUploadSpeed,
                                    label: "上传", icon: "arrow.up.circle.fill",
                                    color: .mbNetworkUp)
                    }
                    .padding(16)
                    .tornBackground()
                    .padding(.horizontal, 12)

                    HStack(spacing: 4) {
                        Text("模式:")
                            .font(.caption)
                            .foregroundColor(.mbSecondaryLabel)
                        Button(monitor.useSmoothNetwork ? "平滑" : "实时") {
                            withAnimation(.smooth(duration: 0.2)) {
                                monitor.toggleNetworkSmooth()
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(monitor.useSmoothNetwork ? .mbCpu : .mbNetworkDown)
                        .buttonStyle(.plain)
                        .underline()
                        Spacer(minLength: 0)
                    }
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
        .navigationTitle("网络")
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
            VStack(spacing: 6) {
                Text("下载")
                    .font(.caption2)
                    .foregroundColor(.mbSecondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LabelledChartView(data: monitor.downloadHistoryData,
                                  color: .mbNetworkDown, yLabel: "KB/s")
                Text("上传")
                    .font(.caption2)
                    .foregroundColor(.mbSecondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LabelledChartView(data: monitor.uploadHistoryData,
                                  color: .mbNetworkUp, yLabel: "KB/s")
            }
            .padding(.horizontal, 12)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

struct NetworkCard: View {
    var value: Double
    var label: String
    var icon: String
    var color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
            Text(formatSpeed(value))
                .font(.system(size: 26, design: .monospaced).weight(.bold))
            Text(label)
                .font(.callout)
                .foregroundColor(.mbSecondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatSpeed(_ bps: Double) -> String {
        if bps >= 1_000_000_000 { return String(format: "%.2fGB/s", bps / 1_000_000_000) }
        if bps >= 1_000_000 { return String(format: "%.2fMB/s", bps / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0fKB/s", bps / 1_000) }
        return String(format: "%.0fB/s", bps)
    }
}
