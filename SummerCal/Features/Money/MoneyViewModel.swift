import Foundation
import SwiftData

@Observable
final class MoneyViewModel {
    var selectedMonth: Date = Date()
    var incomeEntries: [IncomeEntry] = []
    var expenseEntries: [ExpenseEntry] = []
    var workSessions: [WorkSession] = []
    var allWorkSessions: [WorkSession] = []
    var savingsEntries: [SavingsEntry] = []
    var savingsGoals: [SavingsGoal] = []
    var savingsIncomeEntries: [IncomeEntry] = []
    var monthlyGoal: Double = 0
    var currencyCode: String = "USD"
    var entryPreviewLimit: Int = 5
    var incomeDisplayAmounts: [UUID: Double] = [:]
    var expenseDisplayAmounts: [UUID: Double] = [:]
    var workDisplayAmounts: [UUID: Double] = [:]
    var workSpendableDisplayAmounts: [UUID: Double] = [:]
    var workSavingsDisplayAmounts: [UUID: Double] = [:]
    var workSavingsPrimaryDisplayAmounts: [UUID: Double] = [:]
    var savingsDisplayAmounts: [UUID: Double] = [:]
    var savingsPrimaryDisplayAmounts: [UUID: Double] = [:]
    var savingsIncomeDisplayAmounts: [UUID: Double] = [:]
    var savingsGoalDisplayTargets: [UUID: Double] = [:]
    var currencyConversionError: String?

    private let currencyConverter = CurrencyConversionService()

    struct StoreExpenseGroup: Identifiable {
        let id: String
        let name: String
        let count: Int
        let total: Double
    }

    var totalIncome: Double {
        incomeEntries
            .filter { $0.category != .savings }
            .reduce(0) { $0 + displayAmount(for: $1) }
    }

    var totalExpenses: Double {
        expenseEntries.reduce(0) { $0 + displayAmount(for: $1) }
    }

    var totalWorkEarnings: Double {
        workSessions
            .filter { sessionHasEnded($0) }
            .reduce(0) { $0 + displayAmount(for: $1) }
    }

    var totalWorkSpendable: Double {
        workSessions
            .filter { sessionHasEnded($0) }
            .reduce(0) { $0 + displayWorkSpendableAmount(for: $1) }
    }

    var monthlyWorkSavings: Double {
        workSessions
            .filter { sessionHasEnded($0) }
            .reduce(0) { $0 + displayWorkSavingsAmount(for: $1) }
    }

    var totalWorkSavingsBalance: Double {
        allWorkSessions
            .filter { sessionHasEnded($0) }
            .reduce(0) { $0 + displayWorkSavingsAmount(for: $1) }
    }

    var totalGross: Double {
        totalIncome + totalWorkSpendable
    }

    var spendableBalance: Double {
        totalGross - totalExpenses
    }

    var totalSavingsBalance: Double {
        let accountSavings = savingsEntries.reduce(0) { $0 + displayAmount(for: $1) }
        let incomeSavings = savingsIncomeEntries.reduce(0) {
            $0 + (savingsIncomeDisplayAmounts[$1.id] ?? $1.amount)
        }
        return accountSavings + incomeSavings + totalWorkSavingsBalance
    }

    var netBalance: Double {
        spendableBalance + totalSavingsBalance
    }

    var goalProgress: Double {
        guard monthlyGoal > 0 else { return 0 }
        return min(spendableBalance / monthlyGoal, 1.0)
    }

    var dailyAverage: Double {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: selectedMonth)!
        let daysInMonth = range.count
        let dayOfMonth = calendar.component(.day, from: Date())

        let isCurrentMonth = calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
        let elapsedDays = isCurrentMonth ? max(dayOfMonth, 1) : daysInMonth
        return spendableBalance / Double(elapsedDays)
    }

    var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    var formattedGoal: String {
        monthlyGoal > 0 ? formatCurrency(monthlyGoal) : "Not set"
    }

    var spendableIncomeEntries: [IncomeEntry] {
        incomeEntries.filter { $0.category != .savings }
    }

    var recentIncomeEntries: [IncomeEntry] {
        Array(spendableIncomeEntries.prefix(entryPreviewLimit))
    }

    var recentExpenseEntries: [ExpenseEntry] {
        Array(expenseEntries.prefix(entryPreviewLimit))
    }

    var storeExpenseGroups: [StoreExpenseGroup] {
        let grouped = Dictionary(grouping: expenseEntries.compactMap { entry -> (key: String, name: String, entry: ExpenseEntry)? in
            guard let name = cleanedStoreName(entry.storeName) else { return nil }
            return (key: name.lowercased(), name: name, entry: entry)
        }, by: { $0.key })

        return grouped.map { key, values in
            StoreExpenseGroup(
                id: key,
                name: values.first?.name ?? key,
                count: values.count,
                total: values.reduce(0) { $0 + displayAmount(for: $1.entry) }
            )
        }
        .sorted { lhs, rhs in
            if lhs.total == rhs.total { return lhs.name < rhs.name }
            return lhs.total > rhs.total
        }
    }

    var recentSavingsEntries: [SavingsEntry] {
        Array(savingsEntries.prefix(entryPreviewLimit))
    }

    var activeSavingsGoals: [SavingsGoal] {
        savingsGoals.filter { !$0.archived }
    }

    var totalSavingsGoalTarget: Double {
        activeSavingsGoals.reduce(0) { $0 + displayTarget(for: $1) }
    }

    var allocatedSavings: Double {
        activeSavingsGoals.reduce(0) { $0 + allocatedAmount(for: $1) }
    }

    var remainingSavingsNeeded: Double {
        max(totalSavingsGoalTarget - allocatedSavings, 0)
    }

    var savingsGoalProgress: Double {
        guard totalSavingsGoalTarget > 0 else { return 0 }
        return min(allocatedSavings / totalSavingsGoalTarget, 1)
    }

    var unassignedSavingsBalance: Double {
        totalSavingsBalance - allocatedSavings
    }

    var upcomingWorkSessions: [WorkSession] {
        let now = Date()
        let upcoming = workSessions
            .filter { combinedDateTime(date: $0.date, time: $0.startTime) >= now }
            .sorted { lhs, rhs in
                let lhsStart = combinedDateTime(date: lhs.date, time: lhs.startTime)
                let rhsStart = combinedDateTime(date: rhs.date, time: rhs.startTime)
                return lhsStart < rhsStart
            }
        return Array(upcoming.prefix(entryPreviewLimit))
    }

    func loadSettings(modelContext: ModelContext) {
        let settings = UserSettings.current(in: modelContext)
        monthlyGoal = settings.monthlyIncomeGoal ?? 0
        currencyCode = settings.currencyCode
        entryPreviewLimit = max(1, settings.moneyEntryPreviewLimit ?? 5)
    }

    func saveGoal(modelContext: ModelContext) {
        let settings = UserSettings.current(in: modelContext)
        settings.monthlyIncomeGoal = monthlyGoal
        settings.currencyCode = currencyCode
        settings.updatedAt = Date()
        try? modelContext.save()
    }

    func loadEntries(modelContext: ModelContext) {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!

        let incomeDescriptor = FetchDescriptor<IncomeEntry>(
            predicate: #Predicate { entry in
                entry.date >= startOfMonth && entry.date < endOfMonth
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        incomeEntries = (try? modelContext.fetch(incomeDescriptor)) ?? []

        let allIncomeDescriptor = FetchDescriptor<IncomeEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let allIncomeEntries = (try? modelContext.fetch(allIncomeDescriptor)) ?? []
        savingsIncomeEntries = allIncomeEntries.filter { $0.category == .savings }

        let expenseDescriptor = FetchDescriptor<ExpenseEntry>(
            predicate: #Predicate { entry in
                entry.date >= startOfMonth && entry.date < endOfMonth
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        expenseEntries = (try? modelContext.fetch(expenseDescriptor)) ?? []

        let workDescriptor = FetchDescriptor<WorkSession>(
            predicate: #Predicate { session in
                session.date >= startOfMonth && session.date < endOfMonth
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        workSessions = (try? modelContext.fetch(workDescriptor)) ?? []

        let allWorkDescriptor = FetchDescriptor<WorkSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        allWorkSessions = (try? modelContext.fetch(allWorkDescriptor)) ?? []

        let savingsDescriptor = FetchDescriptor<SavingsEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        savingsEntries = (try? modelContext.fetch(savingsDescriptor)) ?? []

        let goalsDescriptor = FetchDescriptor<SavingsGoal>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        savingsGoals = (try? modelContext.fetch(goalsDescriptor)) ?? []

        incomeDisplayAmounts = Dictionary(uniqueKeysWithValues: incomeEntries.map { ($0.id, $0.amount) })
        expenseDisplayAmounts = Dictionary(uniqueKeysWithValues: expenseEntries.map { ($0.id, $0.amount) })
        workDisplayAmounts = Dictionary(uniqueKeysWithValues: allWorkSessions.map { ($0.id, $0.totalEarned) })
        workSpendableDisplayAmounts = Dictionary(uniqueKeysWithValues: allWorkSessions.map { ($0.id, $0.spendableWorkAmount) })
        workSavingsDisplayAmounts = Dictionary(uniqueKeysWithValues: allWorkSessions.map { ($0.id, $0.savingsWorkAmount) })
        workSavingsPrimaryDisplayAmounts = Dictionary(uniqueKeysWithValues: allWorkSessions.map { ($0.id, $0.savingsWorkAmount) })
        savingsDisplayAmounts = Dictionary(uniqueKeysWithValues: savingsEntries.map { ($0.id, $0.amount) })
        savingsPrimaryDisplayAmounts = Dictionary(uniqueKeysWithValues: savingsEntries.map { ($0.id, primarySavingsFallbackAmount(for: $0)) })
        savingsIncomeDisplayAmounts = Dictionary(uniqueKeysWithValues: savingsIncomeEntries.map { ($0.id, $0.amount) })
        savingsGoalDisplayTargets = Dictionary(uniqueKeysWithValues: savingsGoals.map { ($0.id, $0.targetAmount) })
        currencyConversionError = nil
    }

    func refreshCurrencyConversions() async {
        currencyConversionError = nil

        for entry in incomeEntries {
            incomeDisplayAmounts[entry.id] = await convertedAmount(
                entry.amount,
                from: entry.currencyCode,
                fallbackCurrency: currencyCode
            )
        }

        for entry in expenseEntries {
            expenseDisplayAmounts[entry.id] = await convertedAmount(
                entry.amount,
                from: entry.currencyCode,
                fallbackCurrency: currencyCode
            )
        }

        for session in allWorkSessions {
            workDisplayAmounts[session.id] = await convertedAmount(
                session.totalEarned,
                from: session.currencyCode,
                fallbackCurrency: currencyCode
            )
            workSpendableDisplayAmounts[session.id] = await convertedAmount(
                session.spendableWorkAmount,
                from: session.currencyCode,
                fallbackCurrency: currencyCode
            )
            workSavingsDisplayAmounts[session.id] = await convertedAmount(
                session.savingsWorkAmount,
                from: session.currencyCode,
                fallbackCurrency: currencyCode
            )
            workSavingsPrimaryDisplayAmounts[session.id] = await convertedAmount(
                session.savingsWorkAmount,
                from: session.currencyCode,
                to: primaryWorkSavingsCurrency(for: session),
                fallbackCurrency: currencyCode
            )
        }

        for entry in savingsEntries {
            savingsDisplayAmounts[entry.id] = await convertedAmount(
                entry.amount,
                from: entry.currencyCode,
                fallbackCurrency: currencyCode
            )
            savingsPrimaryDisplayAmounts[entry.id] = await convertedAmount(
                entry.amount,
                from: entry.currencyCode,
                to: primarySavingsCurrency(for: entry),
                fallbackCurrency: currencyCode
            )
        }

        for entry in savingsIncomeEntries {
            savingsIncomeDisplayAmounts[entry.id] = await convertedAmount(
                entry.amount,
                from: entry.currencyCode,
                fallbackCurrency: currencyCode
            )
        }

        for goal in savingsGoals {
            savingsGoalDisplayTargets[goal.id] = await convertedAmount(
                goal.targetAmount,
                from: goal.currencyCode,
                fallbackCurrency: currencyCode
            )
        }
    }

    func deleteIncomeEntry(_ entry: IncomeEntry, modelContext: ModelContext) {
        modelContext.delete(entry)
        try? modelContext.save()
        incomeEntries.removeAll { $0.id == entry.id }
    }

    func deleteExpenseEntry(_ entry: ExpenseEntry, modelContext: ModelContext) {
        modelContext.delete(entry)
        try? modelContext.save()
        expenseEntries.removeAll { $0.id == entry.id }
    }

    func deleteWorkSession(_ session: WorkSession, modelContext: ModelContext) {
        modelContext.delete(session)
        try? modelContext.save()
        workSessions.removeAll { $0.id == session.id }
        allWorkSessions.removeAll { $0.id == session.id }
    }

    func deleteSavingsEntry(_ entry: SavingsEntry, modelContext: ModelContext) {
        modelContext.delete(entry)
        try? modelContext.save()
        savingsEntries.removeAll { $0.id == entry.id }
    }

    func deleteSavingsGoal(_ goal: SavingsGoal, modelContext: ModelContext) {
        for entry in savingsEntries where entry.goalId == goal.id {
            entry.goalId = nil
        }
        for session in allWorkSessions where session.savingsGoalId == goal.id {
            session.savingsGoalId = nil
        }
        modelContext.delete(goal)
        try? modelContext.save()
        savingsGoals.removeAll { $0.id == goal.id }
    }

    func navigateMonth(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) {
            selectedMonth = newDate
        }
    }

    func formatCurrency(_ amount: Double) -> String {
        formatCurrency(amount, currency: currencyCode)
    }

    func formatCurrency(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }

    func displayAmount(for entry: IncomeEntry) -> Double {
        incomeDisplayAmounts[entry.id] ?? entry.amount
    }

    func displayAmount(for entry: ExpenseEntry) -> Double {
        expenseDisplayAmounts[entry.id] ?? entry.amount
    }

    func displayAmount(for session: WorkSession) -> Double {
        workDisplayAmounts[session.id] ?? session.totalEarned
    }

    func displayWorkSpendableAmount(for session: WorkSession) -> Double {
        workSpendableDisplayAmounts[session.id] ?? session.spendableWorkAmount
    }

    func displayWorkSavingsAmount(for session: WorkSession) -> Double {
        workSavingsDisplayAmounts[session.id] ?? session.savingsWorkAmount
    }

    func sessionHasEnded(_ session: WorkSession) -> Bool {
        sessionEndDateTime(session) <= Date()
    }

    func workSessionStatusLabel(for session: WorkSession) -> String {
        sessionHasEnded(session) ? "Earned" : "Scheduled"
    }

    func sourceCurrencyLabel(for entry: IncomeEntry) -> String? {
        sourceCurrencyLabel(
            originalAmount: entry.originalAmount,
            originalCurrency: entry.originalCurrencyCode
        )
    }

    func sourceCurrencyLabel(for entry: ExpenseEntry) -> String? {
        sourceCurrencyLabel(
            originalAmount: entry.originalAmount,
            originalCurrency: entry.originalCurrencyCode
        )
    }

    func formatDuration(_ session: WorkSession) -> String {
        let interval = session.endTime.timeIntervalSince(session.startTime)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func categoryLabel(_ category: IncomeCategory) -> String {
        switch category {
        case .salary: return "Salary"
        case .freelance: return "Freelance"
        case .gig: return "Gig"
        case .savings: return "Savings"
        case .other: return "Other"
        }
    }

    func displayAmount(for entry: SavingsEntry) -> Double {
        savingsDisplayAmounts[entry.id] ?? entry.amount
    }

    func primarySavingsAmountText(for entry: SavingsEntry) -> String {
        let primaryCurrency = primarySavingsCurrency(for: entry)
        let primaryAmount = savingsPrimaryDisplayAmounts[entry.id] ?? primarySavingsFallbackAmount(for: entry)
        return formatCurrency(primaryAmount, currency: primaryCurrency)
    }

    func secondarySavingsAmountText(for entry: SavingsEntry) -> String? {
        let primaryCurrency = primarySavingsCurrency(for: entry)
        guard primaryCurrency != currencyCode else { return nil }
        return "App value: \(formatCurrency(displayAmount(for: entry)))"
    }

    func displayTarget(for goal: SavingsGoal) -> Double {
        savingsGoalDisplayTargets[goal.id] ?? goal.targetAmount
    }

    func primarySavingsTargetText(for goal: SavingsGoal) -> String {
        let goalCurrency = currencyConverter.normalizedCurrencyCode(goal.currencyCode) ?? currencyCode
        return formatCurrency(goal.targetAmount, currency: goalCurrency)
    }

    func secondarySavingsTargetText(for goal: SavingsGoal) -> String? {
        let goalCurrency = currencyConverter.normalizedCurrencyCode(goal.currencyCode) ?? currencyCode
        guard goalCurrency != currencyCode else { return nil }
        return "App target: \(formatCurrency(displayTarget(for: goal)))"
    }

    func allocatedAmount(for goal: SavingsGoal) -> Double {
        let directSavings = savingsEntries
            .filter { $0.goalId == goal.id }
            .reduce(0) { $0 + displayAmount(for: $1) }
        let workSavings = allWorkSessions
            .filter { $0.savingsGoalId == goal.id && sessionHasEnded($0) }
            .reduce(0) { $0 + displayWorkSavingsAmount(for: $1) }
        return directSavings + workSavings
    }

    func primaryAllocatedAmount(for goal: SavingsGoal) -> Double {
        let directSavings = savingsEntries
            .filter { $0.goalId == goal.id }
            .reduce(0) { $0 + (savingsPrimaryDisplayAmounts[$1.id] ?? primarySavingsFallbackAmount(for: $1)) }
        let workSavings = allWorkSessions
            .filter { $0.savingsGoalId == goal.id && sessionHasEnded($0) }
            .reduce(0) { $0 + (workSavingsPrimaryDisplayAmounts[$1.id] ?? $1.savingsWorkAmount) }
        return directSavings + workSavings
    }

    func remainingAmount(for goal: SavingsGoal) -> Double {
        max(displayTarget(for: goal) - allocatedAmount(for: goal), 0)
    }

    func primaryRemainingAmount(for goal: SavingsGoal) -> Double {
        max(goal.targetAmount - primaryAllocatedAmount(for: goal), 0)
    }

    func progress(for goal: SavingsGoal) -> Double {
        let target = goal.targetAmount
        guard target > 0 else { return 0 }
        return min(primaryAllocatedAmount(for: goal) / target, 1)
    }

    func goalName(for id: UUID?) -> String {
        guard let id else { return "Unassigned" }
        return savingsGoals.first(where: { $0.id == id })?.name ?? "Deleted Goal"
    }

    func workRateLabel(for session: WorkSession) -> String {
        let rate = formatCurrency(session.hourlyRate, currency: session.currencyCode ?? currencyCode)
        return session.usesDailyPricing ? "\(rate)/day" : "\(rate)/h"
    }

    func workSavingsDestinationLabel(for session: WorkSession) -> String {
        guard session.savingsWorkAmount > 0 else { return "No savings split" }
        if let goalId = session.savingsGoalId,
           let goal = savingsGoals.first(where: { $0.id == goalId }) {
            return goal.name
        }
        return "Unassigned Savings"
    }

    private func convertedAmount(_ amount: Double, from sourceCurrency: String?, fallbackCurrency: String) async -> Double {
        await convertedAmount(amount, from: sourceCurrency, to: currencyCode, fallbackCurrency: fallbackCurrency)
    }

    private func convertedAmount(_ amount: Double, from sourceCurrency: String?, to targetCurrency: String, fallbackCurrency: String) async -> Double {
        let source = currencyConverter.normalizedCurrencyCode(sourceCurrency) ?? fallbackCurrency
        let target = currencyConverter.normalizedCurrencyCode(targetCurrency) ?? currencyCode
        guard source != target else { return amount }

        do {
            let result = try await currencyConverter.convert(amount: amount, from: source, to: target)
            return result.convertedAmount
        } catch {
            currencyConversionError = "Some entries could not be converted. Showing their stored values."
            return amount
        }
    }

    private func sourceCurrencyLabel(originalAmount: Double?, originalCurrency: String?) -> String? {
        guard let originalAmount,
              let originalCurrency = currencyConverter.normalizedCurrencyCode(originalCurrency),
              originalCurrency != currencyCode else {
            return nil
        }
        return "Original: \(formatCurrency(originalAmount, currency: originalCurrency))"
    }

    private func cleanedStoreName(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func primarySavingsCurrency(for entry: SavingsEntry) -> String {
        if let goalId = entry.goalId,
           let goal = savingsGoals.first(where: { $0.id == goalId }),
           let goalCurrency = currencyConverter.normalizedCurrencyCode(goal.currencyCode) {
            return goalCurrency
        }
        return currencyConverter.normalizedCurrencyCode(entry.originalCurrencyCode)
            ?? currencyConverter.normalizedCurrencyCode(entry.currencyCode)
            ?? currencyCode
    }

    private func primaryWorkSavingsCurrency(for session: WorkSession) -> String {
        if let goalId = session.savingsGoalId,
           let goal = savingsGoals.first(where: { $0.id == goalId }),
           let goalCurrency = currencyConverter.normalizedCurrencyCode(goal.currencyCode) {
            return goalCurrency
        }
        return currencyConverter.normalizedCurrencyCode(session.currencyCode) ?? currencyCode
    }

    private func primarySavingsFallbackAmount(for entry: SavingsEntry) -> Double {
        let primaryCurrency = primarySavingsCurrency(for: entry)
        if currencyConverter.normalizedCurrencyCode(entry.originalCurrencyCode) == primaryCurrency,
           let originalAmount = entry.originalAmount {
            return originalAmount
        }
        if currencyConverter.normalizedCurrencyCode(entry.currencyCode) == primaryCurrency {
            return entry.amount
        }
        return displayAmount(for: entry)
    }

    private func combinedDateTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        var merged = DateComponents()
        merged.year = dateComponents.year
        merged.month = dateComponents.month
        merged.day = dateComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        merged.second = timeComponents.second
        return calendar.date(from: merged) ?? date
    }

    private func sessionEndDateTime(_ session: WorkSession) -> Date {
        let calendar = Calendar.current
        if !calendar.isDate(session.startTime, inSameDayAs: session.endTime) {
            return session.endTime
        }
        return combinedDateTime(date: session.date, time: session.endTime)
    }
}
