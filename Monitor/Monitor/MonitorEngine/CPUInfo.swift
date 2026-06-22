import Foundation

/// Raw CPU tick counts needed for delta calculation
struct CPUResult {
    var user: UInt64 = 0
    var system: UInt64 = 0
    var idle: UInt64 = 0
    var nice: UInt64 = 0

    nonisolated init(user: UInt64 = 0, system: UInt64 = 0, idle: UInt64 = 0, nice: UInt64 = 0) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

nonisolated func collectCPUInfo(previousTicks: [CPUResult]? = nil) -> (snapshot: CPUSnapshot, ticks: [CPUResult]) {
    var cpuCount = mach_msg_type_number_t(0)
    var infoCount = mach_msg_type_number_t(0)
    var cpuInfo: processor_info_array_t?

    let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &cpuInfo, &infoCount)

    guard result == KERN_SUCCESS, let info = cpuInfo else {
        let snap = CPUSnapshot(usagePercent: 0, perCoreUsage: [], systemPercent: 0, userPercent: 0, idlePercent: 0, timestamp: Date())
        let empty = (0..<Int(cpuCount)).map { _ in CPUResult() }
        return (snap, empty)
    }

    let count = Int(cpuCount)
    let buf = UnsafeBufferPointer(start: info, count: Int(infoCount))
    let stateCount = Int(CPU_STATE_MAX)
    let minOffset = Int(CPU_STATE_IDLE)

    var currentTicks: [CPUResult] = []

    for i in 0..<count {
        let offset = i * stateCount
        guard offset + minOffset < buf.count else {
            currentTicks.append(CPUResult())
            continue
        }
        currentTicks.append(CPUResult(
            user:   UInt64(buf[offset + Int(CPU_STATE_USER)]),
            system: UInt64(buf[offset + Int(CPU_STATE_SYSTEM)]),
            idle:   UInt64(buf[offset + Int(CPU_STATE_IDLE)]),
            nice:   UInt64(buf[offset + Int(CPU_STATE_NICE)])
        ))
    }

    if infoCount > 0 {
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.size))
    }

    let usage = calculateCPUUsage(previous: previousTicks, current: currentTicks)
    let statePercents = calculateCPUStatePercents(previous: previousTicks, current: currentTicks)

    let snap = CPUSnapshot(
        usagePercent: usage.usagePercent,
        perCoreUsage: usage.perCoreUsage,
        systemPercent: statePercents.systemPercent,
        userPercent: statePercents.userPercent,
        idlePercent: statePercents.idlePercent,
        timestamp: Date()
    )
    return (snap, currentTicks)
}

private extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
