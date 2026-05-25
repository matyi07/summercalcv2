import SwiftUI
import SwiftData

struct MoneyView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = MoneyViewModel()
    @State private var showAddIncome: Bool = false
    @State private var showAddExpense: Bool = false
    @State private var showAddWork: Bool = false
    @State private var showAddSavingsEntry: Bool = false
    @State private var showAddSavingsGoal: Bool = false
    @State private var editIncome: IncomeEntry?
    @State private var editExpense: ExpenseEntry?
    @State private var editSession: WorkSession?
    @State private var editSavingsEntry: SavingsEntry?
    @State private var editSavingsGoal: SavingsGoal?
    @State private var showAllIncome: Bool = false
    @State private var showAllExpenses: Bool = false
    @State private var showAllWorkSessions: Bool = false
    @State private var showAllSavings: Bool = false

    var body: some View {
        List {
            monthlySummarySection

            if viewModel.monthlyGoal > 0 {
                goalProgressSection
            }

            savingsOverviewSection

            Section {
                HStack {
                    Text("Spendable Daily Average")
                    Spacer()
                    Text(viewModel.formatCurrency(viewModel.dailyAverage))
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Entries")
                    Spacer()
                    Text("\(viewModel.spendableIncomeEntries.count + viewModel.expenseEntries.count)")
                        .foregroundStyle(Color(.systemGray))
                }
                HStack {
                    Text("Work Sessions")
                    Spacer()
                    Text("\(viewModel.workSessions.count)")
                        .foregroundStyle(Color(.systemGray))
                }
            }

            Section {
                if viewModel.spendableIncomeEntries.isEmpty {
                    ContentUnavailableView(
                        "No Income Entries",
                        systemImage: "banknote",
                        description: Text("Add your first income entry to start tracking.")
                    )
                } else {
                    ForEach(visibleIncomeEntries) { entry in
                        incomeRow(entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editIncome = entry
                                showAddIncome = true
                            }
                    }
                    .onDelete { offsets in
                        for idx in offsets {
                            viewModel.deleteIncomeEntry(visibleIncomeEntries[idx], modelContext: modelContext)
                        }
                    }
                    moreButton(
                        isShowingAll: $showAllIncome,
                        totalCount: viewModel.spendableIncomeEntries.count,
                        defaultCount: viewModel.recentIncomeEntries.count,
                        label: "income entries"
                    )
                }
                Button {
                    editIncome = nil
                    showAddIncome = true
                } label: {
                    Label("Add Income Entry", systemImage: "plus.circle")
                }
            } header: {
                Text("Income")
            } footer: {
                Text("Income categorized as Savings is excluded from spendable monthly statistics and counted in the savings balance.")
            }

            Section {
                if viewModel.expenseEntries.isEmpty {
                    ContentUnavailableView(
                        "No Expenses",
                        systemImage: "creditcard",
                        description: Text("Track your spending by adding expenses.")
                    )
                } else {
                    ForEach(visibleExpenseEntries) { entry in
                        expenseRow(entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editExpense = entry
                                showAddExpense = true
                            }
                    }
                    .onDelete { offsets in
                        for idx in offsets {
                            viewModel.deleteExpenseEntry(visibleExpenseEntries[idx], modelContext: modelContext)
                        }
                    }
                    moreButton(
                        isShowingAll: $showAllExpenses,
                        totalCount: viewModel.expenseEntries.count,
                        defaultCount: viewModel.recentExpenseEntries.count,
                        label: "expenses"
                    )
                }
                Button {
                    editExpense = nil
                    showAddExpense = true
                } label: {
                    Label("Add Expense", systemImage: "plus.circle")
                }
            } header: {
                Text("Expenses")
            }

            Section {
                if viewModel.workSessions.isEmpty {
                    ContentUnavailableView(
                        "No Work Sessions",
                        systemImage: "clock.badge.checkmark",
                        description: Text("Track your hourly work and earnings.")
                    )
                } else if visibleWorkSessions.isEmpty {
                    ContentUnavailableView(
                        "No Upcoming Work Sessions",
                        systemImage: "clock",
                        description: Text("Tap More to see past work sessions for this month.")
                    )
                    moreButton(
                        isShowingAll: $showAllWorkSessions,
                        totalCount: viewModel.workSessions.count,
                        defaultCount: 0,
                        label: "work sessions"
                    )
                } else {
                    ForEach(visibleWorkSessions) { session in
                        workSessionRow(session)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editSession = session
                                showAddWork = true
                            }
                    }
                    .onDelete { offsets in
                        for idx in offsets {
                            viewModel.deleteWorkSession(visibleWorkSessions[idx], modelContext: modelContext)
                        }
                    }
                    moreButton(
                        isShowingAll: $showAllWorkSessions,
                        totalCount: viewModel.workSessions.count,
                        defaultCount: viewModel.upcomingWorkSessions.count,
                        label: "work sessions"
                    )
                }
                Button {
                    editSession = nil
                    showAddWork = true
                } label: {
                    Label("Add Work Session", systemImage: "plus.circle")
                }
            } header: {
                Text("Work Sessions")
            }
        }
        .navigationTitle("Money")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                monthNavigation
            }
        }
        .onAppear {
            reloadMoney()
        }
        .onChange(of: viewModel.selectedMonth) { _, _ in
            resetSectionExpansion()
            reloadMoney()
        }
        .onReceive(NotificationCenter.default.publisher(for: .summerCalMoneyChanged)) { notification in
            if let savedDate = notification.userInfo?["date"] as? Date {
                viewModel.selectedMonth = savedDate
            }
            reloadMoney()
        }
        .sheet(isPresented: $showAddIncome) {
            AddIncomeView(existingEntry: editIncome) {
                reloadMoney()
            }
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView(
                existingEntry: editExpense,
                onSave: {
                    reloadMoney()
                },
                onSavedExpense: { entry in
                    viewModel.selectedMonth = entry.date
                    reloadMoney()
                }
            )
        }
        .sheet(isPresented: $showAddWork) {
            AddWorkSessionView(existingSession: editSession) {
                reloadMoney()
            }
        }
        .sheet(isPresented: $showAddSavingsEntry) {
            AddSavingsEntryView(existingEntry: editSavingsEntry, goals: viewModel.activeSavingsGoals) {
                reloadMoney()
            }
        }
        .sheet(isPresented: $showAddSavingsGoal) {
            AddSavingsGoalView(existingGoal: editSavingsGoal) {
                reloadMoney()
            }
        }
    }

    private func reloadMoney() {
        viewModel.loadSettings(modelContext: modelContext)
        viewModel.loadEntries(modelContext: modelContext)
        Task {
            await viewModel.refreshCurrencyConversions()
        }
    }

    private var visibleIncomeEntries: [IncomeEntry] {
        showAllIncome ? viewModel.spendableIncomeEntries : viewModel.recentIncomeEntries
    }

    private var visibleExpenseEntries: [ExpenseEntry] {
        showAllExpenses ? viewModel.expenseEntries : viewModel.recentExpenseEntries
    }

    private var visibleWorkSessions: [WorkSession] {
        showAllWorkSessions ? viewModel.workSessions : viewModel.upcomingWorkSessions
    }

    private var visibleSavingsEntries: [SavingsEntry] {
        showAllSavings ? viewModel.savingsEntries : viewModel.recentSavingsEntries
    }

    private func resetSectionExpansion() {
        showAllIncome = false
        showAllExpenses = false
        showAllWorkSessions = false
        showAllSavings = false
    }

    @ViewBuilder
    private func moreButton(
        isShowingAll: Binding<Bool>,
        totalCount: Int,
        defaultCount: Int,
        label: String
    ) -> some View {
        if totalCount > defaultCount {
            Button {
                withAnimation {
                    isShowingAll.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Label(
                        isShowingAll.wrappedValue ? "Show Less" : "More \(label)",
                        systemImage: isShowingAll.wrappedValue ? "chevron.up" : "chevron.down"
                    )
                    Spacer()
                    Text("\(totalCount)")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                }
            }
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
            .frame(minWidth: 44, minHeight: 44)

            Text(viewModel.monthLabel)
                .font(.caption.weight(.medium))
                .frame(minWidth: 100)

            Button {
                viewModel.navigateMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.medium))
            }
            .frame(minWidth: 44, minHeight: 44)
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
                        Text("Net Balance")
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray))
                        Text(viewModel.formatCurrency(viewModel.netBalance))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(viewModel.netBalance >= 0 ? Color.green.gradient : Color.red.gradient)
                        Text("Spendable + savings")
                            .font(.caption2)
                            .foregroundStyle(Color(.systemGray))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Spendable")
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray))
                        Text(viewModel.formatCurrency(viewModel.spendableBalance))
                            .font(.headline)
                            .foregroundColor(viewModel.spendableBalance >= 0 ? .blue : .red)
                    }
                }

                if let error = viewModel.currencyConversionError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Income")
                            .font(.caption2)
                            .foregroundStyle(Color(.systemGray))
                        Text(viewModel.formatCurrency(viewModel.totalIncome))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Expenses")
                            .font(.caption2)
                            .foregroundStyle(Color(.systemGray))
                        Text(viewModel.formatCurrency(viewModel.totalExpenses))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Work Sessions")
                            .font(.caption2)
                            .foregroundStyle(Color(.systemGray))
                        Text(viewModel.formatCurrency(viewModel.totalWorkEarnings))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Savings")
                            .font(.caption2)
                            .foregroundStyle(Color(.systemGray))
                        Text(viewModel.formatCurrency(viewModel.totalSavingsBalance))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var savingsOverviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Savings Account")
                            .font(.headline)
                        Text(viewModel.formatCurrency(viewModel.totalSavingsBalance))
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.purple)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Needed")
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray))
                        Text(viewModel.formatCurrency(viewModel.remainingSavingsNeeded))
                            .font(.subheadline.weight(.semibold))
                    }
                }

                if viewModel.totalSavingsGoalTarget > 0 {
                    ProgressView(value: viewModel.savingsGoalProgress)
                        .tint(.purple)
                    Text("\(Int(viewModel.savingsGoalProgress * 100))% funded across \(viewModel.activeSavingsGoals.count) goal\(viewModel.activeSavingsGoals.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                } else {
                    Text("Create goals for trips, gear, emergency funds, or anything with a price.")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                }

                if viewModel.unassignedSavingsBalance != 0 {
                    Label("Unassigned: \(viewModel.formatCurrency(viewModel.unassignedSavingsBalance))", systemImage: "tray")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                }
            }
            .padding(.vertical, 4)

            if !viewModel.activeSavingsGoals.isEmpty {
                ForEach(viewModel.activeSavingsGoals) { goal in
                    savingsGoalRow(goal)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editSavingsGoal = goal
                            showAddSavingsGoal = true
                        }
                }
                .onDelete { offsets in
                    let goals = viewModel.activeSavingsGoals
                    for idx in offsets {
                        viewModel.deleteSavingsGoal(goals[idx], modelContext: modelContext)
                    }
                }
            }

            if !viewModel.savingsEntries.isEmpty {
                ForEach(visibleSavingsEntries) { entry in
                    savingsEntryRow(entry)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editSavingsEntry = entry
                            showAddSavingsEntry = true
                        }
                }
                .onDelete { offsets in
                    for idx in offsets {
                        viewModel.deleteSavingsEntry(visibleSavingsEntries[idx], modelContext: modelContext)
                    }
                }
                moreButton(
                    isShowingAll: $showAllSavings,
                    totalCount: viewModel.savingsEntries.count,
                    defaultCount: viewModel.recentSavingsEntries.count,
                    label: "savings entries"
                )
            }

            HStack(spacing: 12) {
                Button {
                    editSavingsEntry = nil
                    showAddSavingsEntry = true
                } label: {
                    Label("Add Savings", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.borderless)

                Button {
                    editSavingsGoal = nil
                    showAddSavingsGoal = true
                } label: {
                    Label("Add Goal", systemImage: "target")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.borderless)
            }
        } header: {
            Text("Savings")
        }
    }

    private var goalProgressSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Monthly Goal")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                    Spacer()
                    Text("\(viewModel.formatCurrency(viewModel.spendableBalance)) / \(viewModel.formattedGoal)")
                        .font(.caption)
                        .fontWeight(.medium)
                }

                ProgressView(value: viewModel.goalProgress)
                    .tint(viewModel.goalProgress >= 1.0 ? .green : .orange)

                HStack {
                    Text("\(Int(viewModel.goalProgress * 100))% complete")
                        .font(.caption2)
                        .foregroundStyle(Color(.systemGray))
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
                        .foregroundStyle(Color(.systemGray))
                        .lineLimit(1)
                }
                Text(viewModel.formatDate(entry.date))
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray3))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.formatCurrency(viewModel.displayAmount(for: entry)))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                if let source = viewModel.sourceCurrencyLabel(for: entry) {
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(Color(.systemGray))
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray3))
            }
        }
        .padding(.vertical, 2)
        .frame(minHeight: 44)
    }

    private func expenseRow(_ entry: ExpenseEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.category.icon)
                .font(.title3)
                .frame(width: 32, height: 32)
                .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.category.label)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Image(systemName: paymentIcon(entry.paymentMethod))
                        .font(.caption2)
                    Text(entry.paymentMethod.capitalized)
                        .font(.caption2)
                    Text(viewModel.formatDate(entry.date))
                        .font(.caption2)
                }
                .foregroundStyle(Color(.systemGray3))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.formatCurrency(viewModel.displayAmount(for: entry)))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                if let source = viewModel.sourceCurrencyLabel(for: entry) {
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(Color(.systemGray))
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray3))
            }
        }
        .padding(.vertical, 2)
        .frame(minHeight: 44)
    }

    private func workSessionRow(_ session: WorkSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.checkmark")
                .font(.title3)
                .frame(width: 32, height: 32)
                .background(.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.workTypeName ?? "Work Session")
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    Text(viewModel.formatDuration(session))
                        .font(.caption)
                    Text("at \(viewModel.workRateLabel(for: session))")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                }
                if !session.descriptionText.isEmpty {
                    Text(session.descriptionText)
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                        .lineLimit(1)
                }
                Text(viewModel.formatDate(session.date))
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray3))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.formatCurrency(viewModel.displayAmount(for: session)))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.sessionHasEnded(session) ? .blue : Color(.systemGray))
                Text(viewModel.workSessionStatusLabel(for: session))
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray))
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray3))
            }
        }
        .padding(.vertical, 2)
        .frame(minHeight: 44)
    }

    private func categoryIcon(_ cat: IncomeCategory) -> String {
        switch cat {
        case .salary: return "building.2"
        case .freelance: return "laptopcomputer"
        case .gig: return "figure.walk"
        case .savings: return "banknote.fill"
        case .other: return "ellipsis.circle"
        }
    }

    private func savingsGoalRow(_ goal: SavingsGoal) -> some View {
        let progress = viewModel.progress(for: goal)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: goal.iconName)
                    .font(.title3)
                    .frame(width: 32, height: 32)
                    .background(.purple.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.body.weight(.medium))
                    Text("\(viewModel.formatCurrency(viewModel.allocatedAmount(for: goal))) of \(viewModel.primarySavingsTargetText(for: goal))")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                    if let secondary = viewModel.secondarySavingsTargetText(for: goal) {
                        Text(secondary)
                            .font(.caption2)
                            .foregroundStyle(Color(.systemGray3))
                    }
                }

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.purple)
            }

            ProgressView(value: progress)
                .tint(.purple)

            if viewModel.remainingAmount(for: goal) > 0 {
                Text("\(viewModel.formatCurrency(viewModel.remainingAmount(for: goal))) still needed")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray))
            } else {
                Label("Funded", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private func savingsEntryRow(_ entry: SavingsEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.amount >= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.title3)
                .frame(width: 32, height: 32)
                .background(.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .foregroundColor(entry.amount >= 0 ? .purple : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.goalName(for: entry.goalId))
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                        .lineLimit(1)
                }
                Text(viewModel.formatDate(entry.date))
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray3))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.primarySavingsAmountText(for: entry))
                    .font(.body.weight(.semibold))
                    .foregroundColor(entry.amount >= 0 ? .purple : .orange)
                if let secondary = viewModel.secondarySavingsAmountText(for: entry) {
                    Text(secondary)
                        .font(.caption2)
                        .foregroundStyle(Color(.systemGray))
                }
            }
        }
        .padding(.vertical, 2)
        .frame(minHeight: 44)
    }

    private func paymentIcon(_ method: String) -> String {
        switch method.lowercased() {
        case "card": return "creditcard"
        case "cash": return "banknote"
        case "transfer": return "arrow.left.arrow.right"
        case "direct debit": return "arrow.down.forward"
        default: return "creditcard"
        }
    }
}
