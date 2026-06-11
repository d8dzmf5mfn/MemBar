import SwiftUI

struct ContentView: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var selectedMetric: MetricType? = .cpu

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedMetric: $selectedMetric)
                .navigationSplitViewColumnWidth(260)
        } detail: {
            detailView
                .onAppear { monitor.start() }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedMetric {
        case .cpu:
            CPUDetailView()
        case .memory:
            MemoryDetailView()
        case .network:
            NetworkDetailView()
        case nil:
            CPUDetailView()
        }
    }
}
