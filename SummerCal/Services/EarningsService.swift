import Foundation

final class EarningsService {
    private let calendar = Calendar.current

    func monthlyEarnings(month: Date, entries: [IncomeEntry]) -> Double {
        let monthly = entries.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
        return monthly.reduce(0) { $0 + $1.amount }
    }

    func monthlyWorkEarnings(month: Date, sessions: [WorkSession]) -> Double {
        let monthly = sessions.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
        return monthly.reduce(0) { $0 + $1.totalEarned }
    }

    func monthlyTotal(month: Date, entries: [IncomeEntry], sessions: [WorkSession]) -> Double {
        monthlyEarnings(month: month, entries: entries) + monthlyWorkEarnings(month: month, sessions: sessions)
    }

    func goalProgress(total: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(total / goal, 1.0)
    }

    func dailyAverage(month: Date, total: Double) -> Double {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return 0 }
        return total / Double(range.count)
    }
}
