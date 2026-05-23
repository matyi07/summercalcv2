import { create } from 'zustand';
import { UserSettings } from '../models';

interface SettingsState {
  settings: UserSettings | null;
  loading: boolean;
  setSettings: (settings: UserSettings) => void;
  updateSetting: (patch: Partial<UserSettings>) => void;
  setLoading: (loading: boolean) => void;
}

export const useSettingsStore = create<SettingsState>((set) => ({
  settings: null,
  loading: false,
  setSettings: (settings) => set({ settings }),
  updateSetting: (patch) =>
    set((state) => ({
      settings: state.settings ? { ...state.settings, ...patch } : null,
    })),
  setLoading: (loading) => set({ loading }),
}));
