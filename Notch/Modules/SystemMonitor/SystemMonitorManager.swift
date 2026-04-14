/*
 
 Este archivo usa comandos (lenguaje C) para leer el procesador y la memoria sin gastar apenas batería.
 
 */


import Foundation
import Combine
import SwiftUI
import Darwin // Necesario para hablar en el idioma base del procesador (mach)

class SystemMonitorManager: ObservableObject {
    
    @Published var stats = SystemStats()
    
    private var timer: Timer?
    private let hostCPU = mach_host_self()
    
    // Variables para calcular la CPU (necesita comparar el instante anterior con el actual)
    private var previousCPUInfo: processor_info_array_t?
    private var previousCPUInfoCount: mach_msg_type_number_t = 0
    
    // Arranca el motor: lee los datos cada 2 segundos
    func startMonitoring() {
        // Primera lectura inmediata
        updateStats()
        
        // Configura el reloj
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        
        // Limpia la memoria para evitar fugas (Memory Leaks)
        if let prevInfo = previousCPUInfo {
            let prevCpuInfoSize = Int(previousCPUInfoCount) * MemoryLayout<integer_t>.stride
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(prevCpuInfoSize))
            previousCPUInfo = nil
        }
    }
    
    private func updateStats() {
        // Lo ejecutamos en un hilo secundario para no congelar la app
        DispatchQueue.global(qos: .utility).async {
            let newCpu = self.fetchCPUUsage()
            let newRam = self.fetchRAMStats()
            
            // Volvemos al hilo principal para actualizar la pantalla
            DispatchQueue.main.async {
                self.stats.cpuUsage = newCpu
                self.stats.ramUsed = newRam.ramUsed
                self.stats.ramTotal = newRam.ramTotal
            }
        }
    }
    
    // MARK: - Lector de CPU
    private func fetchCPUUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        
        let result = host_processor_info(hostCPU, PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)
        
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else { return 0.0 }
        
        var totalUsage: Double = 0.0
        
        if let prevCPUInfo = previousCPUInfo {
            var totalUser: Int32 = 0
            var totalSystem: Int32 = 0
            var totalNice: Int32 = 0
            var totalIdle: Int32 = 0
            
            for i in 0..<Int(numCPUs) {
                let inUse = Int(CPU_STATE_MAX) * i
                
                let user = cpuInfo[inUse + Int(CPU_STATE_USER)] - prevCPUInfo[inUse + Int(CPU_STATE_USER)]
                let system = cpuInfo[inUse + Int(CPU_STATE_SYSTEM)] - prevCPUInfo[inUse + Int(CPU_STATE_SYSTEM)]
                let nice = cpuInfo[inUse + Int(CPU_STATE_NICE)] - prevCPUInfo[inUse + Int(CPU_STATE_NICE)]
                let idle = cpuInfo[inUse + Int(CPU_STATE_IDLE)] - prevCPUInfo[inUse + Int(CPU_STATE_IDLE)]
                
                totalUser += user
                totalSystem += system
                totalNice += nice
                totalIdle += idle
            }
            
            let total = totalUser + totalSystem + totalNice + totalIdle
            if total > 0 {
                totalUsage = Double(totalUser + totalSystem + totalNice) / Double(total)
            }
            
            // Limpia la memoria de la lectura anterior
            let prevCpuInfoSize = Int(previousCPUInfoCount) * MemoryLayout<integer_t>.stride
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevCPUInfo), vm_size_t(prevCpuInfoSize))
        }
        
        // Guarda la lectura actual para la próxima comparación
        previousCPUInfo = cpuInfo
        previousCPUInfoCount = numCPUInfo
        
        return min(totalUsage, 1.0)
    }
    
    // MARK: - Lector de RAM
    private func fetchRAMStats() -> SystemStats {
        var stats = SystemStats()
        
        // 1. Obtener RAM Total
        var memSize: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memSize, &size, nil, 0)
        stats.ramTotal = Double(memSize) / 1_073_741_824.0 // Convertimos Bytes a GB
        
        // 2. Obtener RAM Usada
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostCPU, HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = Double(vm_page_size)
            let active = Double(vmStats.active_count) * pageSize
            let wired = Double(vmStats.wire_count) * pageSize
            let compressed = Double(vmStats.compressor_page_count) * pageSize
            
            stats.ramUsed = (active + wired + compressed) / 1_073_741_824.0
        }
        
        return stats
    }
}
