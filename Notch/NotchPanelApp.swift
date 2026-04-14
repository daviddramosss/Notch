import SwiftUI

//Esto elimina la ventana en blanco de raíz. El AppDelegate es ahora el único responsable de crear ventanas.
@main
struct NotchPanelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
