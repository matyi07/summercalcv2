import { ActivitySuggestion, WeatherSnapshot, PlaceCandidate, UserSettings } from '../models';
import { v4 as uuidv4 } from 'uuid';

interface ActivityTemplate {
  title: string;
  category: string;
  durationMinutes: number;
  costLevel: number;
  indoor: boolean;
}

const INDOOR_ACTIVITIES: ActivityTemplate[] = [
  { title: 'Read at a cafe', category: 'Relaxation', durationMinutes: 60, costLevel: 1, indoor: true },
  { title: 'Visit a museum', category: 'Culture', durationMinutes: 120, costLevel: 2, indoor: true },
  { title: 'Workout at the gym', category: 'Fitness', durationMinutes: 60, costLevel: 1, indoor: true },
  { title: 'Try a new recipe', category: 'Food', durationMinutes: 90, costLevel: 1, indoor: true },
  { title: 'Watch a movie', category: 'Entertainment', durationMinutes: 150, costLevel: 2, indoor: true },
  { title: 'Visit a library', category: 'Learning', durationMinutes: 90, costLevel: 0, indoor: true },
  { title: 'Browse a bookstore', category: 'Shopping', durationMinutes: 45, costLevel: 1, indoor: true },
  { title: 'Play board games', category: 'Social', durationMinutes: 120, costLevel: 0, indoor: true },
  { title: 'Plan next week', category: 'Productivity', durationMinutes: 30, costLevel: 0, indoor: true },
  { title: 'Indoor rock climbing', category: 'Fitness', durationMinutes: 90, costLevel: 2, indoor: true },
  { title: 'Visit an art gallery', category: 'Culture', durationMinutes: 60, costLevel: 1, indoor: true },
  { title: 'Bowling', category: 'Social', durationMinutes: 90, costLevel: 2, indoor: true },
  { title: 'Escape room', category: 'Social', durationMinutes: 60, costLevel: 3, indoor: true },
  { title: 'Bake something', category: 'Food', durationMinutes: 120, costLevel: 1, indoor: true },
  { title: 'Yoga at home', category: 'Fitness', durationMinutes: 45, costLevel: 0, indoor: true },
];

const OUTDOOR_ACTIVITIES: ActivityTemplate[] = [
  { title: 'Walk in the park', category: 'Nature', durationMinutes: 45, costLevel: 0, indoor: false },
  { title: 'Go for a run', category: 'Fitness', durationMinutes: 40, costLevel: 0, indoor: false },
  { title: 'Hike a trail', category: 'Nature', durationMinutes: 120, costLevel: 0, indoor: false },
  { title: 'Outdoor picnic', category: 'Social', durationMinutes: 90, costLevel: 1, indoor: false },
  { title: 'Visit a beach', category: 'Nature', durationMinutes: 180, costLevel: 0, indoor: false },
  { title: 'Cycling', category: 'Fitness', durationMinutes: 60, costLevel: 0, indoor: false },
  { title: 'Outdoor photography', category: 'Creative', durationMinutes: 60, costLevel: 0, indoor: false },
  { title: 'Gardening', category: 'Nature', durationMinutes: 60, costLevel: 0, indoor: false },
  { title: 'Farmers market visit', category: 'Food', durationMinutes: 45, costLevel: 2, indoor: false },
  { title: 'Outdoor yoga', category: 'Fitness', durationMinutes: 45, costLevel: 1, indoor: false },
  { title: 'Sunset watching', category: 'Relaxation', durationMinutes: 30, costLevel: 0, indoor: false },
  { title: 'Street art tour', category: 'Culture', durationMinutes: 60, costLevel: 0, indoor: false },
  { title: 'Kayaking', category: 'Adventure', durationMinutes: 120, costLevel: 2, indoor: false },
  { title: 'Outdoor concert', category: 'Entertainment', durationMinutes: 120, costLevel: 2, indoor: false },
  { title: 'Frisbee in the park', category: 'Social', durationMinutes: 60, costLevel: 0, indoor: false },
];

export class ActivitySuggestionService {
  generateFreeDaySuggestions(
    date: Date,
    freeWindows: { start: Date; end: Date }[],
    weather: WeatherSnapshot | null,
    places: PlaceCandidate[],
    settings?: UserSettings
  ): ActivitySuggestion[] {
    const suggestions: ActivitySuggestion[] = [];
    const dateStr = date.toISOString().slice(0, 10);
    const now = new Date().toISOString();
    const isRain = weather && weather.precipitationChance >= 0.5;
    const isGoodOutdoor = weather && weather.precipitationChance < 0.3 && weather.temperatureCelsius >= 15 && weather.temperatureCelsius <= 32;

    let activityPool: ActivityTemplate[];

    if (isRain) {
      activityPool = [...INDOOR_ACTIVITIES];
    } else if (isGoodOutdoor) {
      activityPool = [...OUTDOOR_ACTIVITIES, ...INDOOR_ACTIVITIES.slice(0, 3)];
    } else {
      activityPool = [...INDOOR_ACTIVITIES, ...OUTDOOR_ACTIVITIES.slice(0, 3)];
    }

    const totalFreeMinutes = freeWindows.reduce((s, w) => s + (w.end.getTime() - w.start.getTime()) / 60000, 0);
    const maxActivities = Math.min(Math.floor(totalFreeMinutes / 60), 6);
    const count = Math.max(maxActivities, 3);

    const shuffled = activityPool.sort(() => Math.random() - 0.5);
    const selected = shuffled.slice(0, count);

    for (let i = 0; i < selected.length; i++) {
      const t = selected[i];
      const suggestion: ActivitySuggestion = {
        id: uuidv4(),
        date: dateStr,
        title: t.title,
        summary: `${t.title} for about ${t.durationMinutes} minutes`,
        category: t.category,
        estimatedDurationMinutes: t.durationMinutes,
        estimatedCostLevel: t.costLevel,
        weatherReason: weather ? (isRain ? 'Indoor: rain likely' : 'Outdoor: good weather') : undefined,
        createdAt: now,
      };

      if (places.length > i) {
        suggestion.placeName = places[i].name;
        suggestion.placeId = places[i].placeId;
      }

      suggestions.push(suggestion);
    }

    return suggestions;
  }

  generateQuickIdeas(
    weather: WeatherSnapshot | null,
    preferences?: string[]
  ): ActivitySuggestion[] {
    const now = new Date().toISOString();
    const today = new Date().toISOString().slice(0, 10);
    const isRain = weather && weather.precipitationChance >= 0.5;
    const pool = isRain ? [...INDOOR_ACTIVITIES] : [...OUTDOOR_ACTIVITIES, ...INDOOR_ACTIVITIES];

    let filtered = pool;

    if (preferences && preferences.length > 0) {
      const prefLower = preferences.map(p => p.toLowerCase());
      filtered = pool.filter(a => {
        const cat = a.category.toLowerCase();
        const title = a.title.toLowerCase();
        return prefLower.some(p => cat.includes(p) || title.includes(p));
      });
      if (filtered.length < 3) {
        filtered = [...filtered, ...pool].slice(0, 5);
      }
    }

    const shuffled = filtered.sort(() => Math.random() - 0.5);
    return shuffled.slice(0, 3).map(t => ({
      id: uuidv4(),
      date: today,
      title: t.title,
      summary: `${t.title} for about ${t.durationMinutes} minutes`,
      category: t.category,
      estimatedDurationMinutes: t.durationMinutes,
      estimatedCostLevel: t.costLevel,
      weatherReason: weather ? (isRain ? 'Indoor suggested' : 'Outdoor friendly') : undefined,
      createdAt: now,
    }));
  }
}
