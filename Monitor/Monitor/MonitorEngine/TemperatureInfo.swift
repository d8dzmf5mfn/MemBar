import Foundation

/// Read battery temperature from IORegistry.
/// On Apple Silicon Macs, the battery gas gauge exposes "Temperature" in 0.1 Kelvin units.
/// Returns °C or nil if unavailable.
nonisolated func collectBatteryTemperatureFromIOReg() -> Double? {
    let task = Process()
    task.launchPath = "/usr/sbin/ioreg"
    // Use -l (short output format, not -w0 which doesn't trunc) with grep to find "Temperature"
    task.arguments = ["-l"]

    let pipe = Pipe()
    task.standardOutput = pipe

    do {
        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        // Parse "Temperature" = <value> (battery temp in 0.1 Kelvin)
        let pattern = try NSRegularExpression(pattern: "\"Temperature\"\\s*=\\s*(\\d+)")
        let range = NSRange(output.startIndex..., in: output)
        if let match = pattern.firstMatch(in: output, range: range) {
            let valueRange = Range(match.range(at: 1), in: output)!
            let value = UInt64(output[valueRange]) ?? 0
            guard value > 0 else { return nil }
            // Temperature is in 0.1 Kelvin units
            let celsius = Double(value) / 10.0 - 273.15
            return celsius
        }
        return nil
    } catch {
        return nil
    }
}