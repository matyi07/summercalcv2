import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appRouter: AppRouter
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var weatherService: WeatherService

    @State private var viewModel = TodayViewModel()
    @State private var showAddEvent = false
    @State private var isRefreshing = false
    @State private var weatherFetched = false
    @State private var selectedSuggestion: ActivitySuggestion?

    @Query(sort: \CalendarEvent.startDate) private var allEvents: [CalendarEvent]
    @Query(sort: \ActivitySuggestion.date) private var allSuggestions: [ActivitySuggestion]
    @Query(sort: \IncomeEntry.date) private var allIncome: [IncomeEntry]
    @Query(sort: \WorkSession.date) private var allSessions: [WorkSession]

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default: return "Good Night"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                greetingSection
                weatherStrip
                if let next = viewModel.nextEvent {
                    nextEventCard(next)
                }
                if viewModel.isFreeDay {
                    freeDayBanner
                }
                if !viewModel.suggestions.isEmpty {
                    suggestionsSection
                }
                moneyCard
            }
            .padding()
        }
        .refreshable {
            isRefreshing = true
            await viewModel.loadDay(modelContext: modelContext)
            isRefreshing = false
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                showAddEvent = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.orange))
                    .shadow(radius: 4)
            }
            .padding()
        }
        .sheet(isPresented: $showAddEvent) {
            NavigationStack {
                AddEventView()
            }
        }
        .sheet(item: $selectedSuggestion) { suggestion in
            suggestionDetailView(suggestion)
        }
        .task {
            await viewModel.loadDay(modelContext: modelContext)
        }
        .onChange(of: locationService.currentCoordinate) { _, coord in
            guard let coord = coord else { return }
            Task {
                let settings = UserSettings.current(in: modelContext)
                _ = try? await weatherService.fetchWeather(for: coord, jwt: settings.weatherKitJWT, context: modelContext)
                await viewModel.loadDay(modelContext: modelContext)
            }
        }
    }

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.largeTitle.weight(.bold))
            Text(formattedDate(Date()))
                .font(.subheadline)
                .foregroundColor(Color(.systemGray))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weatherStrip: some View {
        HStack(spacing: 12) {
            if let w = viewModel.weather {
                Image(systemName: weatherIcon(for: w.condition))
                    .font(.title)
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(w.temperatureCelsius))°C  \(w.condition)")
                        .font(.headline)
                    Text(locationService.currentCity ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                }
            } else {
                Image(systemName: "cloud.sun")
                    .font(.title)
                    .foregroundColor(.gray)
                VStack(alignment: .leading, spacing: 2) {
                    Text("--°C")
                        .font(.headline)
                    Text(locationService.currentCity ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                }
            }
            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 4))
    }

    @ViewBuilder
    private func nextEventCard(_ event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Up Next", systemImage: "bell.badge")
                .font(.caption.weight(.semibold))
                .foregroundColor(.orange)
                .textCase(.uppercase)

            Text(event.title)
                .font(.title3.weight(.semibold))

            HStack(spacing: 16) {
                Text(event.startDate, style: .time)
                    .font(.subheadline)
                    .foregroundColor(Color(.systemGray))
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))
        .onTapGesture {
            appRouter.navigateToEvent(event.id)
        }
    }

    private var freeDayBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.max")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("Your day is mostly free.")
                .font(.headline)

            Text("Want a plan based on weather and places nearby?")
                .font(.subheadline)
                .foregroundColor(Color(.systemGray))
                .multilineTextAlignment(.center)

            Button {
                Task {
                    viewModel.isLoadingSuggestions = true
                    await viewModel.refreshSuggestions(modelContext: modelContext, weather: viewModel.weather, location: locationService.currentCoordinate, settings: UserSettings.current(in: modelContext))
                    viewModel.isLoadingSuggestions = false
                }
            } label: {
                HStack {
                    if viewModel.isLoadingSuggestions {
                        ProgressView().tint(.white)
                    }
                    Text("Get Suggestions")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.orange))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 4))
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggestions")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.suggestions) { suggestion in
                        suggestionCard(suggestion)
                    }
                }
            }
        }
    }

    private func suggestionCard(_ suggestion: ActivitySuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(suggestion.title)
                .font(.headline)
                .lineLimit(2)

            if let category = suggestion.category {
                Text(category.capitalized)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.blue))
            }

            HStack(spacing: 12) {
                if let duration = suggestion.estimatedDurationMinutes {
                    Label("\(duration)m", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                }
                if let cost = suggestion.estimatedCostLevel {
                    Label(String(repeating: "$", count: min(cost, 3)), systemImage: "dollarsign.circle")
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                }
            }
        }
        .padding()
        .frame(width: 180, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 4))
        .onTapGesture {
            selectedSuggestion = suggestion
        }
    }

    private var moneyCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("This Month")
                    .font(.headline)
                Spacer()
                if let goal = viewModel.monthlyGoal, goal > 0 {
                    Text("\(viewModel.monthlyEarnings, format: .currency(code: viewModel.currencyCode)) / \(goal, format: .currency(code: viewModel.currencyCode))")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Color(.systemGray))
                } else {
                    Text(viewModel.monthlyEarnings, format: .currency(code: viewModel.currencyCode))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Color(.systemGray))
                }
            }

            if let goal = viewModel.monthlyGoal, goal > 0 {
                ProgressView(value: min(viewModel.monthlyEarnings / goal, 1.0))
                    .tint(.orange)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)

                Text("\(Int(min(viewModel.monthlyEarnings / goal * 100, 100)))% of monthly goal")
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
            } else {
                Text("No monthly goal set")
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 4))
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    private func weatherIcon(for condition: String) -> String {
        let lower = condition.lowercased()
        if lower.contains("rain") { return "cloud.rain" }
        if lower.contains("snow") { return "cloud.snow" }
        if lower.contains("cloud") { return "cloud" }
        if lower.contains("clear") || lower.contains("sun") { return "sun.max" }
        if lower.contains("fog") { return "cloud.fog" }
        if lower.contains("wind") { return "wind" }
        return "cloud.sun"
    }

    private func suggestionDetailView(_ suggestion: ActivitySuggestion) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(suggestion.title)
                            .font(.largeTitle.weight(.bold))

                        if let category = suggestion.category {
                            Text(category.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.blue))
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        Text(suggestion.summary)
                            .font(.body)
                            .foregroundColor(Color(.systemGray))
                    }

                    HStack(spacing: 20) {
                        if let duration = suggestion.estimatedDurationMinutes {
                            VStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                                Text("\(duration) min")
                                    .font(.caption)
                                    .foregroundColor(Color(.systemGray))
                            }
                        }

                        if let cost = suggestion.estimatedCostLevel {
                            VStack(spacing: 4) {
                                Image(systemName: "dollarsign.circle")
                                    .font(.title3)
                                    .foregroundColor(.green)
                                Text(String(repeating: "$", count: min(cost, 3)))
                                    .font(.caption)
                                    .foregroundColor(Color(.systemGray))
                            }
                        }
                    }

                    if let weatherReason = suggestion.weatherReason {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weather")
                                .font(.headline)
                            HStack(spacing: 8) {
                                Image(systemName: "cloud.sun")
                                    .foregroundColor(.blue)
                                Text(weatherReason)
                                    .font(.subheadline)
                                    .foregroundColor(Color(.systemGray))
                            }
                        }
                    }

                    if let placeName = suggestion.placeName {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nearby Place")
                                .font(.headline)
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.orange)
                                Text(placeName)
                                    .font(.subheadline)
                                    .foregroundColor(Color(.systemGray))
                            }
                        }
                    }

                    Spacer()

                    Button {
                        selectedSuggestion = nil
                    } label: {
                        Text("Dismiss")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Color.orange))
                    }
                }
                .padding()
            }
            .navigationTitle("Suggestion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { selectedSuggestion = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
