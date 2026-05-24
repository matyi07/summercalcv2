import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var modelContext
    @State private var locationService = LocationService()
    @State private var weatherService = WeatherService()

    var body: some View {

        ZStack {
            TabView(selection: $router.selectedTab) {
                NavigationStack {
                    TodayView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
                .tabItem { Label(AppTab.today.title, systemImage: AppTab.today.systemImage) }
                .tag(AppTab.today)

                NavigationStack {
                    CalendarView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
                .tabItem { Label(AppTab.calendar.title, systemImage: AppTab.calendar.systemImage) }
                .tag(AppTab.calendar)

                NavigationStack {
                    PlacesView()
                }
                .tabItem { Label(AppTab.places.title, systemImage: AppTab.places.systemImage) }
                .tag(AppTab.places)

                NavigationStack {
                    MoneyView()
                }
                .tabItem { Label(AppTab.money.title, systemImage: AppTab.money.systemImage) }
                .tag(AppTab.money)

                NavigationStack {
                    SettingsView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage) }
                .tag(AppTab.settings)
            }
            .tint(.orange)
            .environmentObject(locationService)
            .environmentObject(weatherService)
            .sheet(item: $router.presentedSheet) { sheet in
                sheetView(for: sheet)
            }
        }
        .task {
            locationService.requestWhenInUsePermission()
        }
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .today: TodayView()
        case .calendar: CalendarView()
        case .eventDetail(let eventId): EventDetailView(eventId: eventId)
        case .aiPlanner: AIPlannerView()
        case .places: PlacesView()
        case .weather: WeatherView()
        case .money: MoneyView()
        case .settings: SettingsView()
        case .notificationSettings: SmartNotificationSettingsView()
        case .aiSettings: AISettingsView()
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: AppSheet) -> some View {
        switch sheet {
        case .addEvent: AddEventView()
        case .addExpense: AddIncomeView()
        case .savePlace: SavePlaceView(placeId: nil)
        case .shareEvent(let eventId): ShareEventView(eventId: eventId)
        case .aiPlanDetail: AIPlanDetailView(planId: UUID())
        case .quickNote(let eventId): QuickNoteView(eventId: eventId)
        case .settings: SettingsView()
        }
    }
}
