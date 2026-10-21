// PinnedAppsManager.swift

import SwiftUI
import AppKit
import Combine

@MainActor
class PinnedAppsManager: ObservableObject {
    static let shared = PinnedAppsManager()
    
    @Published var apps: [PinnedApp] = []
    @Published var runningBundleIDs: Set<String> = []
    
    private var observers: [NSObjectProtocol] = []
    
    private init() {
        self.apps = AppSettings.shared.pinnedApps
        updateRunningStatus()
        setupWorkspaceObservers()
    }
    
    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    // MARK: - Sincronización y Persistencia
    
    func reload() {
        self.apps = AppSettings.shared.pinnedApps
        updateRunningStatus()
    }
    
    private func save() {
        AppSettings.shared.pinnedApps = apps
    }
    
    // MARK: - Control de Ejecución (Lanzar o Enfocar)
    
    func launchApp(_ app: PinnedApp) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
            return
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        NSWorkspace.shared.openApplication(at: url, configuration: config) { [weak self] _, error in
            if error == nil {
                Task { @MainActor in
                    self?.updateRunningStatus()
                }
            }
        }
    }
    
    // MARK: - Estado de Ejecución en Tiempo Real
    
    func isRunning(_ app: PinnedApp) -> Bool {
        runningBundleIDs.contains(app.bundleIdentifier)
    }
    
    func terminateApp(_ app: PinnedApp) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier)
        for target in running {
            target.terminate()
        }
        updateRunningStatus()
    }
    
    func forceTerminateApp(_ app: PinnedApp) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier)
        for target in running {
            target.forceTerminate()
        }
        updateRunningStatus()
    }
    
    func hideApp(_ app: PinnedApp) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier)
        for target in running {
            target.hide()
        }
    }
    
    func restartApp(_ app: PinnedApp) {
        terminateApp(app)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.launchApp(app)
        }
    }
    
    func revealInFinder(_ app: PinnedApp) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    func unpinApp(_ app: PinnedApp) {
        toggleApp(id: app.id)
    }
    
    func isInstalled(_ app: PinnedApp) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) != nil
    }
    
    func icon(for app: PinnedApp) -> NSImage {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return NSWorkspace.shared.icon(forFileType: "app")
    }
    
    func updateRunningStatus() {
        let activeIDs = NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier }
        self.runningBundleIDs = Set(activeIDs)
    }
    
    // MARK: - Observadores Pasivos de NSWorkspace
    
    private func setupWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        
        let launchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               let bundleID = app.bundleIdentifier {
                self?.runningBundleIDs.insert(bundleID)
            }
        }
        
        let terminateObserver = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               let bundleID = app.bundleIdentifier {
                self?.runningBundleIDs.remove(bundleID)
            }
        }
        
        observers.append(contentsOf: [launchObserver, terminateObserver])
    }
    
    // MARK: - Gestión de Apps Ancladas
    
    var enabledCount: Int {
        apps.filter { $0.isEnabled }.count
    }
    
    func toggleApp(id: UUID) {
        if let index = apps.firstIndex(where: { $0.id == id }) {
            if !apps[index].isEnabled && enabledCount >= 2 {
                // Máximo 2 apps activas para no tocar el notch físico
                return
            }
            apps[index].isEnabled.toggle()
            save()
        }
    }
    
    func addApp(url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else { return }
        
        let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        
        if !apps.contains(where: { $0.bundleIdentifier == bundleID }) {
            // Si ya hay 2 activas, se añade desactivada por defecto
            let shouldEnable = enabledCount < 2
            apps.append(PinnedApp(name: name, bundleIdentifier: bundleID, isEnabled: shouldEnable))
            save()
            updateRunningStatus()
        }
    }
    
    func removeApp(id: UUID) {
        apps.removeAll { $0.id == id }
        save()
    }
}
