/*
 Dibuja la interfaz del calendario de forma ELÁSTICA y CENTRADA.
 Usa GeometryReader para calcular cuánto espacio tiene y,
 automáticamente, muestra el mes completo o abreviado, y más o menos días.
*/

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var manager: CalendarWidgetManager
    
    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .center, spacing: 6) { // Reducido para mayor compactación
                
                weekDaysHeader(availableWidth: geo.size.width)
                
                VStack(alignment: .center, spacing: 2) {
                    if manager.permissionDenied {
                        permissionPrompt
                    } else if manager.events.isEmpty {
                        emptyState
                    } else {
                        eventList
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(.vertical, 4)
    }
    
    private func weekDaysHeader(availableWidth: CGFloat) -> some View {
        let radius: Int
        if availableWidth < 180 {
            radius = 1
        } else if availableWidth < 280 {
            radius = 2
        } else if availableWidth < 360 {
            radius = 3
        } else {
            radius = 4
        }
        
        let range = -radius...radius
        let monthFormat: Date.FormatStyle = availableWidth > 350 ? .dateTime.month(.wide) : .dateTime.month(.abbreviated)
        
        return HStack(alignment: .center, spacing: 16) {
            Text(Date(), format: monthFormat)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .layoutPriority(1)
            
            HStack(spacing: 12) {
                ForEach(range, id: \.self) { offset in
                    let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
                    let isToday = offset == 0
                    
                    VStack(spacing: 4) {
                        Text(date, format: .dateTime.weekday(.abbreviated).locale(Locale(identifier: "en_US")))
                            .font(.system(size: 10, weight: isToday ? .bold : .semibold))
                            .foregroundColor(isToday ? Color(red: 0.2, green: 0.5, blue: 1.0) : .white.opacity(0.3))
                            .textCase(.uppercase)
                            .lineLimit(1)
                        
                        Text(date, format: .dateTime.day())
                            .font(.system(size: 14, weight: isToday ? .bold : .regular))
                            .foregroundColor(isToday ? Color(red: 0.2, green: 0.5, blue: 1.0) : .white.opacity(0.4))
                    }
                    .frame(width: 24)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 2) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
            
            Text("Nothing for today")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
    }
    
    private var eventList: some View {
        VStack(spacing: 4) {
            ForEach(manager.events.prefix(2)) { event in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(event.color)
                        .frame(width: 3, height: 16) // Más cortito para que no desborde
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(event.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(event.timeString)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: 200, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private var permissionPrompt: some View {
        Button("Permitir acceso al calendario") {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
        }
        .font(.system(size: 12))
        .foregroundColor(.orange)
        .buttonStyle(.plain)
    }
}
