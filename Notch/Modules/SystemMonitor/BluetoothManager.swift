/*
 
 Este archivo usa las librerías IOBluetooth (para saber si hay cascos conectados) y IOKit (para escarbar en el sistema y sacar el
 porcentaje exacto de batería de cada auricular).
 
 */
import Foundation
import Combine
import IOBluetooth

class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()
    
    @Published var airpods = AirPodsInfo()
    private var pollTimer: Timer?
    
    override init() {
        super.init()
    }
    
    func startMonitoring() {
        checkConnection()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkConnection()
        }
    }
    
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private func checkConnection() {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        guard let device = devices.first(where: {
            $0.isConnected() && ($0.nameOrAddress.contains("AirPods") || $0.nameOrAddress.contains("Beats"))
        }) else {
            DispatchQueue.main.async { self.airpods.isConnected = false }
            return
        }
        
        DispatchQueue.main.async {
            self.airpods.isConnected = true
            self.airpods.name = device.name ?? "AirPods"
        }
    }
}
