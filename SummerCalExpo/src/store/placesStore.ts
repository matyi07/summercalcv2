import { create } from 'zustand';
import { PlaceCandidate } from '../models';

interface PlacesState {
  results: PlaceCandidate[];
  selectedCategory: string;
  searchQuery: string;
  loading: boolean;
  error: string | null;
  setResults: (results: PlaceCandidate[]) => void;
  setCategory: (category: string) => void;
  setQuery: (query: string) => void;
  setLoading: (loading: boolean) => void;
  setError: (error: string | null) => void;
}

export const usePlacesStore = create<PlacesState>((set) => ({
  results: [],
  selectedCategory: '',
  searchQuery: '',
  loading: false,
  error: null,
  setResults: (results) => set({ results, error: null }),
  setCategory: (category) => set({ selectedCategory: category }),
  setQuery: (query) => set({ searchQuery: query }),
  setLoading: (loading) => set({ loading }),
  setError: (error) => set({ error }),
}));
