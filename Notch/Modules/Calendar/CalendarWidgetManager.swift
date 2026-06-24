// CalendarWidgetManager.swift
import EventKit
import Combine
import SwiftUI

struct CalendarEvent: Identifiable {
    let id:        String
    let title:     String
    let startDate: Date
    let endDate:   Date
    let color:     Color
    let isAllDay:  Bool

    var timeString: String {
        if isAllDay { return "Todo el día" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.locale = .current
        return "\(f.string(from: startDate)) – \(f.string(from: endDate))"
    }

    var isNow: Bool {
        let now = Date()
        return startDate <= now && endDate >= now
    }

    var startsInMinutes: Int {
        Int(startDate.timeIntervalSinceNow / 60)
    }
}

class CalendarWidgetManager: ObservableObject, NotchWidget {

    let id:    WidgetID = .calendar
    let title  = "Calendario"
    let requiresPermission = true

    @Published var isEnabled:      Bool             = true
    @Published var events:         [CalendarEvent]  = []
    @Published var permissionDenied: Bool           = false

    private let store = EKEventStore()
    private var refreshTimer: Timer?

    // MARK: - Ciclo de vida

    func activate() {
        // Ya no pide permiso — consulta el estado centralizado
        let status = PermissionsManager.shared.calendar
        
        if status == .denied {
            permissionDenied = true
            return
        }
        
        if status == .granted {
            loadEvents()
            scheduleRefresh()
        }
        // Si es .notDetermined, no hacemos nada — el startup sequence se encarga
    }

    func deactivate() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        events = []
    }


    // MARK: - Carga de eventos

    private func loadEvents() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        // Busca desde ahora hasta el final del día
        // pero también incluye eventos en curso que empezaron antes
        guard let endOfDay = calendar.date(
            byAdding: .day, value: 1, to: startOfDay
        ) else { return }

        let predicate = store.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil  // nil = todos los calendarios activos
        )

        let raw = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        DispatchQueue.main.async { [weak self] in
            self?.events = raw.map { ek in
                CalendarEvent(
                    id:        ek.eventIdentifier,
                    title:     ek.title ?? "Sin título",
                    startDate: ek.startDate,
                    endDate:   ek.endDate,
                    color:     Color(cgColor: ek.calendar.cgColor),
                    isAllDay:  ek.isAllDay
                )
            }
        }
    }

    private func scheduleRefresh() {
        // Refresca al inicio de cada minuto para que los tiempos sean precisos
        let now = Date()
        let calendar = Calendar.current
        guard let nextMinute = calendar.nextDate(
            after: now,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime
        ) else { return }

        let delay = nextMinute.timeIntervalSince(now)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.loadEvents()
            // A partir de aquí, cada 60 s
            self?.refreshTimer = Timer.scheduledTimer(
                withTimeInterval: 60,
                repeats: true
            ) { [weak self] _ in self?.loadEvents() }
        }
    }

    func makeView() -> some View {
        CalendarView().environmentObject(self)
    }
}
