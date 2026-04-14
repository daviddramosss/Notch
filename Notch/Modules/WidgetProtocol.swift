import SwiftUI

// 1. EL "DNI" DE LOS WIDGETS
// Enumera todos los módulos que existirán en la app.
// CaseIterable permite hacer bucles con ellos, y Codable permite guardarlos en disco.
enum WidgetID: String, CaseIterable, Codable {
    case nowPlaying  = "now_playing"
    case camera      = "camera"
    case calendar    = "calendar"
    case dropzone    = "dropzone"
    case shortcuts   = "shortcuts"
    case systemMonitor = "system_monitor"
}

// 2. EL CONTRATO (Protocol)
// Cualquier cosa que quiera ser un "Widget" TIENE que cumplir estas normas.
// ObservableObject permite que la vista se actualice si los datos del manager cambian.
protocol NotchWidget: ObservableObject {
    var id: WidgetID { get }
    var title: String { get }               // Nombre que saldrá en los Ajustes (ej: "Spotify")
    var isEnabled: Bool { get set }         // Está encendido o apagado?
    var requiresPermission: Bool { get }    // Necesita pedir permiso a macOS? (Cámara sí, Spotify no)
    
    // Funciones de ciclo de vida
    func activate()     // Se llama al encender el botón: Arranca motores (ej: enciende la cámara)
    func deactivate()   // Se llama al apagar el botón: Mata los procesos para no gastar batería
    
    // La vista visual que se inyectará en el Notch
    associatedtype WidgetView: View
    func makeView() -> WidgetView
}
