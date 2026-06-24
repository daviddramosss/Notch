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
        
        // --- SOLUCIÓN AL ICONO INVISIBLE ---
        // 1. Creo el espacio en la barra de menú
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 2. Le pongo un icono (puedes cambiar "menubar.rectangle" por "gearshape.fill" si prefieres)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: "Notch")
        }
        
        // 3. Le añado un menú desplegable para controlarlo
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Ajustes...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Cerrar Notch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        // ---------------------------------------
        
        
        Task {
            await PermissionsManager.shared.runStartupSequence()
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
