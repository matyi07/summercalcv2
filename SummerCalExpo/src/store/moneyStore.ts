import { create } from 'zustand';
import { IncomeEntry, WorkSession } from '../models';

interface MoneyState {
  incomeEntries: IncomeEntry[];
  workSessions: WorkSession[];
  currentMonth: Date;
  setEntries: (entries: IncomeEntry[]) => void;
  addEntry: (entry: IncomeEntry) => void;
  deleteEntry: (id: string) => void;
  setSessions: (sessions: WorkSession[]) => void;
  addSession: (session: WorkSession) => void;
  deleteSession: (id: string) => void;
  setMonth: (month: Date) => void;
}

export const useMoneyStore = create<MoneyState>((set) => ({
  incomeEntries: [],
  workSessions: [],
  currentMonth: new Date(),
  setEntries: (entries) => set({ incomeEntries: entries }),
  addEntry: (entry) =>
    set((state) => ({
      incomeEntries: [...state.incomeEntries, entry],
    })),
  deleteEntry: (id) =>
    set((state) => ({
      incomeEntries: state.incomeEntries.filter((e) => e.id !== id),
    })),
  setSessions: (sessions) => set({ workSessions: sessions }),
  addSession: (session) =>
    set((state) => ({
      workSessions: [...state.workSessions, session],
    })),
  deleteSession: (id) =>
    set((state) => ({
      workSessions: state.workSessions.filter((s) => s.id !== id),
    })),
  setMonth: (month) => set({ currentMonth: month }),
}));
