import SwiftUI

//Esto elimina la ventana en blanco de raíz. El AppDelegate es ahora el único responsable de crear ventanas.
@main
struct NotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        // Al usar Settings con EmptyView, le decimos a macOS que no queremos ventana por defecto.
        Settings {
            EmptyView()
        }
    }
}
