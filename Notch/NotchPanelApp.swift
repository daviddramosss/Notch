// NotchPanelApp.swift
// Punto de entrada de la aplicación. Delega el ciclo de vida y gestión de ventanas a AppDelegate.

import SwiftUI

@main
struct NotchPanelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
