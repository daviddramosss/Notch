// AirPodsBatteryReader.swift

import Foundation
import IOKit

enum AirPodsBatteryReader {
    
    static func read() -> (left: Int?, right: Int?, caseLevel: Int?)? {
        let port: mach_port_t
        if #available(macOS 12.0, *) {
            port = kIOMainPortDefault
        } else {
            port = kIOMasterPortDefault
        }
        
        guard let matchingDict = IOServiceMatching("AppleDeviceManagementHIDEventService") else {
            return nil
        }
        
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(port, matchingDict, &iterator)
        guard kr == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            
            let left  = readIntProperty(service, key: "BatteryPercentLeft")
            let right = readIntProperty(service, key: "BatteryPercentRight")
            let caseL = readIntProperty(service, key: "BatteryPercentCase")
            
            if left != nil || right != nil || caseL != nil {
                return (left, right, caseL)
            }
        }
        
        return nil
    }
    
    private static func readIntProperty(_ service: io_object_t, key: String) -> Int? {
        guard let cfValue = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else { return nil }
        
        if let intVal = cfValue as? Int { return intVal }
        if let numVal = cfValue as? NSNumber { return numVal.intValue }
        return nil
    }
}
