import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore

    var body: some View {
        Form {
            Section("菜单栏") {
                Picker("默认显示", selection: $preferences.menuBarMode) {
                    ForEach(SystemMonitor.MenuBarMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("网络") {
                Toggle("平滑网速", isOn: $preferences.useSmoothNetwork)
                Picker("刷新间隔", selection: $preferences.refreshInterval) {
                    Text("1 秒").tag(1.0)
                    Text("2 秒").tag(2.0)
                    Text("5 秒").tag(5.0)
                }
                .pickerStyle(.segmented)
            }

            Section("启动") {
                LabeledContent("开机启动", value: "计划中")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 360)
    }
}
