import Foundation

nonisolated func collectSelfInfo(previousCPUTime: (total: UInt64, wall: UInt64)?) -> (snapshot: SelfSnapshot, cpuTime: (total: UInt64, wall: UInt64)) {
    let now = Date()

    var taskInfo = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let kr = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }

    let memoryMB: Double
    if kr == KERN_SUCCESS {
        memoryMB = Double(taskInfo.resident_size) / (1024.0 * 1024.0)
    } else {
        memoryMB = 0
    }

    var threadList: thread_act_array_t?
    var threadCount = mach_msg_type_number_t(0)
    let threadResult = task_threads(mach_task_self_, &threadList, &threadCount)

    var totalCPUTime: UInt64 = 0
    if threadResult == KERN_SUCCESS, let threads = threadList {
        for i in 0..<Int(threadCount) {
            var threadInfo = thread_basic_info_data_t()
            var threadInfoCount = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<integer_t>.size)

            let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(threadInfoCount)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }

            if infoResult == KERN_SUCCESS {
                let info = threadInfo as thread_basic_info
                if info.flags & TH_FLAGS_IDLE == 0 {
                    let userTime = UInt64(info.user_time.microseconds) + UInt64(info.user_time.seconds) * 1_000_000
                    let systemTime = UInt64(info.system_time.microseconds) + UInt64(info.system_time.seconds) * 1_000_000
                    totalCPUTime += userTime + systemTime
                }
            }
        }
        if threadCount > 0 {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threadList), vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride))
        }
    }

    let wallTime = UInt64(now.timeIntervalSince1970 * 1_000_000)
    var cpuPercent: Double = 0
    var powerMW: Double = 0

    if let (prevCPU, prevWall) = previousCPUTime {
        let cpuDelta = totalCPUTime > prevCPU ? totalCPUTime - prevCPU : 0
        let wallDelta = wallTime > prevWall ? wallTime - prevWall : 1
        cpuPercent = Double(cpuDelta) / Double(wallDelta) * 100.0
        cpuPercent = min(max(cpuPercent, 0), 100)

        let tdpEstimate: Double = 15.0
        powerMW = cpuPercent / 100.0 * tdpEstimate * 1000
    }

    return (
        snapshot: SelfSnapshot(
            memoryUsageMB: memoryMB,
            cpuUsagePercent: cpuPercent,
            powerEstimateMW: powerMW,
            timestamp: now
        ),
        cpuTime: (totalCPUTime, wallTime)
    )
}
