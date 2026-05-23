import { create } from 'zustand';
import { SmartNotificationRule, NotificationLog } from '../models';

interface NotificationState {
  rules: SmartNotificationRule[];
  logs: NotificationLog[];
  scheduling: boolean;
  setRules: (rules: SmartNotificationRule[]) => void;
  updateRule: (rule: SmartNotificationRule) => void;
  setLogs: (logs: NotificationLog[]) => void;
  addLog: (log: NotificationLog) => void;
  setScheduling: (scheduling: boolean) => void;
}

export const useNotificationStore = create<NotificationState>((set) => ({
  rules: [],
  logs: [],
  scheduling: false,
  setRules: (rules) => set({ rules }),
  updateRule: (rule) =>
    set((state) => ({
      rules: state.rules.map((r) => (r.id === rule.id ? rule : r)),
    })),
  setLogs: (logs) => set({ logs }),
  addLog: (log) =>
    set((state) => ({
      logs: [...state.logs, log],
    })),
  setScheduling: (scheduling) => set({ scheduling }),
}));
