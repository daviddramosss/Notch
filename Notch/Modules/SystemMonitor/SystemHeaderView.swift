// SystemHeaderView.swift

import SwiftUI

struct SystemHeaderView: View {
    @StateObject private var sysManager = SystemMonitorManager()
    @StateObject private var btManager = BluetoothManager()
    
    @ObservedObject private var settings = AppSettings.shared
    
    @State private var isAirPodsDropdownOpen: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            
            if settings.systemShowCPU {
                MiniGauge(title: "CPU", value: sysManager.stats.cpuUsage)
                    .transition(.scale.combined(with: .opacity))
            }
            
            if settings.systemShowRAM {
                MiniGauge(title: "RAM", value: sysManager.stats.ramPercent)
                    .transition(.scale.combined(with: .opacity))
            }
            
            if settings.systemShowAirPods && btManager.airpods.isConnected {
                Image(systemName: "airpods")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(isAirPodsDropdownOpen ? 1.0 : 0.8))
                    .transition(.scale.combined(with: .opacity))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        btManager.startBatteryUpdates()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            if btManager.airpods.hasAnyBatteryData {
                                isAirPodsDropdownOpen = true
                            } else {
                                // Hardware no soporta reporte de batería — no abrimos nada
                                btManager.stopBatteryUpdates()
                            }
                        }
                    }
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() }
                        else { NSCursor.pop() }
                    }
                    .popover(isPresented: $isAirPodsDropdownOpen,
                             attachmentAnchor: .point(.bottom),
                             arrowEdge: .top) {
                        AirPodsBatteryDropdown(info: btManager.airpods)
                            .onAppear { btManager.startBatteryUpdates() }
                            .onDisappear { btManager.stopBatteryUpdates() }
                    }
            }
        }

        .animation(.easeInOut(duration: 0.3), value: btManager.airpods.isConnected)
        .animation(.easeInOut(duration: 0.3), value: settings.systemShowCPU)
        .animation(.easeInOut(duration: 0.3), value: settings.systemShowRAM)
        .animation(.easeInOut(duration: 0.3), value: settings.systemShowAirPods)
        .onAppear {
            sysManager.startMonitoring()
            btManager.startMonitoring()
        }
        .onDisappear {
            sysManager.stopMonitoring()
            btManager.stopMonitoring()
            isAirPodsDropdownOpen = false
        }

        .onChange(of: btManager.airpods.isConnected) { _, isConnected in
            if !isConnected && isAirPodsDropdownOpen {
                withAnimation { isAirPodsDropdownOpen = false }
            }
        }
    }
}

// MiniGauge sin cambios
struct MiniGauge: View {
    let title: String
    let value: Double
    
    var color: Color {
        if value < 0.5 { return .green }
        if value < 0.8 { return .orange }
        return .red
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
            
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(value, 0.0), 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: value)
            }
            .frame(width: 14, height: 14)
        }
    }
}
