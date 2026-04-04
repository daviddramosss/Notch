import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    // Instanciamos el Cerebro (ViewModel)
    var panelViewModel = PanelViewModel()
    
    // Instanciamos nuestros controladores
    var windowController: PanelWindowController!
    var hoverDetector: HoverDetector!
    
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Arrancamos la ventana (le pasamos el Cerebro)
        windowController = PanelWindowController(viewModel: panelViewModel)
        
        // 2. Arrancamos el detector de ratón (le pasamos la ventana física y el Cerebro)
        hoverDetector = HoverDetector(panel: windowController.panel, viewModel: panelViewModel)
        
        // 3. Activamos el icono de la barra de menú para poder cerrar la app
        setupMenuBarIcon()
    }
    
    @objc private func openSettings() {
        print("Abriendo ajustes en la Fase 2...")
        // Aquí es donde llamaremos al SettingsWindowController más adelante
    }

    private func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Notch")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Ajustes...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
}
