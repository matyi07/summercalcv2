import { CalendarEvent } from '../models';
import { startOfDay, endOfDay } from 'date-fns';

export class FreeDayDetectionService {
  freeWindows(date: Date, events: CalendarEvent[]): { start: Date; end: Date }[] {
    const dayStart = startOfDay(date);
    const dayEnd = endOfDay(date);
    const dayEvents = events.filter(e => {
      const s = new Date(e.startDate);
      const e2 = new Date(e.endDate);
      return s < dayEnd && e2 > dayStart;
    });

    if (dayEvents.length === 0) return [{ start: dayStart, end: dayEnd }];

    const busy = dayEvents
      .map(e => ({
        start: new Date(Math.max(new Date(e.startDate).getTime(), dayStart.getTime())),
        end: new Date(Math.min(new Date(e.endDate).getTime(), dayEnd.getTime())),
      }))
      .sort((a, b) => a.start.getTime() - b.start.getTime());

    const free: { start: Date; end: Date }[] = [];
    let cursor = dayStart;
    for (const interval of busy) {
      if (cursor < interval.start) {
        free.push({ start: cursor, end: interval.start });
      }
      cursor = new Date(Math.max(cursor.getTime(), interval.end.getTime()));
    }
    if (cursor < dayEnd) {
      free.push({ start: cursor, end: dayEnd });
    }
    return free.filter(f => f.end.getTime() - f.start.getTime() > 60_000);
  }

  shouldNotifyFreeDay(freeWindows: { start: Date; end: Date }[], thresholdHours: number): boolean {
    return freeWindows.some(w => (w.end.getTime() - w.start.getTime()) >= thresholdHours * 3600_000);
  }

  largestFreeWindow(date: Date, events: CalendarEvent[]): { start: Date; end: Date } | null {
    const windows = this.freeWindows(date, events);
    if (windows.length === 0) return null;
    return windows.reduce((a, b) => (b.end.getTime() - b.start.getTime()) > (a.end.getTime() - a.start.getTime()) ? b : a);
  }

  notificationBody(freeWindows: { start: Date; end: Date }[], weather?: { precipitationChance: number; temperatureCelsius: number }): string {
    const totalHours = Math.round(freeWindows.reduce((s, w) => s + (w.end.getTime() - w.start.getTime()), 0) / 3600_000);
    if (weather) {
      if (weather.precipitationChance > 0.5) {
        return `About ${totalHours} free hours today. Rain is likely — indoor ideas: cafe, museum, gym.`;
      } else if (weather.temperatureCelsius > 25) {
        return `About ${totalHours} free hours today. Great weather for outdoor activities!`;
      }
    }
    return `About ${totalHours} free hours today. Want ideas based on weather and nearby places?`;
  }
}
