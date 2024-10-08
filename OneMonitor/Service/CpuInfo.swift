import Darwin

final class CpuInfo {
    
    var percentage: Double = 0.0
    var system: String = ""
    var user: String = ""
    var idle: String = ""
    
    private init() {}
    
    static let shared = CpuInfo()
    
    private let loadInfoCount: mach_msg_type_number_t = UInt32(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
    private var loadPrevious = host_cpu_load_info()
    private var isFirstLoad = true
    
    private func hostCPULoadInfo() -> host_cpu_load_info {
        var size: mach_msg_type_number_t = loadInfoCount
        let hostInfo = host_cpu_load_info_t.allocate(capacity: 1)
        let _ = hostInfo.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { (pointer) -> kern_return_t in
            return host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, pointer, &size)
        }
        let data = hostInfo.move()
        hostInfo.deallocate()
        return data
    }
    
    func update() {
        let load = hostCPULoadInfo()
        
        if isFirstLoad {
            // 第一次加载数据时，不计算 CPU 使用率，只更新 loadPrevious
            loadPrevious = load
            isFirstLoad = false
            return
        }
        
        let userDiff    = Double(load.cpu_ticks.0 - loadPrevious.cpu_ticks.0)
        let systemDiff  = Double(load.cpu_ticks.1 - loadPrevious.cpu_ticks.1)
        let idleDiff    = Double(load.cpu_ticks.2 - loadPrevious.cpu_ticks.2)
        let niceDiff    = Double(load.cpu_ticks.3 - loadPrevious.cpu_ticks.3)
        loadPrevious    = load
        
        let totalTicks = systemDiff + userDiff + idleDiff + niceDiff
        
        // Check if totalTicks is zero to avoid division by zero
        if totalTicks == 0 {
            self.percentage = 0.0
            self.system     = "0.0 %"
            self.user       = "0.0 %"
            self.idle       = "0.0 %"
            return
        }
        
        let system     = 100.0 * systemDiff / totalTicks
        let user       = 100.0 * userDiff / totalTicks
        let idle       = 100.0 * idleDiff / totalTicks
        
        self.percentage = round(min(99.9, (system + user)) * 100) / 100
        self.system     = "\(round(system * 100) / 100) %"
        self.user       = "\(round(user * 100) / 100) %"
        self.idle       = "\(round(idle * 100) / 100) %"
    }
    
}
