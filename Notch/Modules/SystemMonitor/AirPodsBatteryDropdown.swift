// AirPodsBatteryDropdown.swift

import SwiftUI

struct AirPodsBatteryDropdown: View {
    let info: AirPodsInfo
    
    var body: some View {
        VStack(spacing: 12) {
            Text(info.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            
            HStack(spacing: 18) {
                BatteryCell(icon: "earbuds",                label: "L", percent: info.leftBattery)
                BatteryCell(icon: "earbuds",                label: "R", percent: info.rightBattery)
                BatteryCell(icon: "airpods.chargingcase",   label: nil, percent: info.caseBattery)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        // Fondo opaco que tapa el chrome nativo del popover
        .background(Color.black)
    }
}

private struct BatteryCell: View {
    let icon: String
    let label: String?
    let percent: Int?
    
    private var ringColor: Color {
        guard let p = percent else { return .white.opacity(0.2) }
        if p < 20 { return .red }
        if p < 40 { return .orange }
        return .green
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                if let p = percent {
                    Circle()
                        .trim(from: 0, to: CGFloat(p) / 100.0)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: p)
                }
                
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(percent == nil ? 0.3 : 0.9))
            }
            
            HStack(spacing: 3) {
                if let label = label {
                    Text(label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
                Text(percent.map { "\($0)%" } ?? "—")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(percent == nil ? 0.3 : 0.85))
            }
        }
    }
}
