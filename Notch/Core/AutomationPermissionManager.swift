import AppKit
import Carbon

class AutomationPermissionManager {
    static let shared = AutomationPermissionManager()
    private init() {}
    
    // Bundle IDs oficiales de las apps
    enum TargetApp: String, CaseIterable {
        case spotify = "com.spotify.client"
        case appleMusic = "com.apple.Music"
        
        var displayName: String {
            switch self {
            case .spotify: return "Spotify"
            case .appleMusic: return "Apple Music"
            }
        }
    }
    
    // MARK: - API pública
    func requestAllPermissions() {
        for app in TargetApp.allCases {
            requestPermission(for: app)
        }
    }
    
    func requestPermission(for app: TargetApp) {
        // macOS ignora la petición si la app no está abierta en este instante
        guard isRunning(app) else {
            print("⚠️ \(app.displayName) no está en ejecución — no se puede pedir permiso ahora")
            return
        }
        _ = checkPermission(for: app, askUserIfNeeded: true)
    }
    
    // MARK: - Implementación Robusta (Carbon API)
    private func checkPermission(for app: TargetApp, askUserIfNeeded: Bool) -> Bool {
        let bundleID = app.rawValue
        var targetAddress = AEAddressDesc()
        var err: OSStatus = noErr
        
        // Forma segura de pasar un string de Swift a C
        bundleID.withCString { cString in
            // Envuelta la función en OSStatus() para igualar el tamaño
            err = OSStatus(AECreateDesc(
                typeApplicationBundleID,
                cString,
                bundleID.utf8.count,
                &targetAddress
            ))
        }
        
        guard err == noErr else {
            print("❌ Error creando descriptor para \(app.displayName)")
            return false
        }
        
        defer { AEDisposeDesc(&targetAddress) }
        
        //Esto fuerza el popup nativo de macOS
        err = AEDeterminePermissionToAutomateTarget(
            &targetAddress,
            typeWildCard,
            typeWildCard,
            askUserIfNeeded
        )
        
        switch err {
        case noErr:
            print("✅ Permiso concedido para \(app.displayName)")
            return true
        case OSStatus(-1744):
            print("❌ Permiso denegado para \(app.displayName)")
            return false
        default:
            return false
        }
    }
    
    private func isRunning(_ app: TargetApp) -> Bool {
        return NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == app.rawValue
        }
    }
}
