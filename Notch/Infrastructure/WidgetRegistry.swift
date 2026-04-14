/*
 
 Es la única clase de toda la aplicación que sabe qué widgets existen, en qué orden están y si están encendidos o apagados.
 
 */


import SwiftUI
import Combine

// @MainActor asegura que todos los cambios de esta clase se hagan en el hilo principal,
// lo cual es OBLIGATORIO en macOS cuando modificamos cosas que afectan a la interfaz gráfica.
@MainActor
class WidgetRegistry: ObservableObject {
    
    //El Gerente es único (Patrón Singleton)
    static let shared = WidgetRegistry()
    
    // Listas reactivas: Si cambian, la interfaz gráfica se redibuja sola
    @Published private(set) var orderedWidgets: [WidgetID] = []
    @Published private(set) var activeWidgets: Set<WidgetID> = []
    
    // Aquí guarda los "motores" de cada widget
    private var managers: [WidgetID: any NotchWidget] = [:]
    
    // Conecta al gerente con la memoria a largo plazo
    private var settings = AppSettings.shared
    
    private init() {
        // 1. Al arrancar, lee la memoria para ver cómo lo dejó el usuario la última vez
        orderedWidgets = settings.widgetOrder
        activeWidgets  = Set(settings.enabledWidgets)
        
        // 2. Enchufo los modulos
         register(NowPlayingManager())
         register(CalendarWidgetManager())
         register(CameraManager())
        // register(DropzoneManager())
        
        // 3. Enciende los motores de los widgets que estaban activos
        activeWidgets.forEach { activate($0) }
    }
    
    // Función para añadir un widget al registro
    private func register(_ widget: any NotchWidget) {
        managers[widget.id] = widget
    }
    
    // MARK: - API Pública (Lo que pueden usar otras partes de la app)
    
    // Enciende o apaga un widget (Se usará desde la pestaña de Ajustes)
    func setEnabled(_ id: WidgetID, enabled: Bool) {
        if enabled {
            activeWidgets.insert(id)
            activate(id)
        } else {
            activeWidgets.remove(id)
            deactivate(id)
        }
        // Guarda el cambio en el disco duro
        settings.enabledWidgets = Array(activeWidgets)
    }
    
    // Cambia el orden de los widgets (Se usará al arrastrar y soltar en Ajustes)
    func move(from source: IndexSet, to destination: Int) {
        orderedWidgets.move(fromOffsets: source, toOffset: destination)
        // Guarda el nuevo orden en el disco duro
        settings.widgetOrder = orderedWidgets
    }
    
    // Intercambia la posición de dos widgets
    func swapWidgets(_ id1: WidgetID, _ id2: WidgetID) {
        guard let idx1 = orderedWidgets.firstIndex(of: id1),
              let idx2 = orderedWidgets.firstIndex(of: id2) else { return }
        
        orderedWidgets.swapAt(idx1, idx2)
        // Guardamos el nuevo orden en el disco duro
        AppSettings.shared.widgetOrder = orderedWidgets
    }
    
    // Devuelve el motor de un widget específico para que la vista lo dibuje
    func manager(for id: WidgetID) -> (any NotchWidget)? {
        managers[id]
    }
    
    // MARK: - Ciclo de vida interno
    
    private func activate(_ id: WidgetID) {
        managers[id]?.activate()
    }
    
    private func deactivate(_ id: WidgetID) {
        managers[id]?.deactivate()
    }
}
