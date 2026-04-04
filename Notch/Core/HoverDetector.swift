//
//  HoverDetector.swift
//  Notch
//
//  Created by David Ramos on 04/04/2026.
//

/*
 
 Este será el archivo más complejo. Usará herramientas del sistema para saber dónde está la flecha de tu ratón en todo momento.
 Por qué: Como nuestro panel está oculto y no roba el foco de otras aplicaciones, necesitamos un "vigilante" global que avise al
 "Cerebro" cuando el ratón toca el borde superior de tu pantalla.
 
 */

import AppKit
import Combine
import SwiftUI

class HoverDetector {
    private weak var panel: NSPanel?
    private weak var viewModel: PanelViewModel?
    private var globalMonitor: Any?
    
    // Guardamos el estado anterior para no saturar el procesador de tu M5
    // calculando cada milímetro que mueves el ratón.
    private var wasInside: Bool = false

    init(panel: NSPanel, viewModel: PanelViewModel) {
        self.panel = panel
        self.viewModel = viewModel
        setupGlobalMonitor()
    }

    deinit {
        // Limpieza: si la app se cierra, dejamos de espiar al ratón
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupGlobalMonitor() {
        // Este monitor "escucha" el ratón a nivel de sistema (incluso si estás usando Safari o Chrome)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMovement()
        }
        
        // También escuchamos cuando nuestra propia app tiene el foco
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMovement()
            return event
        }
    }

    private func handleMouseMovement() {
        guard let panel = panel, let viewModel = viewModel else { return }
        
        // Obtenemos las coordenadas exactas del ratón en la pantalla
        let mouseLocation = NSEvent.mouseLocation
        
        // ¿Está el ratón dentro del rectángulo de nuestro panel?
        let isInside = panel.frame.contains(mouseLocation)

        // Si el estado no ha cambiado (sigue dentro, o sigue fuera), no hacemos nada
        guard isInside != wasInside else { return }
        wasInside = isInside

        // Si el estado cambia, le avisamos al "Cerebro" (ViewModel)
        DispatchQueue.main.async {
            // Usamos una animación suave para que el cambio no sea brusco
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.isExpanded = isInside
            }
        }
    }
}
