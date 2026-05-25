import Foundation
import SwiftData

@Observable
final class MoneyViewModel {
    var selectedMonth: Date = Date()
    var incomeEntries: [IncomeEntry] = []
    var expenseEntries: [ExpenseEntry] = []
    var workSessions: [WorkSession] = []
    var monthlyGoal: Double = 0
    var currencyCode: String = "USD"
    var incomeDisplayAmounts: [UUID: Double] = [:]
    var expenseDisplayAmounts: [UUID: Double] = [:]
    var workDisplayAmounts: [UUID: Double] = [:]
    var currencyConversionError: String?

    private let currencyConverter = CurrencyConversionService()

    var totalIncome: Double {
        incomeEntries.reduce(0) { $0 + displayAmount(for: $1) }
    }

    var totalExpenses: Double {
        expenseEntries.reduce(0) { $0 + displayAmount(for: $1) }
    }

    var totalWorkEarnings: Double {
        workSessions.reduce(0) { $0 + displayAmount(for: $1) }
    }

    var totalGross: Double {
        totalIncome + totalWorkEarnings
    }

    var netBalance: Double {
        totalGross - totalExpenses
    }

    var goalProgress: Double {
        guard monthlyGoal > 0 else { return 0 }
        return min(netBalance / monthlyGoal, 1.0)
    }

    var dailyAverage: Double {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: selectedMonth)!
        let daysInMonth = range.count
        let dayOfMonth = calendar.component(.day, from: Date())

        let isCurrentMonth = calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
        let elapsedDays = isCurrentMonth ? max(dayOfMonth, 1) : daysInMonth
        return netBalance / Double(elapsedDays)
    }

    var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    var formattedGoal: String {
        monthlyGoal > 0 ? formatCurrency(monthlyGoal) : "Not set"
    }

    func loadSettings(modelContext: ModelContext) {
        let settings = UserSettings.current(in: modelContext)
        monthlyGoal = settings.monthlyIncomeGoal ?? 0
        currencyCode = settings.currencyCode
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

        incomeDisplayAmounts = Dictionary(uniqueKeysWithValues: incomeEntries.map { ($0.id, $0.amount) })
        expenseDisplayAmounts = Dictionary(uniqueKeysWithValues: expenseEntries.map { ($0.id, $0.amount) })
        workDisplayAmounts = Dictionary(uniqueKeysWithValues: workSessions.map { ($0.id, $0.totalEarned) })
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

        for session in workSessions {
            workDisplayAmounts[session.id] = await convertedAmount(
                session.totalEarned,
                from: session.currencyCode,
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
        case .other: return "Other"
        }
    }

    private func convertedAmount(_ amount: Double, from sourceCurrency: String?, fallbackCurrency: String) async -> Double {
        let source = currencyConverter.normalizedCurrencyCode(sourceCurrency) ?? fallbackCurrency
        guard source != currencyCode else { return amount }

        do {
            let result = try await currencyConverter.convert(amount: amount, from: source, to: currencyCode)
            return result.convertedAmount
        } catch {
            currencyConversionError = "Some entries could not be converted to \(currencyCode). Showing their stored values."
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
}
