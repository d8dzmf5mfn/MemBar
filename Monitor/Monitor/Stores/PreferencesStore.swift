import Foundation

extension Notification.Name {
    static let preferencesDidChange = Notification.Name("preferencesDidChange")
}

@MainActor @Observable
final class PreferencesStore {
    enum Keys {
        static let menuBarMode = "menuBarMode"
        static let useSmoothNetwork = "useSmoothNetwork"
        static let refreshInterval = "refreshInterval"
    }

    static let shared = PreferencesStore()
    static let supportedRefreshIntervals: [TimeInterval] = [1.0, 2.0, 5.0]

    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter

    init(defaults: UserDefaults = .standard, notificationCenter: NotificationCenter = .default) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    var menuBarMode: SystemMonitor.MenuBarMode {
        get {
            SystemMonitor.MenuBarMode(rawValue: defaults.string(forKey: Keys.menuBarMode) ?? "") ?? .memory
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.menuBarMode)
            postChange(key: Keys.menuBarMode)
        }
    }

    var useSmoothNetwork: Bool {
        get { defaults.bool(forKey: Keys.useSmoothNetwork) }
        set {
            defaults.set(newValue, forKey: Keys.useSmoothNetwork)
            postChange(key: Keys.useSmoothNetwork)
        }
    }

    var refreshInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: Keys.refreshInterval)
            return Self.supportedRefreshIntervals.contains(value) ? value : 2.0
        }
        set {
            let stored = Self.supportedRefreshIntervals.contains(newValue) ? newValue : 2.0
            defaults.set(stored, forKey: Keys.refreshInterval)
            postChange(key: Keys.refreshInterval)
        }
    }

    private func postChange(key: String) {
        notificationCenter.post(name: .preferencesDidChange, object: self, userInfo: ["key": key])
    }
}
