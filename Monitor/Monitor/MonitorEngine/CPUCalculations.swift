import Foundation

struct CPUUsageResult {
    let usagePercent: Double
    let perCoreUsage: [Double]
}

struct CPUStatePercents {
    let userPercent: Double
    let systemPercent: Double
    let idlePercent: Double
}

nonisolated func calculateCPUUsage(previous: [CPUResult]?, current: [CPUResult]) -> CPUUsageResult {
    guard let previous else {
        return CPUUsageResult(usagePercent: 0, perCoreUsage: Array(repeating: 0, count: current.count))
    }

    var perCoreUsage: [Double] = []
    var totalUsed: UInt64 = 0
    var totalTicks: UInt64 = 0

    for (index, currentTicks) in current.enumerated() {
        let previousTicks = previous.indices.contains(index) ? previous[index] : CPUResult()
        let deltaUser = currentTicks.user &- previousTicks.user
        let deltaSystem = currentTicks.system &- previousTicks.system
        let deltaIdle = currentTicks.idle &- previousTicks.idle
        let deltaNice = currentTicks.nice &- previousTicks.nice
        let deltaTotal = deltaUser &+ deltaSystem &+ deltaIdle &+ deltaNice
        let deltaUsed = deltaUser &+ deltaSystem &+ deltaNice

        if deltaTotal == 0 {
            perCoreUsage.append(0)
            continue
        }

        perCoreUsage.append(Double(deltaUsed) / Double(deltaTotal) * 100)
        totalUsed &+= deltaUsed
        totalTicks &+= deltaTotal
    }

    let usagePercent = totalTicks == 0 ? 0 : Double(totalUsed) / Double(totalTicks) * 100
    return CPUUsageResult(usagePercent: usagePercent, perCoreUsage: perCoreUsage)
}

nonisolated func calculateCPUStatePercents(previous: [CPUResult]?, current: [CPUResult]) -> CPUStatePercents {
    guard let previous else {
        return CPUStatePercents(userPercent: 0, systemPercent: 0, idlePercent: 0)
    }

    var totalUser: UInt64 = 0
    var totalSystem: UInt64 = 0
    var totalIdle: UInt64 = 0
    var totalNice: UInt64 = 0

    for (index, currentTicks) in current.enumerated() {
        let previousTicks = previous.indices.contains(index) ? previous[index] : CPUResult()
        totalUser &+= currentTicks.user &- previousTicks.user
        totalSystem &+= currentTicks.system &- previousTicks.system
        totalIdle &+= currentTicks.idle &- previousTicks.idle
        totalNice &+= currentTicks.nice &- previousTicks.nice
    }

    let totalTicks = totalUser &+ totalSystem &+ totalIdle &+ totalNice
    guard totalTicks > 0 else {
        return CPUStatePercents(userPercent: 0, systemPercent: 0, idlePercent: 0)
    }

    return CPUStatePercents(
        userPercent: Double(totalUser) / Double(totalTicks) * 100,
        systemPercent: Double(totalSystem) / Double(totalTicks) * 100,
        idlePercent: Double(totalIdle) / Double(totalTicks) * 100
    )
}
