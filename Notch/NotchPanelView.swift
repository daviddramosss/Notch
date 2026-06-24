/*
 Interfaz visual raíz. Dibuja el fondo, la cabecera (Pestañas y Ajustes)
 y distribuye el espacio interior de forma ELÁSTICA según los Ajustes.
 PRUEBA   
*/

import SwiftUI

enum NotchTab {
    case nook
    case tray
}

struct NotchPanelView: View {
    @EnvironmentObject var viewModel: PanelViewModel
    @EnvironmentObject var registry: WidgetRegistry
    @ObservedObject var settings = AppSettings.shared
    
    @State private var selectedTab: NotchTab = .nook
    
    var body: some View {
        ZStack(alignment: .top) {
            //Cristal oscuro o Negro sólido
                Group {
                    if settings.useMaterialBackground {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark) // Fuerza el tinte oscuro elegante
                    } else {
                        Color.black
                    }
                }
                .clipShape(
                    .rect(
                        bottomLeadingRadius: viewModel.isExpanded ? settings.cornerRadius : 12,
                        bottomTrailingRadius: viewModel.isExpanded ? settings.cornerRadius : 12,
                        style: .continuous
                    )
                )
            
            if viewModel.isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(
            width: viewModel.isExpanded ? 720 : viewModel.collapsedWidth,
            height: viewModel.isExpanded ? settings.expandedHeight : viewModel.collapsedHeight
        )
        .ignoresSafeArea()
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.isExpanded)
    }
    
    private var expandedContent: some View {
        VStack(spacing: 0) {
            //Color.clear.frame(height: viewModel.collapsedHeight)
            
            header
                .padding(.horizontal, 22)
                .padding(.top, 12)
            
            if selectedTab == .nook {
                let activeNookWidgets = registry.orderedWidgets.filter {
                    registry.activeWidgets.contains($0) && ($0 == .nowPlaying || $0 == .calendar || $0 == .camera)
                }
                
                let innerWidth: CGFloat = 680
                let cameraWidth: CGFloat = 92
                let dividerWidth: CGFloat = 16
                let totalDividersWidth = CGFloat(max(0, activeNookWidgets.count - 1)) * dividerWidth
                
                let hasCamera = activeNookWidgets.contains(.camera)
                let fixedPixels = (hasCamera ? cameraWidth : 0) + totalDividersWidth
                let availableForStretch = max(0, innerWidth - fixedPixels)
                
                let stretchables = activeNookWidgets.filter { $0 != .camera }
                let totalWeight = stretchables.reduce(0.0) { $0 + (settings.widgetWidths[$1.rawValue] ?? 0.3) }
                
                HStack(alignment: .center, spacing: 0) {
                    if !activeNookWidgets.isEmpty {
                        ForEach(Array(activeNookWidgets.enumerated()), id: \.element) { index, id in
                            
                            if id == .camera {
                                widgetView(for: .camera)
                                    .frame(width: cameraWidth, height: cameraWidth)
                                    .clipped()
                            } else {
                                let weight = settings.widgetWidths[id.rawValue] ?? 0.3
                                let fraction = totalWeight > 0 ? (weight / totalWeight) : 1.0
                                let width = availableForStretch * CGFloat(fraction)
                                
                                widgetView(for: id)
                                    .frame(width: width)
                                    .clipped()
                            }
                            
                            if index < activeNookWidgets.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.15))
                                    .frame(height: 50)
                                    .padding(.horizontal, dividerWidth / 2)
                            }
                        }
                    } else {
                        Text("No hay widgets activos")
                            .foregroundColor(.white.opacity(0.3))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(width: innerWidth)
                .frame(maxHeight: .infinity) //Esto evita que se aplaste al quitar la cámara
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 18)
                
            } else {
                DropzoneView()
                    .padding(.bottom, 12)
            }
        }
    }
    
    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                TabButton(title: "Nook", icon: "macwindow", isSelected: selectedTab == .nook) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .nook }
                }
                TabButton(title: "Tray", icon: "tray", isSelected: selectedTab == .tray) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .tray }
                }
            }
            Spacer()
            
            SystemHeaderView()
                .padding(.trailing, 16)
            
            Button {
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsWindow"), object: nil)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() }
                        else { NSCursor.pop() }
                    }
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func widgetView(for id: WidgetID) -> some View {
        switch id {
        case .nowPlaying:
            if let manager = registry.manager(for: id) as? NowPlayingManager {
                NowPlayingView().environmentObject(manager)
            }
        case .calendar:
            if let manager = registry.manager(for: id) as? CalendarWidgetManager {
                CalendarView().environmentObject(manager)
            }
        case .camera:
            if let manager = registry.manager(for: id) as? CameraManager {
                CameraView().environmentObject(manager)
            }
        default: EmptyView()
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title).fontWeight(.semibold)
            }
            .font(.system(size: 12))
            .foregroundColor(isSelected ? .white : .white.opacity(0.4))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isSelected ? Color.white.opacity(0.15) : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
