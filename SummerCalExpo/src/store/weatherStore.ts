import { create } from 'zustand';
import { WeatherSnapshot } from '../models';

interface WeatherState {
  currentSnapshot: WeatherSnapshot | null;
  loading: boolean;
  error: string | null;
  setWeather: (snapshot: WeatherSnapshot) => void;
  setLoading: (loading: boolean) => void;
  setError: (error: string | null) => void;
}

export const useWeatherStore = create<WeatherState>((set) => ({
  currentSnapshot: null,
  loading: false,
  error: null,
  setWeather: (snapshot) => set({ currentSnapshot: snapshot, error: null }),
  setLoading: (loading) => set({ loading }),
  setError: (error) => set({ error }),
}));
