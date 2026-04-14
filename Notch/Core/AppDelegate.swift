import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    // Instancio el Cerebro (ViewModel)
    var panelViewModel = PanelViewModel()
    
    // Instancio loa controladores
    var windowController: PanelWindowController!
    var hoverDetector: HoverDetector!
    
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController = PanelWindowController(viewModel: panelViewModel)
        hoverDetector = HoverDetector(panel: windowController.panel, viewModel: panelViewModel)
        
        AutomationPermissionManager.shared.requestAllPermissions()
        
        Task {
            await PermissionsManager.shared.requestAll()
        }
        
        //Escucha si alguien pulsa el engranaje del Notch
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: NSNotification.Name("OpenSettingsWindow"),
            object: nil
        )
    }
    
    // Limpio la memoria si la app se cierra
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // La función que crea y abre la ventana de ajustes
    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView().environmentObject(WidgetRegistry.shared)
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 550),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "Ajustes de Notch"
            settingsWindow?.contentView = NSHostingView(rootView: view)
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

   
}
