import Foundation
import IOKit

protocol BatteryTemperatureProviding {
    func batteryTemperatureCelsius() -> Double?
}

struct IOKitBatteryTemperatureProvider: BatteryTemperatureProviding {
    func batteryTemperatureCelsius() -> Double? {
        guard let matching = IOServiceMatching("AppleSmartBattery") else { return nil }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let rawValue = IORegistryEntryCreateCFProperty(
            service,
            "Temperature" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber else {
            return nil
        }

        let value = rawValue.doubleValue
        guard value > 0 else { return nil }
        return value / 10.0 - 273.15
    }
}

final class TemperatureRefreshController {
    private let minimumInterval: TimeInterval
    private let currentTime: () -> TimeInterval
    private let fetchTemperature: () -> Double?
    private var lastRefreshTime: TimeInterval?

    init(
        minimumInterval: TimeInterval,
        currentTime: @escaping () -> TimeInterval,
        fetchTemperature: @escaping () -> Double?
    ) {
        self.minimumInterval = minimumInterval
        self.currentTime = currentTime
        self.fetchTemperature = fetchTemperature
    }

    func refreshIfNeeded() -> Double? {
        let now = currentTime()
        if let lastRefreshTime, now - lastRefreshTime < minimumInterval {
            return nil
        }

        lastRefreshTime = now
        return fetchTemperature()
    }
}
