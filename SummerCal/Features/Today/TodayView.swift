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
    @State private var lastWeatherFetch: Date = .distantPast
    @State private var selectedSuggestion: ActivitySuggestion?
    @State private var suggestionPreferenceText: String = ""
    @State private var showAllSuggestions = false
    @FocusState private var suggestionPreferenceFocused: Bool

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
                if !viewModel.hourlyForecast.isEmpty {
                    hourlyForecastSection
                }
                if !viewModel.todaysEvents.isEmpty {
                    todaysEventsSection
                }
                freeDaySummaryCard
                if !viewModel.suggestions.isEmpty {
                    suggestionsSection
                } else if let err = viewModel.suggestionError {
                    suggestionErrorCard(err)
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
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    suggestionPreferenceFocused = false
                }
            }
        }
        .task {
            await viewModel.loadDay(modelContext: modelContext)
        }
        .onChange(of: locationService.currentCoordinate) { _, coord in
            guard let coord = coord else { return }
            let now = Date()
            guard now.timeIntervalSince(lastWeatherFetch) > 900 else { return }
            Task {
                let settings = UserSettings.current(in: modelContext)
                _ = try? await weatherService.fetchWeather(for: coord, jwt: settings.weatherKitJWT, context: modelContext)
                lastWeatherFetch = Date()
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

    private var todaysEventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Events")
                .font(.headline)

            ForEach(viewModel.todaysEvents.sorted(by: { $0.startDate < $1.startDate })) { event in
                Button {
                    appRouter.navigateToEvent(event.id)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(eventColor(event))
                            .frame(width: 4, height: 58)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            Text(eventTimeSummary(event))
                                .font(.caption)
                                .foregroundStyle(Color(.systemGray))

                            if let notes = event.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(Color(.systemGray))
                                    .lineLimit(2)
                            }

                            HStack(spacing: 8) {
                                if let category = event.category, !category.isEmpty {
                                    Label(category.capitalized, systemImage: "tag")
                                        .font(.caption2)
                                        .foregroundStyle(Color(.systemGray))
                                }
                                if let location = event.location, !location.isEmpty {
                                    Label(location, systemImage: "mappin.and.ellipse")
                                        .font(.caption2)
                                        .foregroundStyle(Color(.systemGray))
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        if event.notificationEnabled {
                            VStack(alignment: .trailing, spacing: 4) {
                                Image(systemName: "bell.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text(reminderSummary(event))
                                    .font(.caption2)
                                    .foregroundStyle(Color(.systemGray))
                            }
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Color(.systemGray3))
                            .padding(.top, 2)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 2))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private func eventTimeSummary(_ event: CalendarEvent) -> String {
        if event.isAllDay {
            return "All day, \(formattedDate(event.startDate))"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        return "\(dateFormatter.string(from: event.startDate)), \(timeFormatter.string(from: event.startDate)) - \(timeFormatter.string(from: event.endDate))"
    }

    private func reminderSummary(_ event: CalendarEvent) -> String {
        var labels = event.reminderOffsets().prefix(2).map(reminderLabel)
        if event.customReminderDate != nil {
            labels.append("Custom")
        }
        if labels.isEmpty {
            return "On"
        }
        let totalCount = event.reminderOffsets().count + (event.customReminderDate == nil ? 0 : 1)
        if totalCount > labels.count {
            return labels.joined(separator: ", ") + " +\(totalCount - labels.count)"
        }
        return labels.joined(separator: ", ")
    }

    private func reminderLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "At start"
        case 60: return "1 hour"
        case 1440: return "1 day"
        default: return "\(minutes) min"
        }
    }

    private func eventColor(_ event: CalendarEvent) -> Color {
        if event.isOutdoor { return .green }
        switch event.category {
        case "meeting": return .blue
        case "workout": return .orange
        case "appointment": return .red
        case "travel": return .purple
        default: return .gray
        }
    }

    private var hourlyForecastSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hourly Forecast")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(viewModel.hourlyForecast.prefix(12).enumerated()), id: \.element.id) { _, snap in
                        VStack(spacing: 6) {
                            Text(hourLabel(snap.forecastDate))
                                .font(.caption2)
                                .foregroundStyle(Color(.systemGray))
                            Image(systemName: weatherIcon(for: snap.condition))
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.blue.gradient)
                            Text("\(Int(snap.temperatureCelsius))°C")
                                .font(.caption)
                                .fontWeight(.medium)
                            if let wind = snap.windSpeedKph {
                                Text("\(Int(wind)) km/h")
                                    .font(.caption2)
                                    .foregroundStyle(Color(.systemGray))
                            }
                            Text("\(Int(snap.precipitationChance * 100))%")
                                .font(.caption2)
                                .foregroundStyle(snap.precipitationChance > 0.3 ? .blue : Color(.systemGray3))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                    }

                    if viewModel.hourlyForecast.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.title2)
                                .foregroundColor(Color(.systemGray))
                            Text("No hourly data available")
                                .font(.caption)
                                .foregroundStyle(Color(.systemGray))
                        }
                        .padding(20)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func hourLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date)
    }

    private var freeDaySummaryCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: viewModel.isFreeDay ? "sun.max" : "calendar")
                    .font(.title2)
                    .foregroundColor(viewModel.isFreeDay ? .orange : Color(.systemGray))

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.freeDaySummary)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if !viewModel.freeWindows.isEmpty {
                        Text(freeWindowsSummary)
                            .font(.caption)
                            .foregroundColor(Color(.systemGray))
                    }
                }
                Spacer()
            }

            suggestionPreferenceField

            Button {
                suggestionPreferenceFocused = false
                showAllSuggestions = false
                Task {
                    viewModel.isLoadingSuggestions = true
                    viewModel.suggestionError = nil
                    await viewModel.refreshSuggestions(
                        modelContext: modelContext,
                        weather: viewModel.weather,
                        location: locationService.currentCoordinate,
                        settings: UserSettings.current(in: modelContext),
                        customPreferences: suggestionPreferenceText
                    )
                    viewModel.isLoadingSuggestions = false
                }
            } label: {
                HStack {
                    if viewModel.isLoadingSuggestions {
                        ProgressView().tint(.white)
                    }
                    Text("Get Suggestions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.orange))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 4))
    }

    private var suggestionPreferenceField: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.subheadline)
                .foregroundColor(.orange)
                .padding(.top, 3)

            TextField("Mood, distance, food, budget, or anything else", text: $suggestionPreferenceText, axis: .vertical)
                .lineLimit(1...4)
                .focused($suggestionPreferenceFocused)
                .submitLabel(.done)
                .onSubmit {
                    suggestionPreferenceFocused = false
                }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(suggestionPreferenceFocused ? Color.orange : Color(.systemGray5), lineWidth: 1)
        }
    }

    private var freeWindowsSummary: String {
        let totalMin = Int((viewModel.freeWindows.reduce(0.0) { $0 + $1.duration }) / 60.0)
        let h = totalMin / 60
        let m = totalMin % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m available" }
        if h > 0 { return "\(h)h available" }
        return "\(m)m available"
    }

    private func suggestionErrorCard(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
                .font(.caption)
            Text(message)
                .font(.caption)
                .foregroundColor(Color(.systemGray))
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.1)))
        .padding(.horizontal)
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Suggestion")
                    .font(.headline)
                Spacer()
                if viewModel.suggestions.count > 1 {
                    Button(showAllSuggestions ? "Show Less" : "View More") {
                        withAnimation {
                            showAllSuggestions.toggle()
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(.orange)
                }
            }

            VStack(spacing: 10) {
                ForEach(visibleSuggestions) { suggestion in
                    suggestionCard(suggestion)
                }
            }
        }
    }

    private var visibleSuggestions: [ActivitySuggestion] {
        showAllSuggestions ? viewModel.suggestions : Array(viewModel.suggestions.prefix(1))
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
