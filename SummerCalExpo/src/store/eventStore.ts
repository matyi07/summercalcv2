import { create } from 'zustand';
import { CalendarEvent } from '../models';

interface EventState {
  events: CalendarEvent[];
  loading: boolean;
  setEvents: (events: CalendarEvent[]) => void;
  addEvent: (event: CalendarEvent) => void;
  updateEvent: (event: CalendarEvent) => void;
  deleteEvent: (id: string) => void;
  setLoading: (loading: boolean) => void;
}

export const useEventStore = create<EventState>((set) => ({
  events: [],
  loading: false,
  setEvents: (events) => set({ events }),
  addEvent: (event) => set((state) => ({ events: [...state.events, event] })),
  updateEvent: (event) =>
    set((state) => ({
      events: state.events.map((e) => (e.id === event.id ? event : e)),
    })),
  deleteEvent: (id) =>
    set((state) => ({
      events: state.events.filter((e) => e.id !== id),
    })),
  setLoading: (loading) => set({ loading }),
}));
