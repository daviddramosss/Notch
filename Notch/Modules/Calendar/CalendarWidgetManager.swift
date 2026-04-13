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
        requestAccessIfNeeded { [weak self] granted in
            guard granted else {
                self?.permissionDenied = true
                return
            }
            self?.loadEvents()
            // Refresca cada 5 minutos y al cambiar de minuto
            self?.scheduleRefresh()
        }
    }

    func deactivate() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        events = []
    }

    // MARK: - Permisos

    private func requestAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess:
            completion(true)
        case .notDetermined:
            // iOS 17+ / macOS 14+ usa requestFullAccessToEvents
            if #available(macOS 14.0, *) {
                store.requestFullAccessToEvents { granted, _ in
                    DispatchQueue.main.async { completion(granted) }
                }
            } else {
                store.requestAccess(to: .event) { granted, _ in
                    DispatchQueue.main.async { completion(granted) }
                }
            }
        default:
            completion(false)
        }
    }

    // MARK: - Carga de eventos

    private func loadEvents() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        // Buscamos desde ahora hasta el final del día
        // pero también incluimos eventos en curso que empezaron antes
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
