// PermissionsManager.swift
import AVFoundation
import EventKit
import SwiftUI
import Combine
import CoreBluetooth
import Carbon

enum PermissionState {
    case notDetermined, granted, denied
}

@MainActor
class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published private(set) var camera: PermissionState = .notDetermined
    @Published private(set) var calendar: PermissionState = .notDetermined
    @Published private(set) var bluetooth: PermissionState = .notDetermined
    
    // Flag para que la UI sepa cuándo terminó la secuencia inicial
    @Published private(set) var initialCheckComplete: Bool = false
    
    private let eventStore = EKEventStore()
    
    // Bundle IDs para Automation (absorbe AutomationPermissionManager)
    private static let automationTargets: [(bundleID: String, name: String)] = [
        ("com.spotify.client", "Spotify"),
        ("com.apple.Music", "Apple Music")
    ]
    
    private init() {
        // Solo lectura de estado — sin popups
        refreshStatuses()
    }
    
    // MARK: - Punto de entrada único (llamar desde AppDelegate)
    
    /// Ejecuta comprobaciones y peticiones en secuencia estricta.
    /// Nunca dos popups simultáneos. Solo pide si el estado es .notDetermined.
    func runStartupSequence() async {
        // 1. Lectura limpia del estado actual
        refreshStatuses()
        
        // 2. Pedir permisos TCC solo si no se han determinado, uno a uno
        if calendar == .notDetermined {
            await requestCalendar()
        }
        
        if camera == .notDetermined {
            await requestCamera()
        }
        
        // 3. Automation (Apple Events) — con pre-check sin popup
        await requestAutomationIfNeeded()
        
        // 4. Lectura final para reflejar cualquier cambio
        refreshStatuses()
        initialCheckComplete = true
    }
    
    // MARK: - Lectura pura de estado (sin popups, seguro en cualquier momento)
    
    func refreshStatuses() {
        camera = readCameraStatus()
        calendar = readCalendarStatus()
        bluetooth = readBluetoothStatus()
    }
    
    // MARK: - Peticiones individuales
    
    private func requestCalendar() async {
        if #available(macOS 14.0, *) {
            let granted = (try? await eventStore.requestFullAccessToEvents()) ?? false
            calendar = granted ? .granted : .denied
        } else {
            let granted = (try? await eventStore.requestAccess(to: .event)) ?? false
            calendar = granted ? .granted : .denied
        }
    }
    
    private func requestCamera() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        camera = granted ? .granted : .denied
    }
    
    /// Para Apple Events no existe authorizationStatus consultable.
    /// Usamos AEDeterminePermissionToAutomateTarget con askUserIfNeeded=false
    /// para comprobar sin popup. Solo pedimos si es indeterminado Y la app corre.
    private func requestAutomationIfNeeded() async {
        for target in Self.automationTargets {
            // Solo tiene sentido si la app está corriendo
            guard isAppRunning(bundleID: target.bundleID) else { continue }
            
            // Pre-check silencioso
            let status = checkAutomationPermission(bundleID: target.bundleID, ask: false)
            
            if status == .notDetermined {
                // Ahora sí pedimos — esto muestra el popup nativo de macOS
                _ = checkAutomationPermission(bundleID: target.bundleID, ask: true)
                
                // Pausa breve para que macOS procese el diálogo antes del siguiente
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
    
    // MARK: - Lectores de estado
    
    private func readCameraStatus() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }
    
    private func readCalendarStatus() -> PermissionState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }
    
    private func readBluetoothStatus() -> PermissionState {
        if #available(macOS 10.15, *) {
            switch CBManager.authorization {
            case .allowedAlways: return .granted
            case .denied, .restricted: return .denied
            default: return .notDetermined
            }
        }
        return .granted
    }
    
    // MARK: - Automation helpers (absorbe AutomationPermissionManager)
    
    private func checkAutomationPermission(bundleID: String, ask: Bool) -> PermissionState {
        var targetAddress = AEAddressDesc()
        var err: OSStatus = noErr
        
        bundleID.withCString { cString in
            err = OSStatus(AECreateDesc(
                typeApplicationBundleID,
                cString,
                bundleID.utf8.count,
                &targetAddress
            ))
        }
        
        guard err == noErr else { return .denied }
        defer { AEDisposeDesc(&targetAddress) }
        
        err = AEDeterminePermissionToAutomateTarget(
            &targetAddress,
            typeWildCard,
            typeWildCard,
            ask
        )
        
        switch err {
        case noErr:
            return .granted
        case OSStatus(-1744): // errAEEventNotPermitted
            return .denied
        default:
            return .notDetermined
        }
    }
    
    private func isAppRunning(bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}
