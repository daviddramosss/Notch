// WidgetRegistry.swift
// Registro central que gestiona el orden, estado de activación y ciclo de vida de los widgets.

import SwiftUI
import Combine

@MainActor
class WidgetRegistry: ObservableObject {
    
    static let shared = WidgetRegistry()
    
    @Published private(set) var orderedWidgets: [WidgetID] = []
    @Published private(set) var activeWidgets: Set<WidgetID> = []
    
    private var managers: [WidgetID: any NotchWidget] = [:]
    private var settings = AppSettings.shared
    
    private init() {
        orderedWidgets = settings.widgetOrder
        activeWidgets  = Set(settings.enabledWidgets)
        
        register(NowPlayingManager())
        register(CalendarWidgetManager())
        register(CameraManager())
        // register(DropzoneManager())
        
        activeWidgets.forEach { activate($0) }
    }
    
    private func register(_ widget: any NotchWidget) {
        managers[widget.id] = widget
    }
    
    // MARK: - API Pública
    
    func setEnabled(_ id: WidgetID, enabled: Bool) {
        if enabled {
            activeWidgets.insert(id)
            activate(id)
        } else {
            activeWidgets.remove(id)
            deactivate(id)
        }
        settings.enabledWidgets = Array(activeWidgets)
    }
    
    func move(from source: IndexSet, to destination: Int) {
        orderedWidgets.move(fromOffsets: source, toOffset: destination)
        settings.widgetOrder = orderedWidgets
    }
    
    func swapWidgets(_ id1: WidgetID, _ id2: WidgetID) {
        guard let idx1 = orderedWidgets.firstIndex(of: id1),
              let idx2 = orderedWidgets.firstIndex(of: id2) else { return }
        
        orderedWidgets.swapAt(idx1, idx2)
        AppSettings.shared.widgetOrder = orderedWidgets
    }
    
    func manager(for id: WidgetID) -> (any NotchWidget)? {
        managers[id]
    }
    
    // MARK: - Ciclo de vida
    
    private func activate(_ id: WidgetID) {
        managers[id]?.activate()
    }
    
    private func deactivate(_ id: WidgetID) {
        managers[id]?.deactivate()
    }
}
