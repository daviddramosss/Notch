// AirPodsInfo.swift

import Foundation

struct AirPodsInfo {
    var name: String = "AirPods"
    var leftBattery: Int?
    var rightBattery: Int?
    var caseBattery: Int?
    var isConnected: Bool = false
    
    var hasAnyBatteryData: Bool {
        leftBattery != nil || rightBattery != nil || caseBattery != nil
    }
}
