import SwiftUI
import SwiftData
import GoogleMaps

@main
struct SummerCalApp: App {
    @State private var appRouter = AppRouter()

    private let modelContainer: ModelContainer = SummerCalApp.makeModelContainer()

    private static var appSchema: Schema {
        Schema([
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
            SavingsEntry.self,
            SavingsGoal.self,
            WorkSession.self,
            WorkType.self,
            UserSettings.self,
        ])
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = appSchema
        let persistentConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [persistentConfiguration])
            seedDefaultSettings(in: container)
            return container
        } catch {
            debugPrint("Failed to create persistent ModelContainer, using in-memory fallback: \(error)")
        }

        let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [memoryConfiguration])
            seedDefaultSettings(in: container)
            return container
        } catch {
            fatalError("Failed to create fallback ModelContainer: \(error)")
        }
    }

    private static func seedDefaultSettings(in container: ModelContainer) {
        let context = container.mainContext
        if (try? context.fetch(FetchDescriptor<UserSettings>(sortBy: [SortDescriptor(\.createdAt)])).isEmpty) ?? true {
            let defaultSettings = UserSettings()
            context.insert(defaultSettings)
            try? context.save()
        }
    }

    init() {
        GMSServices.provideAPIKey(GoogleAPI.defaultKey)
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
