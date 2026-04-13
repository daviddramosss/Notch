/*
 
 AppSettings es la memoria a largo plazo de tu aplicación.

 Si no tuviéramos este archivo, cada vez que cerraras la aplicación y la volvieras a abrir, el Mac olvidaría cómo habías
 configurado tu notch. Si habías decidido apagar la cámara y poner el panel a 400 píxeles de ancho, al reiniciar volvería a estar
 la cámara encendida y el panel a 320 píxeles.

 AppSettings soluciona esto usando una herramienta mágica de Apple llamada @AppStorage.

 ¿Qué hace @AppStorage? Guarda automáticamente cualquier variable directamente en el disco duro de tu Mac (en un archivo del
 sistema llamado UserDefaults). No tienes que darle a "Guardar", se hace solo en tiempo real.

 El truco de la traducción: El disco duro de Mac es un poco tonto y solo sabe guardar cosas simples (texto o números). No sabe
 guardar listas complejas de Swift (Arrays). Por eso, en el código, cogemos tu lista de widgets activos [camera, nowPlaying] y la
 convertimos en un texto simple "camera,now_playing" para guardarla. Cuando abres la app, AppSettings lee ese texto y lo vuelve a
 convertir en una lista para que el resto del código lo entienda.

 El patrón "Singleton" (static let shared): Esto asegura que solo exista una copia de los ajustes en toda la app. Si la ventana de
 preferencias cambia el tamaño, el notch lee exactamente de la misma hoja de papel y se actualiza al instante.
 */

import SwiftUI
import Combine

// MARK: - CLASE PRINCIPAL DE AJUSTES
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // --------------------------------------------------------
    // 1. ESTADO Y ORDEN DE LOS WIDGETS (Sincronizado con tu Enum)
    // Por defecto: Música, Calendario y Cámara (Espejo)
    @AppStorage("enabled_widgets_raw") private var enabledWidgetsRaw: String = "[\"now_playing\", \"calendar\", \"camera\"]"
    
    var enabledWidgets: [WidgetID] {
        get {
            guard let data = enabledWidgetsRaw.data(using: .utf8),
                  let stringArray = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return stringArray.compactMap { WidgetID(rawValue: $0) }
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue.map { $0.rawValue }),
               let str = String(data: encoded, encoding: .utf8) {
                enabledWidgetsRaw = str
            }
        }
    }
    
    @AppStorage("widget_order_raw") private var widgetOrderRaw: String = "[\"now_playing\", \"calendar\", \"camera\", \"dropzone\", \"shortcuts\", \"system_monitor\"]"
    
    var widgetOrder: [WidgetID] {
        get {
            guard let data = widgetOrderRaw.data(using: .utf8),
                  let stringArray = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return stringArray.compactMap { WidgetID(rawValue: $0) }
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue.map { $0.rawValue }),
               let str = String(data: encoded, encoding: .utf8) {
                widgetOrderRaw = str
            }
        }
    }

    // --------------------------------------------------------
    // 2. SISTEMA DE ANCHOS VARIABLES
    @AppStorage("widget_widths_raw") private var widgetWidthsRaw: String = "{}"
    
    var widgetWidths: [String: Double] {
        get {
            guard let data = widgetWidthsRaw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue),
               let str = String(data: encoded, encoding: .utf8) {
                widgetWidthsRaw = str
            }
        }
    }
    
    // --------------------------------------------------------
    // 3. APARIENCIA DEL NOTCH
    @AppStorage("expanded_height") var expandedHeight: Double = 160.0
    @AppStorage("corner_radius") var cornerRadius: Double = 30.0
    @AppStorage("background_opacity") var backgroundOpacity: Double = 1.0
    @AppStorage("accent_color_option") var accentColorOption: AccentColorOption = .white
    
    // --------------------------------------------------------
    // 4. GESTOS Y COMPORTAMIENTO
    @AppStorage("hover_expand_delay") var hoverExpandDelay: Double = 0.0
    @AppStorage("hover_collapse_delay") var hoverCollapseDelay: Double = 0.3
    @AppStorage("activation_mode") var activationMode: ActivationMode = .hover
    
    // --------------------------------------------------------
    // 5. OPCIONES ESPECÍFICAS DE CADA MÓDULO
    @AppStorage("np_show_artwork") var nowPlayingShowArtwork: Bool = true
    @AppStorage("np_show_progress") var nowPlayingShowProgress: Bool = true
    @AppStorage("np_show_controls") var nowPlayingShowControls: Bool = true
    
    @AppStorage("cal_days_ahead") var calendarDaysAhead: Int = 1
    @AppStorage("cal_show_allday") var calendarShowAllDay: Bool = true
    
    @AppStorage("sys_show_cpu") var systemShowCPU: Bool = true
    @AppStorage("sys_show_ram") var systemShowRAM: Bool = true
    @AppStorage("sys_show_airpods") var systemShowAirPods: Bool = true
    
    // --------------------------------------------------------
    // 6. GENERALES
    @AppStorage("launch_at_login") var launchAtLogin: Bool = false
    @AppStorage("show_menu_bar_icon") var showMenuBarIcon: Bool = true
    @AppStorage("useMaterialBackground") var useMaterialBackground: Bool = true
}

// MARK: - ENUMS
enum ActivationMode: String, Codable { case hover, click, doubleClick }
enum AccentColorOption: String, CaseIterable, Codable {
    case white, blue, purple, pink, green, orange
    var color: Color {
        switch self {
        case .white: return .white
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .green: return .green
        case .orange: return .orange
        }
    }
}

// MARK: - EXTENSIÓN VISUAL
// Usamos los cases tal cual los tienes definidos en tu Enum
extension WidgetID {
    var displayName: String {
        switch self {
        case .nowPlaying: return "Media Player"
        case .camera: return "Espejo"
        case .calendar: return "Calendario"
        case .dropzone: return "Bandeja"
        case .shortcuts: return "Atajos"
        case .systemMonitor: return "Sistema"
        }
    }
    
    var icon: String {
        switch self {
        case .nowPlaying: return "music.note"
        case .camera: return "camera.fill"
        case .calendar: return "calendar"
        case .dropzone: return "tray.fill"
        case .shortcuts: return "bolt.fill"
        case .systemMonitor: return "cpu"
        }
    }
    
    var subtitle: String {
        switch self {
        case .nowPlaying: return "Spotify, Apple Music"
        case .camera: return "Feed de vídeo en vivo"
        case .calendar: return "Próximos eventos"
        case .dropzone: return "Arrastrar archivos"
        case .shortcuts: return "Atajos del sistema"
        case .systemMonitor: return "Estadísticas arriba"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .nowPlaying: return .pink
        case .camera: return .purple
        case .calendar: return .blue
        case .dropzone: return .orange
        case .shortcuts: return .yellow
        case .systemMonitor: return .green
        }
    }
}
