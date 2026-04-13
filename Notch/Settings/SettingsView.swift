import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var registry: WidgetRegistry
    @ObservedObject var settings = AppSettings.shared
    @State private var selectedSection: SettingsSection = .nook

    enum SettingsSection: String, CaseIterable {
        case general       = "General"
        case nook          = "Nook"
        case behavior      = "Gestos"
        case appearance    = "Apariencia"

        var icon: String {
            switch self {
            case .general:    return "gearshape"
            case .nook:       return "rectangle.topthird.inset.filled"
            case .behavior:   return "hand.point.up"
            case .appearance: return "paintbrush"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionToolbar
            Divider()
            
            ScrollView {
                Group {
                    switch selectedSection {
                    case .general:    GeneralSettingsSection()
                    case .nook:       NookSettingsSection()
                    case .behavior:   BehaviorSettingsSection()
                    case .appearance: AppearanceSettingsSection()
                    }
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(minWidth: 540, idealWidth: 540, maxWidth: 540, minHeight: 650, idealHeight: 650, maxHeight: 650)
        .environmentObject(registry)
    }

    private var sectionToolbar: some View {
        HStack(spacing: 0) {
            ForEach(SettingsSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedSection = section
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: section.icon).font(.system(size: 20))
                        Text(section.rawValue).font(.system(size: 11))
                    }
                    .foregroundColor(selectedSection == section ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedSection == section ? Color.accentColor.opacity(0.1) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("NotchPanel v1.0").font(.caption).foregroundColor(.secondary)
            Spacer()
            Button { NSApplication.shared.terminate(nil) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "power").font(.system(size: 12, weight: .bold))
                    Text("Cerrar Notch").font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .onHover { hovering in if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }
}

// MARK: - SECCIÓN NOOK (Configuración Visual)
struct NookSettingsSection: View {
    @EnvironmentObject var registry: WidgetRegistry
    @ObservedObject var settings = AppSettings.shared
    @State private var selectedWidgetID: WidgetID? = nil

    var nookWidgets: [WidgetID] {
        registry.orderedWidgets.filter {
            $0 != .dropzone && $0 != .systemMonitor && $0 != .shortcuts
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Vista previa del Nook", systemImage: "rectangle.topthird.inset.filled")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    NotchPreviewBar(
                        widgets: nookWidgets.filter { registry.activeWidgets.contains($0) },
                        widthMap: settings.widgetWidths,
                        selectedID: $selectedWidgetID
                    )
                    .frame(height: 72)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    Text("Selecciona un widget para ajustar su tamaño y posición.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Módulos Principales", systemImage: "square.grid.2x2")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        ForEach(nookWidgets, id: \.self) { id in
                            WidgetConfigRow(
                                id: id,
                                isSelected: selectedWidgetID == id,
                                onSelect: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedWidgetID = selectedWidgetID == id ? nil : id
                                    }
                                }
                            )
                            .environmentObject(registry)

                            if id != nookWidgets.last { Divider().padding(.leading, 44) }
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
                }

                if let selectedID = selectedWidgetID, registry.activeWidgets.contains(selectedID) {
                    WidgetWidthEditor(widgetID: selectedID)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    if selectedID == .nowPlaying { NowPlayingOptions().transition(.opacity) }
                    if selectedID == .calendar { CalendarOptions().transition(.opacity) }
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Label("Cabecera del Sistema (Arriba a la derecha)", systemImage: "menubar.dock.rectangle.badge.record")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 0) {
                    SettingsToggleRow(label: "Mostrar CPU", icon: "cpu", isOn: $settings.systemShowCPU)
                    Divider().padding(.leading, 44)
                    SettingsToggleRow(label: "Mostrar RAM", icon: "memorychip", isOn: $settings.systemShowRAM)
                    Divider().padding(.leading, 44)
                    SettingsToggleRow(label: "Mostrar AirPods", icon: "airpodspro", isOn: $settings.systemShowAirPods)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
            }
        }
    }
}

// MARK: - PREVISUALIZACIÓN DEL NOTCH
struct NotchPreviewBar: View {
    let widgets: [WidgetID]
    let widthMap: [String: Double]
    @Binding var selectedID: WidgetID?

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 16
            let totalAssigned = widgets.reduce(0.0) { $0 + (widthMap[$1.rawValue] ?? 0.3) }
            let scale = totalAssigned > 1.0 ? (1.0 / totalAssigned) : 1.0

            HStack(spacing: 4) {
                ForEach(widgets, id: \.self) { id in
                    let rawFraction = widthMap[id.rawValue] ?? 0.3
                    let fraction = rawFraction * scale
                    
                    PreviewWidgetCell(
                        id: id,
                        isSelected: selectedID == id,
                        onTap: { withAnimation(.easeInOut(duration: 0.15)) { selectedID = selectedID == id ? nil : id } }
                    )
                    .frame(width: max(40, totalWidth * fraction))
                    .animation(.spring(response: 0.4), value: fraction)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 8)
    }
}

struct PreviewWidgetCell: View {
    let id: WidgetID
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: id.icon).font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                Text(id.displayName).font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - COMPONENTES REUTILIZABLES DE AJUSTES
struct WidgetConfigRow: View {
    let id: WidgetID
    let isSelected: Bool
    let onSelect: () -> Void
    @EnvironmentObject var registry: WidgetRegistry

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(id.accentColor.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: id.icon).font(.system(size: 14, weight: .medium)).foregroundColor(id.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(id.displayName).font(.system(size: 13, weight: .medium))
                Text(id.subtitle).font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            
            if registry.activeWidgets.contains(id) {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "chevron.up" : "slider.horizontal.3")
                        .foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            
            Toggle("", isOn: Binding(
                get: { registry.activeWidgets.contains(id) },
                set: { registry.setEnabled(id, enabled: $0) }
            )).labelsHidden().toggleStyle(.switch)
        }
        .padding(.horizontal, 14).padding(.vertical, 10).contentShape(Rectangle())
    }
}

// MARK: - EDITOR: TAMAÑO Y ORDEN
struct WidgetWidthEditor: View {
    let widgetID: WidgetID
    @ObservedObject var settings = AppSettings.shared
    @EnvironmentObject var registry: WidgetRegistry

    var activeNookWidgets: [WidgetID] {
        registry.orderedWidgets.filter {
            registry.activeWidgets.contains($0) && ($0 == .nowPlaying || $0 == .calendar || $0 == .camera)
        }
    }

    var isFirst: Bool { activeNookWidgets.first == widgetID }
    var isLast:  Bool { activeNookWidgets.last == widgetID }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            HStack {
                Image(systemName: widgetID.icon).foregroundColor(widgetID.accentColor)
                Text("Configurar \(widgetID.displayName)").font(.system(size: 13, weight: .bold))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Ancho en el Notch")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int((settings.widgetWidths[widgetID.rawValue] ?? 0.3) * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 10) {
                    Image(systemName: "arrow.left.and.right").font(.system(size: 11)).foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { settings.widgetWidths[widgetID.rawValue] ?? 0.3 },
                            set: { settings.widgetWidths[widgetID.rawValue] = $0 }
                        ),
                        in: 0.10...0.70, step: 0.05
                    )
                    Button("Reset") { settings.widgetWidths[widgetID.rawValue] = 0.3 }
                        .font(.system(size: 11)).buttonStyle(.plain).foregroundColor(.accentColor)
                }
            }

            Divider().padding(.vertical, 2)

            HStack {
                Text("Posición visual")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 12) {
                    Button(action: moveLeft) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                            Text("Izquierda").font(.system(size: 11))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(isFirst ? 0.05 : 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(isFirst)
                    .opacity(isFirst ? 0.4 : 1.0)

                    Button(action: moveRight) {
                        HStack(spacing: 4) {
                            Text("Derecha").font(.system(size: 11))
                            Image(systemName: "arrow.right")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(isLast ? 0.05 : 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLast)
                    .opacity(isLast ? 0.4 : 1.0)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5))
    }

    private func moveLeft() {
        guard let visualIndex = activeNookWidgets.firstIndex(of: widgetID), visualIndex > 0 else { return }
        let targetID = activeNookWidgets[visualIndex - 1]
        swapInRegistry(id1: widgetID, id2: targetID)
    }

    private func moveRight() {
        guard let visualIndex = activeNookWidgets.firstIndex(of: widgetID), visualIndex < activeNookWidgets.count - 1 else { return }
        let targetID = activeNookWidgets[visualIndex + 1]
        swapInRegistry(id1: widgetID, id2: targetID)
    }

    private func swapInRegistry(id1: WidgetID, id2: WidgetID) {
        withAnimation(.spring(response: 0.4)) {
            registry.swapWidgets(id1, id2)
        }
    }
}

struct NowPlayingOptions: View {
    @ObservedObject var settings = AppSettings.shared
    var body: some View {
        SettingsCard(title: "Now Playing", icon: "music.note") {
            SettingsToggleRow(label: "Mostrar carátula", icon: "photo", isOn: $settings.nowPlayingShowArtwork)
            Divider().padding(.leading, 36)
            SettingsToggleRow(label: "Mostrar controles", icon: "playpause", isOn: $settings.nowPlayingShowControls)
        }
    }
}

struct CalendarOptions: View {
    @ObservedObject var settings = AppSettings.shared
    var body: some View {
        SettingsCard(title: "Calendario", icon: "calendar") {
            SettingsToggleRow(label: "Eventos todo el día", icon: "sun.max", isOn: $settings.calendarShowAllDay)
        }
    }
}

struct GeneralSettingsSection: View {
    // Leemos el estado real del sistema al abrir la pestaña
    @State private var isLaunchAtLoginEnabled: Bool = SMAppService.mainApp.status == .enabled
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: "Inicio", icon: "power") {
                
                // Creamos un Binding (Conexión directa) entre el interruptor y el sistema del Mac
                SettingsToggleRow(
                    label: "Iniciar con Mac",
                    icon: "bolt.fill",
                    isOn: Binding(
                        get: { isLaunchAtLoginEnabled },
                        set: { newValue in
                            toggleLaunchAtLogin(enable: newValue)
                        }
                    )
                )
            }
        }
    }
    
    // MARK: - Lógica del Sistema
    private func toggleLaunchAtLogin(enable: Bool) {
        do {
            if enable {
                // Le pedimos a macOS que nos añada a la lista
                try SMAppService.mainApp.register()
            } else {
                // Le pedimos a macOS que nos quite de la lista
                try SMAppService.mainApp.unregister()
            }
            // Si funciona, actualizamos el interruptor visualmente
            isLaunchAtLoginEnabled = enable
        } catch {
            print("Error al configurar el arranque del sistema: \(error.localizedDescription)")
            // Si el sistema lo rechaza por seguridad, el interruptor vuelve a su estado real
            isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        }
    }
}

struct BehaviorSettingsSection: View {
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: "Activación", icon: "cursorarrow") {
                
                // 1. Selector de Modo
                Picker("Activar con", selection: $settings.activationMode) {
                    Text("Hover").tag(ActivationMode.hover)
                    Text("Clic").tag(ActivationMode.click)
                    Text("Doble Clic").tag(ActivationMode.doubleClick)
                }
                .pickerStyle(.segmented)
                .padding(14)
                
                // 2. Deslizador de retraso (Aparece solo en modo Hover)
                if settings.activationMode == .hover {
                    Divider().padding(.leading, 36)
                    SettingsSliderRow(
                        label: "Retraso al abrir",
                        icon: "timer",
                        value: $settings.hoverExpandDelay,
                        range: 0.0...1.5, // De 0 a 1.5 segundos
                        step: 0.1,
                        unit: "s"
                    )
                }
            }
        }
    }
}

struct AppearanceSettingsSection: View {
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // 1. Tarjeta principal de ajustes
            SettingsCard(title: "Panel", icon: "rectangle.roundedtop") {
                SettingsToggleRow(label: "Fondo Translúcido", icon: "drop.fill", isOn: $settings.useMaterialBackground)
                Divider().padding(.leading, 36)
                
                SettingsSliderRow(label: "Altura al expandirse", icon: "arrow.up.and.down", value: $settings.expandedHeight, range: 100...300, step: 5, unit: "px")
                Divider().padding(.leading, 36)
                
                SettingsSliderRow(label: "Redondeo de bordes", icon: "square.on.circle", value: $settings.cornerRadius, range: 0...60, step: 2, unit: "px")
            }
            
            // 2. Botón de Restablecer
            HStack {
                Spacer() // Empuja el botón hacia la derecha
                
                Button(action: resetAppearanceDefaults) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .bold))
                        Text("Restablecer por defecto")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
        }
    }
    
    // MARK: - Valores por defecto
    private func resetAppearanceDefaults() {
        // Envolvemos los cambios en withAnimation para que los sliders se muevan suavemente
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            settings.useMaterialBackground = true
            settings.expandedHeight = 165.0 // Tu altura base
            settings.cornerRadius = 30.0    // Tu redondeo base
        }
    }
}

// MARK: - HELPERS VISUALES
struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                Text(title.uppercased()).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary).kerning(0.5)
            }
            .padding(.bottom, 6)
            VStack(spacing: 0) { content }
                .background(Color(NSColor.controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
        }
    }
}

struct SettingsToggleRow: View {
    let label: String
    let icon: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.secondary).frame(width: 20)
            Text(label).font(.system(size: 13))
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden()
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}

struct SettingsSliderRow: View {
    let label: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    var displayMultiplier: Double = 1.0
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.secondary).frame(width: 20)
            Text(label).font(.system(size: 13))
            Spacer()
            Slider(value: $value, in: range, step: step).frame(width: 110)
            Text("\(Int(value * displayMultiplier))\(unit)").font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary).frame(minWidth: 42, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}
