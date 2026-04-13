/*
 
 Esta vista dibuja los mini-anillos de colores y los iconos, y se encarga de arrancar y apagar los motores solo cuando abres el Notch (así ahorramos
 100% de batería cuando el Notch está cerrado).
 
 */

import SwiftUI

struct SystemHeaderView: View {
    @StateObject private var sysManager = SystemMonitorManager()
    @StateObject private var btManager = BluetoothManager()
    
    // 👀 Le decimos a la vista que vigile los ajustes en tiempo real
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        HStack(spacing: 16) {
            
            // 1. CPU
            if settings.systemShowCPU {
                MiniGauge(title: "CPU", value: sysManager.stats.cpuUsage)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // 2. RAM
            if settings.systemShowRAM {
                MiniGauge(title: "RAM", value: sysManager.stats.ramPercent)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // 3. AirPods
            if settings.systemShowAirPods && btManager.airpods.isConnected {
                Image(systemName: "airpods")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
                    .transition(.scale.combined(with: .opacity))
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
        }
    }
}

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
