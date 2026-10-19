// BluetoothManager.swift

import Foundation
import Combine
import IOBluetooth

class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()
    
    @Published var airpods = AirPodsInfo()
    
    // Timer de detección de conexión (cada 3s)
    private var pollTimer: Timer?
    
    // Timer de lectura de batería (cada 30s, solo cuando el dropdown está abierto)
    private var batteryTimer: Timer?
    
    override init() {
        super.init()
    }
    
    // MARK: - Ciclo principal (sin cambios respecto a la versión anterior)
    
    func startMonitoring() {
        checkConnection()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkConnection()
        }
    }
    
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        stopBatteryUpdates()  // por defensividad
    }
    
    // MARK: - Detección de conexión
    
    private func checkConnection() {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        
        let connected = devices.first {
            $0.isConnected() && ($0.nameOrAddress.contains("AirPods") || $0.nameOrAddress.contains("Beats"))
        }
        
        DispatchQueue.main.async {
            if let device = connected {
                self.airpods.isConnected = true
                self.airpods.name = device.name ?? "AirPods"
            } else {
                // [Validación 1] Si se desconectan, limpiamos también la batería
                self.airpods.isConnected = false
                self.airpods.leftBattery = nil
                self.airpods.rightBattery = nil
                self.airpods.caseBattery = nil
            }
        }
    }
    
    // MARK: - Polling de batería (on-demand)
    
    /// Llamar cuando el desplegable se abre.
    /// Lectura inmediata + timer cada 30s mientras esté abierto.
    func startBatteryUpdates() {
           
            refreshBatteryLevels()
            
            batteryTimer?.invalidate()
            batteryTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                self?.refreshBatteryLevels()
            }
        }
    
        func stopBatteryUpdates() {
            batteryTimer?.invalidate()
            batteryTimer = nil
        }
        
        private func refreshBatteryLevels() {
           
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let result = AirPodsBatteryReader.read()
                
                
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.airpods.leftBattery = result?.left
                    self.airpods.rightBattery = result?.right
                    self.airpods.caseBattery = result?.caseLevel
                }
            }
        }
}
