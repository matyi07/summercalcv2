import SwiftUI
import SwiftData

struct MoneyView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = MoneyViewModel()
    @State private var showAddIncome: Bool = false
    @State private var showAddWork: Bool = false
    @State private var showSettings: Bool = false
    @State private var settingsGoalText: String = ""
    @State private var settingsCurrency: String = "USD"
    @State private var pendingIncomeRefresh: Bool = false
    @State private var pendingWorkRefresh: Bool = false

    private let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "MXN", "BRL", "KRW"]

    var body: some View {
        List {
            monthlySummarySection

            if viewModel.monthlyGoal > 0 {
                goalProgressSection
            }

            Section {
                HStack {
                    Text("Daily Average")
                    Spacer()
                    Text(viewModel.formatCurrency(viewModel.dailyAverage))
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Entries")
                    Spacer()
                    Text("\(viewModel.incomeEntries.count)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Work Sessions")
                    Spacer()
                    Text("\(viewModel.workSessions.count)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Income Entries") {
                if viewModel.incomeEntries.isEmpty {
                    ContentUnavailableView(
                        "No Income Entries",
                        systemImage: "banknote",
                        description: Text("Add your first income entry to start tracking.")
                    )
                } else {
                    ForEach(viewModel.incomeEntries) { entry in
                        incomeRow(entry)
                    }
                    .onDelete { offsets in
                        for idx in offsets {
                            viewModel.deleteIncomeEntry(viewModel.incomeEntries[idx], modelContext: modelContext)
                        }
                    }
                }

                Button {
                    showAddIncome = true
                } label: {
                    Label("Add Income Entry", systemImage: "plus.circle")
                }
            }

            Section("Work Sessions") {
                if viewModel.workSessions.isEmpty {
                    ContentUnavailableView(
                        "No Work Sessions",
                        systemImage: "clock.badge.checkmark",
                        description: Text("Track your hourly work and earnings.")
                    )
                } else {
                    ForEach(viewModel.workSessions) { session in
                        workSessionRow(session)
                    }
                    .onDelete { offsets in
                        for idx in offsets {
                            viewModel.deleteWorkSession(viewModel.workSessions[idx], modelContext: modelContext)
                        }
                    }
                }

                Button {
                    showAddWork = true
                } label: {
                    Label("Add Work Session", systemImage: "plus.circle")
                }
            }

            Section {
                Button {
                    settingsGoalText = String(format: "%.0f", viewModel.monthlyGoal)
                    settingsCurrency = viewModel.currencyCode
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .navigationTitle("Money")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    monthNavigation
                }
            }
        }
        .onAppear {
            viewModel.loadSettings(modelContext: modelContext)
            viewModel.loadEntries(modelContext: modelContext)
        }
        .onChange(of: viewModel.selectedMonth) { _, _ in
            viewModel.loadEntries(modelContext: modelContext)
        }
        .sheet(isPresented: $showAddIncome) {
            AddIncomeView {
                viewModel.loadEntries(modelContext: modelContext)
            }
        }
        .sheet(isPresented: $showAddWork) {
            AddWorkSessionView {
                viewModel.loadEntries(modelContext: modelContext)
            }
        }
        .sheet(isPresented: $showSettings) {
            moneySettingsSheet
        }
    }

    private var monthNavigation: some View {
        HStack(spacing: 2) {
            Button {
                viewModel.navigateMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.medium))
            }

            Text(viewModel.monthLabel)
                .font(.caption.weight(.medium))
                .frame(minWidth: 100)

            Button {
                viewModel.navigateMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.medium))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6), in: Capsule())
    }

    private var monthlySummarySection: some View {
        Section {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Gross")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.formatCurrency(viewModel.totalGross))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange.gradient)
                    }
                    Spacer()
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Work Earnings")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(viewModel.formatCurrency(viewModel.totalWorkEarnings))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Income Entries")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(viewModel.formatCurrency(viewModel.totalIncome))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var goalProgressSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Monthly Goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.formatCurrency(viewModel.totalGross)) / \(viewModel.formattedGoal)")
                        .font(.caption)
                        .fontWeight(.medium)
                }

                ProgressView(value: viewModel.goalProgress)
                    .tint(viewModel.goalProgress >= 1.0 ? .green : .orange)

                HStack {
                    Text("\(Int(viewModel.goalProgress * 100))% complete")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if viewModel.goalProgress >= 1.0 {
                        Label("Goal reached!", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }

    private func incomeRow(_ entry: IncomeEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon(entry.category))
                .font(.title3)
                .frame(width: 32, height: 32)
                .background(.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.source)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if !entry.descriptionText.isEmpty {
                    Text(entry.descriptionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(viewModel.formatDate(entry.date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(viewModel.formatCurrency(entry.amount))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.green)
        }
        .padding(.vertical, 2)
    }

    private func workSessionRow(_ session: WorkSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.checkmark")
                .font(.title3)
                .frame(width: 32, height: 32)
                .background(.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Work Session")
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    Text(viewModel.formatDuration(session))
                        .font(.caption)
                    Text("at \(viewModel.formatCurrency(session.hourlyRate))/h")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !session.descriptionText.isEmpty {
                    Text(session.descriptionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(viewModel.formatDate(session.date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(viewModel.formatCurrency(session.totalEarned))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 2)
    }

    private func categoryIcon(_ cat: IncomeCategory) -> String {
        switch cat {
        case .salary: return "building.2"
        case .freelance: return "laptopcomputer"
        case .gig: return "figure.walk"
        case .other: return "ellipsis.circle"
        }
    }

    private var moneySettingsSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Currency", selection: $settingsCurrency) {
                        ForEach(currencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                } header: {
                    Text("Currency")
                }

                Section {
                    HStack {
                        Text(settingsCurrency)
                            .foregroundStyle(.secondary)
                        TextField("Goal", text: $settingsGoalText)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    Text("Monthly Income Goal")
                } footer: {
                    Text("Set a target to track your progress throughout the month.")
                }
            }
            .navigationTitle("Money Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSettings = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.currencyCode = settingsCurrency
                        let cleaned = settingsGoalText.replacingOccurrences(of: ",", with: ".")
                        viewModel.monthlyGoal = Double(cleaned) ?? 0
                        viewModel.saveGoal(modelContext: modelContext)
                        showSettings = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
