import Foundation

struct MetricsSnapshot {
    var cpu: CPUSnapshot
    var memory: MemorySnapshot
    var network: NetworkSnapshot
    var thermal: ThermalSnapshot
}
