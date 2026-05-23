import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { v4 as uuidv4 } from 'uuid';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';
import { useEventStore, useWeatherStore, useMoneyStore, useSettingsStore } from '../store';
import { useDatabase } from '../hooks/useDatabase';
import { EventCard } from '../components/EventCard';
import { EmptyState } from '../components/EmptyState';
import { WeatherStrip } from '../components/WeatherStrip';
import { FreeDayBanner } from '../components/FreeDayBanner';
import { SuggestionCard } from '../components/SuggestionCard';
import { MonthlyProgressBar } from '../components/MonthlyProgressBar';
import { Card } from '../components/Card';
import { CalendarEvent, ActivitySuggestion } from '../models';
import { ActivitySuggestionService } from '../services/ActivitySuggestionService';
import { FreeDayDetectionService } from '../services/FreeDayDetectionService';
import { EarningsService } from '../services/EarningsService';
import { WeatherService } from '../services/WeatherService';
import { LocationService } from '../services/LocationService';
import { AddEventSheet } from './AddEventSheet';

function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

function getTodayDateString(): string {
  const d = new Date();
  return d.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
}

function mapCalendarEventToEventCard(event: CalendarEvent): {
  id: string;
  title: string;
  timeRange: string;
  location: string;
  category: 'work' | 'personal' | 'social' | 'health' | 'travel' | 'other';
  isOutdoor: boolean;
  hasNotification: boolean;
} {
  const formatTime = (iso: string) => {
    const d = new Date(iso);
    return d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
  };

  let displayCategory: 'work' | 'personal' | 'social' | 'health' | 'travel' | 'other' = 'other';
  switch (event.category?.toLowerCase()) {
    case 'meeting':
    case 'work':
      displayCategory = 'work';
      break;
    case 'workout':
    case 'health':
      displayCategory = 'health';
      break;
    case 'social':
      displayCategory = 'social';
      break;
    case 'travel':
      displayCategory = 'travel';
      break;
    case 'appointment':
    case 'errand':
      displayCategory = 'personal';
      break;
  }

  return {
    id: event.id,
    title: event.title,
    timeRange: event.isAllDay ? 'All Day' : `${formatTime(event.startDate)} - ${formatTime(event.endDate)}`,
    location: event.location || 'No location set',
    category: displayCategory,
    isOutdoor: event.isOutdoor,
    hasNotification: event.notificationEnabled,
  };
}

const suggestionService = new ActivitySuggestionService();
const freeDayService = new FreeDayDetectionService();
const earningsService = new EarningsService();
const weatherServiceInstance = new WeatherService();
const locationService = new LocationService();

export function TodayScreen() {
  const insets = useSafeAreaInsets();
  const { db, ready } = useDatabase();

  const events = useEventStore((s) => s.events);
  const setEvents = useEventStore((s) => s.setEvents);
  const addEventToStore = useEventStore((s) => s.addEvent);

  const weather = useWeatherStore((s) => s.currentSnapshot);
  const setWeather = useWeatherStore((s) => s.setWeather);

  const incomeEntries = useMoneyStore((s) => s.incomeEntries);
  const workSessions = useMoneyStore((s) => s.workSessions);
  const setEntries = useMoneyStore((s) => s.setEntries);
  const setSessions = useMoneyStore((s) => s.setSessions);

  const settings = useSettingsStore((s) => s.settings);

  const [refreshing, setRefreshing] = useState(false);
  const [suggestions, setSuggestions] = useState<ActivitySuggestion[]>([]);
  const [isFreeDay, setIsFreeDay] = useState(false);
  const [freeDayMessage, setFreeDayMessage] = useState('');
  const [addSheetVisible, setAddSheetVisible] = useState(false);
  const [city, setCity] = useState('Unknown');

  const today = new Date();
  const todayStr = today.toISOString().slice(0, 10);
  const todayEvents = events.filter((e) => {
    const startStr = e.startDate.slice(0, 10);
    const endStr = e.endDate.slice(0, 10);
    return startStr <= todayStr && endStr >= todayStr;
  });
  todayEvents.sort((a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime());

  const now = new Date();
  const upcomingEvent = todayEvents.find((e) => new Date(e.endDate) >= now) || null;

  const monthlyTotal = earningsService.monthlyTotal(today, incomeEntries, workSessions);
  const monthlyGoal = settings?.monthlyIncomeGoal ?? 0;

  const loadData = useCallback(async () => {
    if (!db) return;

    const rows = await db.getAllAsync<any>('SELECT * FROM calendar_events ORDER BY start_date ASC');
    const mapped: CalendarEvent[] = rows.map((r: any) => ({
      id: r.id,
      title: r.title,
      startDate: r.start_date,
      endDate: r.end_date,
      isAllDay: r.is_all_day === 1,
      location: r.location ?? undefined,
      notes: r.notes ?? undefined,
      category: r.category ?? undefined,
      isOutdoor: r.is_outdoor === 1,
      recurrenceRule: r.recurrence_rule ?? undefined,
      notificationEnabled: r.notification_enabled === 1,
      reminderMinutesBefore: r.reminder_minutes_before ?? 30,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    }));
    setEvents(mapped);

    const incomeRows = await db.getAllAsync<any>('SELECT * FROM income_entries ORDER BY date DESC');
    setEntries(incomeRows.map((r: any) => ({
      id: r.id,
      date: r.date,
      amount: r.amount,
      source: r.source,
      descriptionText: r.description_text,
      category: r.category,
      createdAt: r.created_at,
    })));

    const sessionRows = await db.getAllAsync<any>('SELECT * FROM work_sessions ORDER BY date DESC');
    setSessions(sessionRows.map((r: any) => ({
      id: r.id,
      date: r.date,
      startTime: r.start_time,
      endTime: r.end_time,
      hourlyRate: r.hourly_rate,
      totalEarned: r.total_earned,
      descriptionText: r.description_text,
      createdAt: r.created_at,
    })));

    const location = await locationService.getCurrentLocation();
    if (location) {
      setCity(location.city);
      const snap = await weatherServiceInstance.fetchWeather(location.latitude, location.longitude);
      if (snap) {
        setWeather(snap);
      }
    }

    try {
      const suggestionRows = await db.getAllAsync<any>(
        'SELECT * FROM activity_suggestions WHERE date = ? ORDER BY created_at DESC LIMIT 5',
        todayStr
      );
      if (suggestionRows.length > 0) {
        setSuggestions(suggestionRows.map((r: any) => ({
          id: r.id,
          date: r.date,
          title: r.title,
          summary: r.summary,
          category: r.category,
          estimatedDurationMinutes: r.estimated_duration_minutes,
          estimatedCostLevel: r.estimated_cost_level,
          placeName: r.place_name ?? undefined,
          placeId: r.place_id ?? undefined,
          weatherReason: r.weather_reason ?? undefined,
          aiProvider: r.ai_provider ?? undefined,
          createdAt: r.created_at,
        })));
      } else {
        setSuggestions([]);
      }
    } catch {
      setSuggestions([]);
    }

    computeFreeDay(mapped);
  }, [db, todayStr]);

  const computeFreeDay = (currentEvents: CalendarEvent[]) => {
    const windows = freeDayService.freeWindows(today, currentEvents);
    const thresholdHours = settings?.freeDayThresholdHours ?? 4;
    const free = windows.length === 0 || windows.some(
      (w) => (w.end.getTime() - w.start.getTime()) >= thresholdHours * 3600_000
    );
    setIsFreeDay(free);
    if (free) {
      setFreeDayMessage(freeDayService.notificationBody(windows, weather ? {
        precipitationChance: weather.precipitationChance,
        temperatureCelsius: weather.temperatureCelsius,
      } : undefined));
    }
  };

  useEffect(() => {
    if (ready) {
      loadData();
    }
  }, [ready, loadData]);

  useEffect(() => {
    if (events.length > 0) {
      computeFreeDay(events);
    }
  }, [events, settings]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await loadData();
    setRefreshing(false);
  }, [loadData]);

  const handleGetSuggestions = useCallback(() => {
    if (!db) return;

    const windows = freeDayService.freeWindows(today, events);
    const newSuggestions = suggestionService.generateFreeDaySuggestions(
      today, windows, weather, [], settings ?? undefined
    );

    setSuggestions(newSuggestions);

    newSuggestions.forEach(async (s) => {
      await db.runAsync(
        `INSERT OR REPLACE INTO activity_suggestions (id, date, title, summary, category, estimated_duration_minutes, estimated_cost_level, place_name, place_id, weather_reason, ai_provider, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        s.id, s.date, s.title, s.summary, s.category, s.estimatedDurationMinutes,
        s.estimatedCostLevel, s.placeName ?? null, s.placeId ?? null,
        s.weatherReason ?? null, s.aiProvider ?? null, s.createdAt
      );
    });
  }, [db, today, events, weather, settings]);

  const handleEventPress = useCallback((eventId: string) => {
    const { router } = require('expo-router');
    router.push(`/event/${eventId}`);
  }, []);

  const mapSuggestionToComponent = (s: ActivitySuggestion) => {
    const catMap: Record<string, 'outdoor' | 'indoor' | 'food' | 'culture' | 'sports' | 'relax' | 'social'> = {
      Nature: 'outdoor', Fitness: 'sports', Food: 'food', Culture: 'culture',
      Entertainment: 'culture', Shopping: 'indoor', Social: 'social',
      Relaxation: 'relax', Learning: 'indoor', Productivity: 'indoor',
      Adventure: 'outdoor', Creative: 'culture',
    };
    const componentCat = catMap[s.category] || 'indoor';
    const hours = Math.floor(s.estimatedDurationMinutes / 60);
    const mins = s.estimatedDurationMinutes % 60;
    const durStr = hours > 0 ? `${hours}h ${mins > 0 ? `${mins}m` : ''}` : `${mins}m`;

    return {
      id: s.id,
      title: s.title,
      summary: s.summary,
      category: componentCat,
      duration: durStr.trim(),
      cost: s.estimatedCostLevel,
    };
  };

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.primary} />}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.greetingSection}>
          <Text style={styles.greeting}>{getGreeting()}</Text>
          <Text style={styles.date}>{getTodayDateString()}</Text>
        </View>

        {weather && (
          <WeatherStrip
            condition={weather.condition}
            temperature={Math.round(weather.temperatureCelsius)}
            city={city}
          />
        )}

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Up Next</Text>
          {upcomingEvent ? (
            <EventCard
              event={mapCalendarEventToEventCard(upcomingEvent)}
              onPress={() => handleEventPress(upcomingEvent.id)}
            />
          ) : (
            <EmptyState icon="📅" title="No events today" subtitle="Tap + to add one" />
          )}
        </View>

        {isFreeDay && events.length > 0 && (
          <FreeDayBanner message={freeDayMessage} onGetSuggestions={handleGetSuggestions} />
        )}

        {suggestions.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Suggestions</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.suggestionScroll}>
              {suggestions.slice(0, 5).map((s) => (
                <View key={s.id} style={styles.suggestionCardWrapper}>
                  <SuggestionCard
                    suggestion={mapSuggestionToComponent(s)}
                    onPress={() => {}}
                  />
                </View>
              ))}
            </ScrollView>
          </View>
        )}

        <View style={styles.section}>
          <Card>
            <MonthlyProgressBar current={monthlyTotal} goal={monthlyGoal} />
          </Card>
        </View>
      </ScrollView>

      <TouchableOpacity
        style={[styles.fab, { bottom: insets.bottom + Spacing.xxl }]}
        onPress={() => setAddSheetVisible(true)}
        activeOpacity={0.8}
      >
        <Text style={styles.fabText}>+</Text>
      </TouchableOpacity>

      <AddEventSheet
        visible={addSheetVisible}
        onClose={() => setAddSheetVisible(false)}
        onSave={async (eventData) => {
          if (!db) return;
          const now = new Date().toISOString();
          const newEvent: CalendarEvent = {
            id: uuidv4(),
            title: eventData.title,
            startDate: eventData.startDate,
            endDate: eventData.endDate,
            isAllDay: eventData.isAllDay,
            location: eventData.location || undefined,
            notes: eventData.notes || undefined,
            category: eventData.category || undefined,
            isOutdoor: eventData.isOutdoor,
            recurrenceRule: undefined,
            notificationEnabled: eventData.notificationEnabled,
            reminderMinutesBefore: eventData.reminderMinutesBefore,
            createdAt: now,
            updatedAt: now,
          };

          await db.runAsync(
            `INSERT INTO calendar_events (id, title, start_date, end_date, is_all_day, location, notes, category, is_outdoor, recurrence_rule, notification_enabled, reminder_minutes_before, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            newEvent.id, newEvent.title, newEvent.startDate, newEvent.endDate,
            newEvent.isAllDay ? 1 : 0, newEvent.location ?? null, newEvent.notes ?? null,
            newEvent.category ?? null, newEvent.isOutdoor ? 1 : 0, null,
            newEvent.notificationEnabled ? 1 : 0, newEvent.reminderMinutesBefore,
            newEvent.createdAt, newEvent.updatedAt
          );

          addEventToStore(newEvent);

          try {
            const { notificationService } = require('../services/NotificationService');
            if (newEvent.notificationEnabled) {
              await notificationService.scheduleEventReminder(newEvent, newEvent.reminderMinutesBefore);
            }
          } catch {}
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  scrollContent: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.xxxl * 3,
  },
  greetingSection: {
    paddingVertical: Spacing.xl,
  },
  greeting: {
    fontSize: FontSize.title,
    fontWeight: '700',
    color: Colors.text,
  },
  date: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
    marginTop: Spacing.xs,
  },
  section: {
    marginTop: Spacing.lg,
  },
  sectionTitle: {
    fontSize: FontSize.lg,
    fontWeight: '600',
    color: Colors.text,
    marginBottom: Spacing.sm,
  },
  suggestionScroll: {
    flexDirection: 'row',
  },
  suggestionCardWrapper: {
    width: 280,
    marginRight: Spacing.md,
  },
  fab: {
    position: 'absolute',
    right: Spacing.xxl,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: Colors.primary,
    justifyContent: 'center',
    alignItems: 'center',
    ...Shadow.lg,
  },
  fabText: {
    fontSize: FontSize.xxl,
    color: '#FFFFFF',
    fontWeight: '600',
  },
});
