//
//  PanelWindowController.swift
//  Notch
//
//  Created by David Ramos on 04/04/2026.
//

/*
 
 PanelWindowController.swift. Este archivo actuará como el "conductor" de la ventana física. Él interactúa con AppKit (macOS puro)
 para calcular los píxeles exactos de tu notch y hacer que la ventana se expanda con una animación fluida (NSAnimationContext).
 
 */


import AppKit
import SwiftUI
import Combine

class PanelWindowController {
    var panel: NSPanel!
    var viewModel: PanelViewModel
    private var cancellables = Set<AnyCancellable>() // Para escuchar al Cerebro
    
    // El controlador de la ventana recibe el Cerebro (ViewModel) al nacer
    init(viewModel: PanelViewModel) {
        self.viewModel = viewModel
        setupPanel()
        setupBindings()
    }
    
    private func setupPanel() {
        guard let screen = NSScreen.main else { return }
        
        // 1. Calculamos el tamaño exacto inicial (colapsado)
        let initialRect = notchFrame(for: screen)
        
        // 2. Creamos la ventana física invisible
        panel = NSPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // 3. Propiedades para que flote y sea transparente
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        // 4. Inyectamos la vista visual (NotchPanelView) DENTRO de la ventana física
        let rootView = NotchPanelView().environmentObject(viewModel)
        panel.contentView = NSHostingView(rootView: rootView)
        panel.orderFrontRegardless()
    }
    
    // Esta función lee el hardware de tu Mac para buscar el Notch
    private func notchFrame(for screen: NSScreen) -> NSRect {
        // auxiliaryTopLeftArea nos dice dónde acaba el notch por la izquierda
        if let notchArea = screen.auxiliaryTopLeftArea {
            let rightArea = screen.auxiliaryTopRightArea ?? .zero
            // Calculamos el ancho restando los márgenes laterales al ancho total
            let notchWidth = screen.frame.width - notchArea.width - rightArea.width
            let notchX = notchArea.maxX
            
            // Guardamos esta altura real en el Cerebro para usarla luego
            viewModel.collapsedHeight = notchArea.height
            
            return NSRect(
                x: notchX,
                y: screen.frame.maxY - notchArea.height,
                width: notchWidth,
                height: notchArea.height
            )
        }
        
        // Plan B: Si conectas un monitor externo sin notch, crea una barra virtual de 200px
        let fallbackWidth: CGFloat = 200
        viewModel.collapsedHeight = 32
        return NSRect(
            x: screen.frame.midX - fallbackWidth / 2,
            y: screen.frame.maxY - 32,
            width: fallbackWidth,
            height: 32
        )
    }
    
    // Escuchamos los cambios del ViewModel
    private func setupBindings() {
        viewModel.$isExpanded
            // Ignoramos el primer valor al arrancar
            .dropFirst()
            // Cuando cambie el estado, ejecutamos la animación en el hilo principal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] expanded in
                self?.animatePanel(expand: expanded)
            }
            .store(in: &cancellables)
    }
    
    // La animación fluida del sistema
    private func animatePanel(expand: Bool) {
        guard let screen = NSScreen.main else { return }
            
            let targetFrame = expand ? expandedFrame(for: screen) : notchFrame(for: screen)
            
            // 1. Sincronizamos AppKit (El frame de la ventana)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                // Estos puntos de control imitan el efecto "bounce" de Apple
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1.0)
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(targetFrame, display: true)
            }
            
    }
    
    // Calcula hasta dónde tiene que bajar la ventana física al expandirse
    private func expandedFrame(for screen: NSScreen) -> NSRect {
        let collapsed = notchFrame(for: screen)
        return NSRect(
            x: collapsed.minX,
            y: collapsed.maxY - viewModel.expandedHeight,
            width: collapsed.width,
            height: viewModel.expandedHeight
        )
    }
}
