import SwiftUI
import SwiftData
import GoogleMaps

struct ContentView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var modelContext
    @State private var locationService = LocationService()
    @State private var weatherService = WeatherService()
    @Query(sort: \UserSettings.createdAt) private var settings: [UserSettings]

    private var appLocale: Locale {
        let code = settings.first?.languageCode ?? "en"
        return Locale(identifier: code == "hu" ? "hu_HU" : "en_US")
    }

    var body: some View {

        ZStack {
            TabView(selection: $router.selectedTab) {
                NavigationStack(path: $router.todayNavigationPath) {
                    TodayView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
                .tabItem { Label(AppTab.today.titleKey, systemImage: AppTab.today.systemImage) }
                .tag(AppTab.today)

                NavigationStack(path: $router.calendarNavigationPath) {
                    CalendarView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
                .tabItem { Label(AppTab.calendar.titleKey, systemImage: AppTab.calendar.systemImage) }
                .tag(AppTab.calendar)

                NavigationStack {
                    PlacesView()
                }
                .tabItem { Label(AppTab.places.titleKey, systemImage: AppTab.places.systemImage) }
                .tag(AppTab.places)

                NavigationStack {
                    MoneyView()
                }
                .tabItem { Label(AppTab.money.titleKey, systemImage: AppTab.money.systemImage) }
                .tag(AppTab.money)

                NavigationStack(path: $router.settingsNavigationPath) {
                    SettingsView()
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
                .tabItem { Label(AppTab.settings.titleKey, systemImage: AppTab.settings.systemImage) }
                .tag(AppTab.settings)
            }
            .tint(.orange)
            .environment(\.locale, appLocale)
            .environmentObject(locationService)
            .environmentObject(weatherService)
            .sheet(item: $router.presentedSheet) { sheet in
                sheetView(for: sheet)
            }
        }
        .task {
            locationService.requestWhenInUsePermission()
            WidgetDataService.refreshTodayEvents(modelContext: modelContext)
            await NotificationBootstrapService().refresh(modelContext: modelContext)
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .task(priority: .background) {
            GMSServices.provideAPIKey(GoogleAPI.defaultKey)
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
        case .addExpense(let openCamera): AddExpenseView(startWithCamera: openCamera)
        case .savePlace: SavePlaceView(placeId: nil)
        case .shareEvent(let eventId): ShareEventView(eventId: eventId)
        case .aiPlanDetail: AIPlanDetailView(planId: UUID())
        case .quickNote(let eventId): QuickNoteView(eventId: eventId)
        case .settings: SettingsView()
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == SummerCalWidgetShared.appURLScheme else { return }

        if url.host == "today" {
            router.selectedTab = .today
        } else if url.host == "add-expense" {
            let shouldOpenCamera = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .contains(where: { $0.name == "camera" && $0.value == "1" }) ?? false
            router.selectedTab = .money
            router.showSheet(.addExpense(openCamera: shouldOpenCamera))
        }
    }
}
