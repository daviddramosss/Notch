/*
 Este es el "Cerebro Sensorial" de la app.
 Ahora no solo detecta el ratón, sino que lee tus Ajustes en tiempo real para saber
 si debe esperar (Hover Delay), o si debe reaccionar solo a Clics o Dobles Clics.
*/

import AppKit
import Combine
import SwiftUI

class HoverDetector {
    private weak var panel: NSPanel?
    private weak var viewModel: PanelViewModel?
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    // Control de estado para no saturar el procesador
    private var wasInside: Bool = false
    
    // Temporizador para el "Hover Delay"
    private var expandTimer: Timer?

    init(panel: NSPanel, viewModel: PanelViewModel) {
        self.panel = panel
        self.viewModel = viewModel
        setupMonitors()
    }

    deinit {
        if let gMonitor = globalMonitor { NSEvent.removeMonitor(gMonitor) }
        if let lMonitor = localMonitor { NSEvent.removeMonitor(lMonitor) }
        expandTimer?.invalidate()
    }

    private func setupMonitors() {
        // Añadimos .leftMouseDown al radar para detectar los clics
        let eventsToWatch: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown]
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventsToWatch) { [weak self] event in
            self?.handleMouseEvent(event)
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventsToWatch) { [weak self] event in
            self?.handleMouseEvent(event)
            return event
        }
    }

    private func handleMouseEvent(_ event: NSEvent) {
        guard let panel = panel, let viewModel = viewModel else { return }
        
        // 1. ¿Dónde está el ratón y qué modo tenemos seleccionado?
        let isInside = panel.frame.contains(NSEvent.mouseLocation)
        let mode = AppSettings.shared.activationMode
        
        // 2. LÓGICA DE CLICS
        if event.type == .leftMouseDown {
            if isInside {
                if mode == .click {
                    setExpanded(true)
                } else if mode == .doubleClick && event.clickCount == 2 {
                    setExpanded(true)
                }
                // (Si es modo Hover, hacer clic también lo abre por comodidad)
                if mode == .hover {
                    setExpanded(true)
                }
            } else {
                // Si haces clic fuera del panel, lo cerramos siempre
                setExpanded(false)
            }
        }
        
        // 3. LÓGICA DE MOVIMIENTO (Hover y Auto-Cierre)
        if event.type == .mouseMoved || event.type == .leftMouseDragged {
            // Solo actuamos si el ratón cruza la frontera (entra o sale)
            if isInside != wasInside {
                wasInside = isInside
                
                if isInside {
                    // El ratón acaba de ENTRAR
                    if mode == .hover {
                        startHoverTimer()
                    }
                } else {
                    // El ratón acaba de SALIR
                    cancelHoverTimer()
                    // Auto-colapso al salir (funciona para todos los modos para que no se quede atascado abierto)
                    setExpanded(false)
                }
            }
        }
    }
    
    // MARK: - Helpers del Temporizador y Animación
    
    private func startHoverTimer() {
        let delay = AppSettings.shared.hoverExpandDelay
        
        if delay <= 0 {
            // Si el delay es 0, abrimos al instante
            setExpanded(true)
        } else {
            // Si hay delay, programamos la apertura
            expandTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.setExpanded(true)
            }
        }
    }
    
    private func cancelHoverTimer() {
        expandTimer?.invalidate()
        expandTimer = nil
    }
    
    private func setExpanded(_ expand: Bool) {
        // Solo animamos si realmente hay un cambio de estado
        guard viewModel?.isExpanded != expand else { return }
        
        DispatchQueue.main.async { [weak self] in
            // Usamos la misma animación elástica que definimos en la Fase 3
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                self?.viewModel?.isExpanded = expand
            }
        }
    }
}
