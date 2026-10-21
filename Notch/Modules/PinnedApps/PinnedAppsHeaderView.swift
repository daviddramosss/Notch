// PinnedAppsHeaderView.swift

import SwiftUI

struct PinnedAppsHeaderView: View {
    @ObservedObject private var manager = PinnedAppsManager.shared
    
    // Límite estricto de 2 apps para no invadir el notch físico central
    private var visibleApps: [PinnedApp] {
        Array(manager.apps.filter { $0.isEnabled }.prefix(2))
    }
    
    var body: some View {
        if !visibleApps.isEmpty {
            HStack(spacing: 10) {
                Divider()
                    .background(Color.white.opacity(0.15))
                    .frame(height: 14)
                
                HStack(spacing: 6) {
                    ForEach(visibleApps) { app in
                        PinnedAppButton(app: app, manager: manager)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: manager.apps)
            .onAppear {
                manager.reload()
            }
        }
    }
}

// MARK: - Botón Individual de App Anclada
struct PinnedAppButton: View {
    let app: PinnedApp
    @ObservedObject var manager: PinnedAppsManager
    @EnvironmentObject var viewModel: PanelViewModel
    @State private var isHovered: Bool = false
    @State private var showActionsPopover: Bool = false
     
    var body: some View {
        Button {
            manager.launchApp(app)
        } label: {
            VStack(spacing: 2) {
                Group {
                    if manager.isInstalled(app) {
                        Image(nsImage: manager.icon(for: app))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 17, height: 17)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    } else if let symbol = app.customIconSymbol {
                        Image(systemName: symbol)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(isHovered ? 1.0 : 0.8))
                            .frame(width: 17, height: 17)
                    } else {
                        Image(nsImage: manager.icon(for: app))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 17, height: 17)
                    }
                }
                
                // Indicador luminoso sutil tipo macOS Dock si la app está abierta
                Circle()
                    .fill(manager.isRunning(app) ? Color.white.opacity(0.85) : Color.clear)
                    .frame(width: 3, height: 3)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(isHovered ? Color.white.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(app.name)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                showActionsPopover = true
                viewModel.isMenuOrPopoverOpen = true
            }
        )
        .popover(isPresented: $showActionsPopover, arrowEdge: .bottom) {
            PinnedAppActionsPopover(app: app, manager: manager, isPresented: $showActionsPopover)
        }
        .onChange(of: showActionsPopover) { open in
            viewModel.isMenuOrPopoverOpen = open
        }
        .contextMenu {
            PinnedAppContextMenu(app: app, manager: manager)
        }
    }
}

// MARK: - Panel de Acciones en Doble Clic (Popover)
struct PinnedAppActionsPopover: View {
    let app: PinnedApp
    @ObservedObject var manager: PinnedAppsManager
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Cabecera con info de la app
            HStack(spacing: 10) {
                Image(nsImage: manager.icon(for: app))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack(spacing: 5) {
                        Circle()
                            .fill(manager.isRunning(app) ? Color.green : Color.secondary.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text(manager.isRunning(app) ? "En ejecución" : "Cerrada")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.bottom, 2)
            
            Divider()
            
            // Acciones de ciclo de vida
            VStack(alignment: .leading, spacing: 4) {
                if manager.isRunning(app) {
                    popoverActionButton(title: "Cerrar aplicación", icon: "xmark.circle") {
                        manager.terminateApp(app)
                        isPresented = false
                    }
                    
                    popoverActionButton(title: "Reiniciar app", icon: "arrow.clockwise") {
                        manager.restartApp(app)
                        isPresented = false
                    }
                    
                    popoverActionButton(title: "Ocultar", icon: "eye.slash") {
                        manager.hideApp(app)
                        isPresented = false
                    }
                    
                    popoverActionButton(title: "Forzar salida", icon: "exclamationmark.octagon", isDestructive: true) {
                        manager.forceTerminateApp(app)
                        isPresented = false
                    }
                } else {
                    popoverActionButton(title: "Abrir aplicación", icon: "play.fill") {
                        manager.launchApp(app)
                        isPresented = false
                    }
                }
            }
            
            Divider()
            
            // Acciones de gestión y archivo
            VStack(alignment: .leading, spacing: 4) {
                popoverActionButton(title: "Mostrar en Finder", icon: "folder") {
                    manager.revealInFinder(app)
                    isPresented = false
                }
                
                popoverActionButton(title: "Desanclar del Notch", icon: "pin.slash") {
                    manager.unpinApp(app)
                    isPresented = false
                }
                
                popoverActionButton(title: "Ajustes de Notch...", icon: "gearshape") {
                    isPresented = false
                    NSApp.activate(ignoringOtherApps: true)
                    NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsWindow"), object: nil)
                }
            }
        }
        .padding(12)
        .frame(width: 200)
    }
    
    private func popoverActionButton(title: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
            }
            .foregroundColor(isDestructive ? .red : .primary)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(Color.white.opacity(0.001)) // Área de toque
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Menú Contextual (Clic Derecho)
struct PinnedAppContextMenu: View {
    let app: PinnedApp
    @ObservedObject var manager: PinnedAppsManager
    
    var body: some View {
        if manager.isRunning(app) {
            Button("Cerrar") {
                manager.terminateApp(app)
            }
            Button("Reiniciar") {
                manager.restartApp(app)
            }
            Button("Ocultar") {
                manager.hideApp(app)
            }
            Button("Forzar salida") {
                manager.forceTerminateApp(app)
            }
            Divider()
        } else {
            Button("Abrir") {
                manager.launchApp(app)
            }
            Divider()
        }
        
        Button("Mostrar en Finder") {
            manager.revealInFinder(app)
        }
        
        Button("Desanclar del Notch") {
            manager.unpinApp(app)
        }
        
        Divider()
        
        Button("Ajustes de Notch...") {
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsWindow"), object: nil)
        }
    }
}
