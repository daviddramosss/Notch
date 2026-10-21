import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    var panelViewModel = PanelViewModel()
    var windowController: PanelWindowController!
    var hoverDetector: HoverDetector!
    
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateOtherInstances()
        
        windowController = PanelWindowController(viewModel: panelViewModel)
        hoverDetector = HoverDetector(panel: windowController.panel, viewModel: panelViewModel)
        
        setupStatusItem()
        
        Task {
            await PermissionsManager.shared.runStartupSequence()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: NSNotification.Name("OpenSettingsWindow"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: "Notch")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Ajustes...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Cerrar Notch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
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

    private func terminateOtherInstances() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        guard !bundleID.isEmpty else { return }
        
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        for app in runningApps where app.processIdentifier != currentPID {
            app.terminate()
        }
    }
}
