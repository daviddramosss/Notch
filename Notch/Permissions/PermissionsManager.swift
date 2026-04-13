import AVFoundation
import EventKit
import SwiftUI
import Combine
import CoreBluetooth

enum PermissionState {
    case notDetermined, granted, denied
}

@MainActor
class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published var camera: PermissionState = .notDetermined
    @Published var calendar: PermissionState = .notDetermined
    @Published var bluetooth: PermissionState = .notDetermined
    
    private init() { refreshAll() }
    
    func refreshAll() {
        camera = cameraStatus()
        calendar = calendarStatus()
        bluetooth = bluetoothStatus()
    }
    
    // Solicita permisos en orden — nunca dos diálogos simultáneos
    func requestAll() async {
        await requestCalendar()
        // await requestCamera() // Lo activaremos cuando hagamos la cámara
    }
    
    func requestCalendar() async {
        let store = EKEventStore()
        if #available(macOS 14.0, *) {
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            calendar = granted ? .granted : .denied
        } else {
            let granted = (try? await store.requestAccess(to: .event)) ?? false
            calendar = granted ? .granted : .denied
        }
    }
    
    // MARK: - Estado actual (sin pedir)
    private func cameraStatus() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }
    
    private func calendarStatus() -> PermissionState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }
    
    //Lector de estado del Bluetooth
        private func bluetoothStatus() -> PermissionState {
            if #available(macOS 10.15, *) {
                switch CBManager.authorization {
                case .allowedAlways: return .granted
                case .denied, .restricted: return .denied
                default: return .notDetermined
                }
            } else {
                return .granted
            }
        }
}
