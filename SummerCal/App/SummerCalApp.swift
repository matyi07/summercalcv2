import SwiftUI
import SwiftData

@main
struct SummerCalApp: App {
    @State private var appRouter = AppRouter()
    @State private var mapsInitialized = false

    private let modelContainer: ModelContainer = {
        let schema = Schema([
            CalendarEvent.self,
            EventNote.self,
            EventReminder.self,
            SmartNotificationRule.self,
            NotificationLog.self,
            ActivitySuggestion.self,
            WeatherSnapshot.self,
            PlaceCandidate.self,
            IncomeEntry.self,
            ExpenseEntry.self,
            WorkSession.self,
            UserSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let context = container.mainContext
            if (try? context.fetch(FetchDescriptor<UserSettings>(sortBy: [SortDescriptor(\.createdAt)])).isEmpty) ?? true {
                let defaultSettings = UserSettings()
                context.insert(defaultSettings)
                try? context.save()
            }
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    init() {
        _ = NotificationService.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appRouter)
        }
        .modelContainer(modelContainer)
    }
}
