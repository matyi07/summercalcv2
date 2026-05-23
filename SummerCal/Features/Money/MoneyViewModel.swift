import Foundation
import SwiftData

@Observable
final class MoneyViewModel {
    var selectedMonth: Date = Date()
    var incomeEntries: [IncomeEntry] = []
    var workSessions: [WorkSession] = []
    var monthlyGoal: Double = 0
    var currencyCode: String = "USD"

    var totalIncome: Double {
        incomeEntries.reduce(0) { $0 + $1.amount }
    }

    var totalWorkEarnings: Double {
        workSessions.reduce(0) { $0 + $1.totalEarned }
    }

    var totalGross: Double {
        totalIncome + totalWorkEarnings
    }

    var goalProgress: Double {
        guard monthlyGoal > 0 else { return 0 }
        return min(totalGross / monthlyGoal, 1.0)
    }

    var dailyAverage: Double {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: selectedMonth)!
        let daysInMonth = range.count
        let dayOfMonth = calendar.component(.day, from: Date())

        let isCurrentMonth = calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
        let elapsedDays = isCurrentMonth ? max(dayOfMonth, 1) : daysInMonth
        return totalGross / Double(elapsedDays)
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
        monthlyGoal = settings.monthlyIncomeGoal
        currencyCode = settings.currencyCode
    }

    func saveGoal(modelContext: ModelContext) {
        let settings = UserSettings.current(in: modelContext)
        settings.monthlyIncomeGoal = monthlyGoal
        settings.updatedAt = Date()
        try? modelContext.save()
    }

    func loadEntries(modelContext: ModelContext) {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        let incomeDescriptor = FetchDescriptor<IncomeEntry>(
            predicate: #Predicate { entry in
                entry.date >= startOfMonth && entry.date <= endOfMonth
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        incomeEntries = (try? modelContext.fetch(incomeDescriptor)) ?? []

        let workDescriptor = FetchDescriptor<WorkSession>(
            predicate: #Predicate { session in
                session.date >= startOfMonth && session.date <= endOfMonth
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        workSessions = (try? modelContext.fetch(workDescriptor)) ?? []
    }

    func deleteIncomeEntry(_ entry: IncomeEntry, modelContext: ModelContext) {
        modelContext.delete(entry)
        try? modelContext.save()
        incomeEntries.removeAll { $0.id == entry.id }
    }

    func deleteWorkSession(_ session: WorkSession, modelContext: ModelContext) {
        modelContext.delete(session)
        try? modelContext.save()
        workSessions.removeAll { $0.id == session.id }
    }

    func addIncomeEntry(date: Date, amount: Double, source: String, description: String, category: IncomeCategory, modelContext: ModelContext) {
        let entry = IncomeEntry(
            date: date,
            amount: amount,
            source: source,
            descriptionText: description,
            category: category
        )
        modelContext.insert(entry)
        try? modelContext.save()
        incomeEntries.append(entry)
        incomeEntries.sort { $0.date > $1.date }
    }

    func addWorkSession(date: Date, startTime: Date, endTime: Date, hourlyRate: Double, description: String, modelContext: ModelContext) {
        let duration = endTime.timeIntervalSince(startTime) / 3600
        let earned = duration * hourlyRate
        let session = WorkSession(
            date: date,
            startTime: startTime,
            endTime: endTime,
            hourlyRate: hourlyRate,
            totalEarned: earned,
            descriptionText: description
        )
        modelContext.insert(session)
        try? modelContext.save()
        workSessions.append(session)
        workSessions.sort { $0.date > $1.date }
    }

    func navigateMonth(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) {
            selectedMonth = newDate
        }
    }

    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
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
}
