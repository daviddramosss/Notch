/*
 EXPLICACIÓN DE LA CLASE:
 Es el "Conductor" físico. Habla con AppKit para mover y cambiar el tamaño de la ventana.
 Gestiona el redondeo directamente en el CALayer de la ventana (CoreAnimation)
 aplicando una curva continua (.continuous) para el efecto squircle orgánico.
 */

import AppKit
import SwiftUI
import Combine

class PanelWindowController {
    var panel: NSPanel!
    var viewModel: PanelViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(viewModel: PanelViewModel) {
        self.viewModel = viewModel
        setupPanel()
        setupBindings()
    }
    
    private func setupPanel() {
        guard let screen = NSScreen.main else { return }
        let initialRect = notchFrame(for: screen)
        
        panel = NSPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        let rootView = NotchPanelView()
            .environmentObject(viewModel)
            .environmentObject(WidgetRegistry.shared)
        
        let hostingView = NSHostingView(rootView: rootView)
        panel.contentView = hostingView
        
        // Se enmascara el panel directamente para que la curva no se corte
        hostingView.wantsLayer = true
        hostingView.layer?.masksToBounds = true
        hostingView.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.cornerRadius = 12
        
        panel.orderFrontRegardless()
    }
    
    private func notchFrame(for screen: NSScreen) -> NSRect {
        if let notchArea = screen.auxiliaryTopLeftArea {
            let rightArea = screen.auxiliaryTopRightArea ?? .zero
            let notchWidth = screen.frame.width - notchArea.width - rightArea.width
            let notchX = notchArea.maxX
            
            viewModel.collapsedHeight = notchArea.height
            viewModel.collapsedWidth = notchWidth
            
            return NSRect(
                x: notchX,
                y: screen.frame.maxY - notchArea.height,
                width: notchWidth,
                height: notchArea.height
            )
        }
        
        let fallbackWidth: CGFloat = 200
        viewModel.collapsedHeight = 32
        viewModel.collapsedWidth = fallbackWidth
        return NSRect(
            x: screen.frame.midX - fallbackWidth / 2,
            y: screen.frame.maxY - 32,
            width: fallbackWidth,
            height: 32
        )
    }
    
    private func setupBindings() {
        viewModel.$isExpanded
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] expanded in
                self?.animatePanel(expand: expanded)
            }
            .store(in: &cancellables)
    }
    
    private func animatePanel(expand: Bool) {
        guard let screen = NSScreen.main else { return }
            
        let targetFrame = expand ? expandedFrame(for: screen) : notchFrame(for: screen)
        
        // CURVAS DINÁMICAS: Ahora la ventana física lee el redondeo de los Ajustes
        let targetRadius: CGFloat = expand ? CGFloat(AppSettings.shared.cornerRadius) : 12
            
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1.0)
            context.allowsImplicitAnimation = true // Permite que CALayer se anime solo
            
            panel.animator().setFrame(targetFrame, display: true)
            panel.contentView?.layer?.cornerRadius = targetRadius
        }
    }
    
    private func expandedFrame(for screen: NSScreen) -> NSRect {
        let collapsed = notchFrame(for: screen)
        
        let currentHeight = viewModel.dynamicExpandedHeight
        let expandedWidth = viewModel.dynamicExpandedWidth
        
        return NSRect(
            x: collapsed.midX - (expandedWidth / 2),
            y: collapsed.maxY - currentHeight,
            width: expandedWidth,
            height: currentHeight
        )
    }
}
