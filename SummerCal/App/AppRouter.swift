import SwiftUI

enum AppTab: String, CaseIterable {
    case today, calendar, aiPlanner, places, weather, money, settings

    var title: String {
        switch self {
        case .today: "Today"
        case .calendar: "Calendar"
        case .aiPlanner: "AI"
        case .places: "Places"
        case .weather: "Weather"
        case .money: "Money"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "house"
        case .calendar: "calendar.day.timeline.left"
        case .aiPlanner: "brain"
        case .places: "map"
        case .weather: "cloud.sun"
        case .money: "dollarsign.circle"
        case .settings: "gearshape"
        }
    }
}

enum AppRoute: Hashable {
    case today
    case calendar
    case eventDetail(eventId: UUID)
    case aiPlanner
    case places
    case weather
    case money
    case settings
    case notificationSettings
    case aiSettings
}

enum AppSheet: Identifiable {
    case addEvent
    case addExpense(openCamera: Bool)
    case savePlace(placeId: UUID?)
    case shareEvent(eventId: UUID)
    case aiPlanDetail(planId: UUID)
    case quickNote(eventId: UUID)
    case settings

    var id: String {
        switch self {
        case .addEvent: "add_event"
        case .addExpense(let openCamera): openCamera ? "add_expense_camera" : "add_expense"
        case .savePlace: "save_place"
        case .shareEvent(let id): "share_\(id)"
        case .aiPlanDetail(let id): "plan_\(id)"
        case .quickNote(let id): "note_\(id)"
        case .settings: "settings"
        }
    }
}

final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .today
    @Published var todayNavigationPath: [AppRoute] = []
    @Published var calendarNavigationPath: [AppRoute] = []
    @Published var settingsNavigationPath: [AppRoute] = []
    @Published var presentedEventId: UUID?
    @Published var presentedSheet: AppSheet?

    func navigateToEvent(_ eventId: UUID) {
        let route = AppRoute.eventDetail(eventId: eventId)
        switch selectedTab {
        case .calendar:
            calendarNavigationPath.append(route)
        case .settings:
            settingsNavigationPath.append(route)
        default:
            selectedTab = .today
            todayNavigationPath.append(route)
        }
        presentedEventId = eventId
    }

    func navigateToWeather() {
        selectedTab = .weather
    }

    func navigateToPlaces() {
        selectedTab = .places
    }

    func navigateToSettings() {
        presentedSheet = .settings
    }

    func dismissEvent() { presentedEventId = nil }
    func showSheet(_ sheet: AppSheet) { presentedSheet = sheet }
    func dismissSheet() { presentedSheet = nil }
}
