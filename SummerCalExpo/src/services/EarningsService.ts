import { IncomeEntry, WorkSession } from '../models';

export class EarningsService {
  monthlyIncomeEntries(date: Date, entries: IncomeEntry[]): number {
    const target = new Date(date);
    return entries
      .filter(e => new Date(e.date).getMonth() === target.getMonth() && new Date(e.date).getFullYear() === target.getFullYear())
      .reduce((s, e) => s + e.amount, 0);
  }

  monthlyWorkEarnings(date: Date, sessions: WorkSession[]): number {
    const target = new Date(date);
    return sessions
      .filter(s => new Date(s.date).getMonth() === target.getMonth() && new Date(s.date).getFullYear() === target.getFullYear())
      .reduce((s, e) => s + e.totalEarned, 0);
  }

  monthlyTotal(date: Date, entries: IncomeEntry[], sessions: WorkSession[]): number {
    return this.monthlyIncomeEntries(date, entries) + this.monthlyWorkEarnings(date, sessions);
  }

  goalProgress(total: number, goal: number): number {
    if (goal <= 0) return 0;
    return Math.min(total / goal, 1);
  }

  dailyAverage(date: Date, total: number): number {
    const daysInMonth = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
    return total / daysInMonth;
  }
}
