import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var locationService = LocationService()
    @State private var weatherService = WeatherService()
    @State private var lastWeatherRefresh: Date = .distantPast
    @State private var weatherRefreshInFlight = false
    @Query(sort: \UserSettings.createdAt) private var settings: [UserSettings]

    private let weatherRefreshTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

    private var appLocale: Locale {
        let code = settings.first?.languageCode ?? "en"
        return Locale(identifier: code == "hu" ? "hu_HU" : "en_US")
    }

    private var preferredColorScheme: ColorScheme? {
        switch settings.first?.appearanceMode ?? "system" {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
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
            .preferredColorScheme(preferredColorScheme)
            .environmentObject(locationService)
            .environmentObject(weatherService)
            .sheet(item: $router.presentedSheet) { sheet in
                sheetView(for: sheet)
            }
        }
        .task {
            locationService.requestWhenInUsePermission()
            locationService.requestLocation()
            WidgetDataService.refreshTodayEvents(modelContext: modelContext)
            await refreshWeatherIfNeeded(force: true)
            await NotificationBootstrapService().refresh(modelContext: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            locationService.requestLocation()
            Task {
                await refreshWeatherIfNeeded(force: true)
            }
        }
        .onChange(of: locationService.currentCoordinate) { _, _ in
            Task {
                await refreshWeatherIfNeeded(force: true)
            }
        }
        .onReceive(weatherRefreshTimer) { _ in
            Task {
                await refreshWeatherIfNeeded(force: false)
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
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

    @MainActor
    private func refreshWeatherIfNeeded(force: Bool) async {
        guard let coordinate = locationService.currentCoordinate else { return }
        guard !weatherRefreshInFlight else { return }

        let now = Date()
        guard force || now.timeIntervalSince(lastWeatherRefresh) >= 300 else { return }

        weatherRefreshInFlight = true
        defer { weatherRefreshInFlight = false }

        let settings = UserSettings.current(in: modelContext)
        do {
            _ = try await weatherService.fetchWeather(
                for: coordinate,
                jwt: settings.weatherKitJWT,
                context: modelContext
            )
            try? modelContext.save()
            lastWeatherRefresh = Date()
        } catch {
            weatherService.error = error.localizedDescription
        }
    }
}
