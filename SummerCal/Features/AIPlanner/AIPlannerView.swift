import SwiftUI
import SwiftData

struct AIPlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AIPlannerViewModel()
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.messages.isEmpty {
                shortcutBar
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            if viewModel.messages.isEmpty {
                emptyState
            } else {
                messagesList
            }

            inputBar
        }
        .navigationTitle("AI Planner")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.messages.isEmpty {
                    Button(role: .destructive) {
                        viewModel.clearChat()
                    } label: {
                        Label("Clear Chat", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.orange.gradient)

            Text("AI Planner")
                .font(.title2)
                .fontWeight(.bold)

            Text("Ask me to plan your day, find places to go, or suggest activities based on your schedule and the weather.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(PlannerShortcut.allCases) { shortcut in
                    shortcutButton(shortcut)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
            }
        }
    }

    private var shortcutBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlannerShortcut.allCases) { shortcut in
                    shortcutButton(shortcut)
                        .controlSize(.small)
                }
            }
        }
    }

    private func shortcutButton(_ shortcut: PlannerShortcut) -> some View {
        Button {
            Task {
                await viewModel.useShortcut(shortcut, modelContext: modelContext)
            }
        } label: {
            Label(shortcut.label, systemImage: shortcut.icon)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.1), in: Capsule())
                .overlay(Capsule().stroke(.orange.opacity(0.3)))
        }
        .tint(.orange)
        .disabled(viewModel.isLoading)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        messageBubble(message)
                    }

                    if viewModel.isLoading {
                        loadingBubble
                    }

                    if let error = viewModel.errorMessage {
                        errorBubble(error)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding()
            }
            .onAppear { scrollProxy = proxy }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isLoading) { _, loading in
                if loading {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.orange : Color(.systemGray5))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }

    private var loadingBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                if !viewModel.currentProvider.isEmpty {
                    Text("\(viewModel.currentProvider) is thinking...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Thinking...")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .padding(12)
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 16))
            }
            Spacer(minLength: 60)
        }
    }

    private func errorBubble(_ error: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Error")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            Spacer(minLength: 60)
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask anything...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendInput()
                    }

                Button {
                    sendInput()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .orange)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
    }

    private func sendInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !viewModel.isLoading else { return }
        inputText = ""

        Task {
            let settings = UserSettings.current(in: modelContext)

            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

            let eventDescriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate { $0.startDate >= today && $0.startDate < tomorrow },
                sortBy: [SortDescriptor(\.startDate)]
            )
            let todaysEvents = (try? modelContext.fetch(eventDescriptor)) ?? []

            let weatherDescriptor = FetchDescriptor<WeatherSnapshot>(
                predicate: #Predicate { $0.forecastDate >= today && $0.forecastDate < tomorrow },
                sortBy: [SortDescriptor(\.forecastDate)]
            )
            let weather = (try? modelContext.fetch(weatherDescriptor)).flatMap { $0.first }.map { "\($0.condition), \(Int($0.temperatureCelsius))°C" }

            let placeDescriptor = FetchDescriptor<PlaceCandidate>(sortBy: [SortDescriptor(\.createdAt)])
            let places = (try? modelContext.fetch(placeDescriptor)) ?? []

            let sortedEvents = todaysEvents.sorted { $0.startDate < $1.startDate }
            var windows: [DateInterval] = []
            let dayStart = max(today, Date())
            let dayEnd = tomorrow
            var cursor = dayStart
            for event in sortedEvents where !event.isAllDay {
                if max(event.startDate, cursor) > cursor {
                    windows.append(DateInterval(start: cursor, end: min(event.startDate, dayEnd)))
                }
                cursor = max(cursor, event.endDate)
            }
            if cursor < dayEnd {
                windows.append(DateInterval(start: cursor, end: dayEnd))
            }
            windows = windows.filter { $0.duration >= 1200 }

            let context = AIPlannerContext(
                todaysEvents: todaysEvents,
                freeWindows: windows,
                weatherSummary: weather,
                nearbyPlaces: places,
                preferences: settings
            )

            await viewModel.sendMessage(text, context: context, modelContext: modelContext)
        }
    }
}
