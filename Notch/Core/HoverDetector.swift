// HoverDetector.swift
// Monitoriza eventos de cursor y clics para expandir o contraer el panel.

import AppKit
import Combine
import SwiftUI

class HoverDetector {
    private weak var panel: NSPanel?
    private weak var viewModel: PanelViewModel?
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    private var wasInside: Bool = false
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
        let eventsToWatch: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown]
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventsToWatch) { [weak self] event in
            self?.handleMouseEvent(event)
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventsToWatch) { [weak self] event in
            self?.handleMouseEvent(event)
            return event
        }
    }

    private func isMouseInside() -> Bool {
        guard let panel = panel else { return false }
        let mouseLoc = NSEvent.mouseLocation
        
        if panel.frame.contains(mouseLoc) {
            return true
        }
        
        for window in NSApp.windows where window.isVisible && window != panel {
            if window.title == "Ajustes de Notch" { continue }
            let className = String(describing: type(of: window))
            if className.contains("Popover") || window.parent == panel {
                if window.frame.contains(mouseLoc) {
                    return true
                }
            }
        }
        
        return false
    }

    private func handleMouseEvent(_ event: NSEvent) {
        guard let panel = panel, let viewModel = viewModel else { return }
        
        if viewModel.isMenuOrPopoverOpen {
            return
        }
        
        let isInside = isMouseInside()
        let mode = AppSettings.shared.activationMode
        
        if event.type == .leftMouseDown {
            if isInside {
                if mode == .click {
                    setExpanded(true)
                } else if mode == .doubleClick && event.clickCount == 2 {
                    setExpanded(true)
                } else if mode == .hover {
                    setExpanded(true)
                }
            } else {
                setExpanded(false)
            }
        }
        
        if event.type == .mouseMoved || event.type == .leftMouseDragged {
            if isInside != wasInside {
                wasInside = isInside
                
                if isInside {
                    if mode == .hover {
                        startHoverTimer()
                    }
                } else {
                    cancelHoverTimer()
                    setExpanded(false)
                }
            }
        }
    }
    
    private func startHoverTimer() {
        let delay = AppSettings.shared.hoverExpandDelay
        
        if delay <= 0 {
            setExpanded(true)
        } else {
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
        guard viewModel?.isExpanded != expand else { return }
        
        DispatchQueue.main.async { [weak self] in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                self?.viewModel?.isExpanded = expand
            }
        }
    }
}
