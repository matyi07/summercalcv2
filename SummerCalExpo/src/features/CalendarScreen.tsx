import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  RefreshControl,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { v4 as uuidv4 } from 'uuid';
import {
  startOfMonth,
  endOfMonth,
  startOfWeek,
  endOfWeek,
  eachDayOfInterval,
  format,
  isSameDay,
  isSameMonth,
  addMonths,
  subMonths,
  parseISO,
} from 'date-fns';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';
import { useEventStore, useSettingsStore } from '../store';
import { useDatabase } from '../hooks/useDatabase';
import { CalendarEvent } from '../models';
import { AddEventSheet } from './AddEventSheet';

const WEEKDAY_HEADERS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

const CATEGORY_COLORS: Record<string, string> = {
  meeting: Colors.info,
  workout: Colors.success,
  health: Colors.success,
  appointment: Colors.warning,
  travel: '#5AC8FA',
  social: '#AF52DE',
  errand: Colors.textSecondary,
  work: Colors.info,
  personal: Colors.warning,
  other: Colors.textTertiary,
};

function formatTimeRange(event: CalendarEvent): string {
  if (event.isAllDay) return 'All Day';
  const start = new Date(event.startDate);
  const end = new Date(event.endDate);
  const fmt = (d: Date) =>
    d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
  return `${fmt(start)} - ${fmt(end)}`;
}

export function CalendarScreen() {
  const insets = useSafeAreaInsets();
  const { db, ready } = useDatabase();

  const events = useEventStore((s) => s.events);
  const setEvents = useEventStore((s) => s.setEvents);
  const addEventToStore = useEventStore((s) => s.addEvent);
  const deleteEventFromStore = useEventStore((s) => s.deleteEvent);

  const settings = useSettingsStore((s) => s.settings);

  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [refreshing, setRefreshing] = useState(false);
  const [addSheetVisible, setAddSheetVisible] = useState(false);
  const [editEventId, setEditEventId] = useState<string | undefined>(undefined);

  const loadEvents = useCallback(async () => {
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
  }, [db]);

  useEffect(() => {
    if (ready) {
      loadEvents();
    }
  }, [ready, loadEvents]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await loadEvents();
    setRefreshing(false);
  }, [loadEvents]);

  const daysInGrid = useMemo(() => {
    const monthStart = startOfMonth(currentMonth);
    const monthEnd = endOfMonth(currentMonth);
    const calStart = startOfWeek(monthStart, { weekStartsOn: 0 });
    const calEnd = endOfWeek(monthEnd, { weekStartsOn: 0 });
    return eachDayOfInterval({ start: calStart, end: calEnd });
  }, [currentMonth]);

  const eventsByDate = useMemo(() => {
    const map = new Map<string, CalendarEvent[]>();
    for (const event of events) {
      const startDate = parseISO(event.startDate);
      const endDate = parseISO(event.endDate);
      let current = new Date(startDate);
      while (current <= endDate) {
        const key = format(current, 'yyyy-MM-dd');
        const list = map.get(key) || [];
        list.push(event);
        map.set(key, list);
        current.setDate(current.getDate() + 1);
      }
    }
    return map;
  }, [events]);

  const selectedDateKey = format(selectedDate, 'yyyy-MM-dd');
  const selectedEvents = useMemo(
    () => (eventsByDate.get(selectedDateKey) || []).sort(
      (a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime()
    ),
    [eventsByDate, selectedDateKey]
  );

  const today = new Date();

  const goToPrevMonth = () => setCurrentMonth((m) => subMonths(m, 1));
  const goToNextMonth = () => setCurrentMonth((m) => addMonths(m, 1));

  const handleDayPress = (day: Date) => {
    setSelectedDate(day);
  };

  const handleEventPress = (eventId: string) => {
    router.push(`/event/${eventId}`);
  };

  const handleEventLongPress = (event: CalendarEvent) => {
    Alert.alert(
      'Delete Event',
      `Delete "${event.title}"?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            if (!db) return;
            await db.runAsync('DELETE FROM calendar_events WHERE id = ?', event.id);
            await db.runAsync('DELETE FROM event_notes WHERE event_id = ?', event.id);
            deleteEventFromStore(event.id);
          },
        },
      ]
    );
  };

  const handleEditEvent = (event: CalendarEvent) => {
    setEditEventId(event.id);
    setAddSheetVisible(true);
  };

  const categoryDot = (event: CalendarEvent) => {
    const color = CATEGORY_COLORS[event.category?.toLowerCase() ?? ''] || Colors.textTertiary;
    return <View style={[styles.dot, { backgroundColor: color }]} />;
  };

  const rows = [];
  for (let i = 0; i < daysInGrid.length; i += 7) {
    rows.push(daysInGrid.slice(i, i + 7));
  }

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.primary} />}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.monthHeader}>
          <TouchableOpacity onPress={goToPrevMonth} style={styles.navArrow}>
            <Text style={styles.navArrowText}>{'<'}</Text>
          </TouchableOpacity>
          <Text style={styles.monthTitle}>{format(currentMonth, 'MMMM yyyy')}</Text>
          <TouchableOpacity onPress={goToNextMonth} style={styles.navArrow}>
            <Text style={styles.navArrowText}>{'>'}</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.weekdayRow}>
          {WEEKDAY_HEADERS.map((day, idx) => (
            <View key={idx} style={styles.weekdayCell}>
              <Text style={styles.weekdayText}>{day}</Text>
            </View>
          ))}
        </View>

        {rows.map((row, rowIdx) => (
          <View key={rowIdx} style={styles.gridRow}>
            {row.map((day) => {
              const dayKey = format(day, 'yyyy-MM-dd');
              const dayEvents = eventsByDate.get(dayKey) || [];
              const isToday = isSameDay(day, today);
              const isSelected = isSameDay(day, selectedDate);
              const inMonth = isSameMonth(day, currentMonth);
              const hasEvents = dayEvents.length > 0;

              return (
                <TouchableOpacity
                  key={dayKey}
                  style={[
                    styles.dayCell,
                    isSelected && styles.dayCellSelected,
                  ]}
                  onPress={() => handleDayPress(day)}
                  activeOpacity={0.7}
                >
                  <View style={[isToday && styles.todayCircle]}>
                    <Text
                      style={[
                        styles.dayText,
                        !inMonth && styles.dayTextOutside,
                        isToday && styles.todayText,
                        isSelected && styles.dayTextSelected,
                      ]}
                    >
                      {format(day, 'd')}
                    </Text>
                  </View>
                  {hasEvents && (
                    <View style={styles.dotsRow}>
                      {dayEvents.slice(0, 3).map((ev) => (
                        <View key={ev.id} style={styles.dot} />
                      ))}
                    </View>
                  )}
                </TouchableOpacity>
              );
            })}
          </View>
        ))}

        <View style={styles.agendaSection}>
          <Text style={styles.agendaTitle}>
            {isSameDay(selectedDate, today) ? 'Today' : format(selectedDate, 'EEE, MMM d')}
          </Text>
          {selectedEvents.length === 0 ? (
            <View style={styles.emptyAgenda}>
              <Text style={styles.emptyAgendaText}>No events on this day</Text>
            </View>
          ) : (
            selectedEvents.map((event) => (
              <TouchableOpacity
                key={event.id}
                style={styles.agendaItem}
                onPress={() => handleEventPress(event.id)}
                onLongPress={() => handleEventLongPress(event)}
                activeOpacity={0.7}
              >
                <View style={styles.agendaRow}>
                  {event.category && (
                    <View
                      style={[
                        styles.categoryBadge,
                        { backgroundColor: (CATEGORY_COLORS[event.category.toLowerCase()] || Colors.textTertiary) + '20' },
                      ]}
                    >
                      <Text
                        style={[
                          styles.categoryBadgeText,
                          { color: CATEGORY_COLORS[event.category.toLowerCase()] || Colors.textTertiary },
                        ]}
                      >
                        {event.category}
                      </Text>
                    </View>
                  )}
                  {event.isOutdoor && (
                    <View style={styles.outdoorBadge}>
                      <Text style={styles.outdoorBadgeText}>🌿</Text>
                    </View>
                  )}
                </View>
                <Text style={styles.agendaEventTitle} numberOfLines={1}>{event.title}</Text>
                <Text style={styles.agendaEventTime}>{formatTimeRange(event)}</Text>
              </TouchableOpacity>
            ))
          )}
        </View>
      </ScrollView>

      <TouchableOpacity
        style={[styles.fab, { bottom: insets.bottom + Spacing.xxl }]}
        onPress={() => {
          setEditEventId(undefined);
          setAddSheetVisible(true);
        }}
        activeOpacity={0.8}
      >
        <Text style={styles.fabText}>+</Text>
      </TouchableOpacity>

      <AddEventSheet
        visible={addSheetVisible}
        onClose={() => {
          setAddSheetVisible(false);
          setEditEventId(undefined);
        }}
        eventId={editEventId}
        onSave={async (eventData) => {
          if (!db) return;
          if (editEventId) {
            const now = new Date().toISOString();
            await db.runAsync(
              `UPDATE calendar_events SET title = ?, start_date = ?, end_date = ?, is_all_day = ?, location = ?, notes = ?, category = ?, is_outdoor = ?, notification_enabled = ?, reminder_minutes_before = ?, updated_at = ?
               WHERE id = ?`,
              eventData.title, eventData.startDate, eventData.endDate,
              eventData.isAllDay ? 1 : 0, eventData.location ?? null, eventData.notes ?? null,
              eventData.category ?? null, eventData.isOutdoor ? 1 : 0,
              eventData.notificationEnabled ? 1 : 0, eventData.reminderMinutesBefore,
              now, editEventId
            );

            const existingEvent = events.find((e) => e.id === editEventId);
            if (existingEvent) {
              const updated: CalendarEvent = {
                ...existingEvent,
                ...eventData,
                id: editEventId,
                updatedAt: now,
              };
              useEventStore.getState().updateEvent(updated);
            }

            try {
              const { notificationService } = require('../services/NotificationService');
              if (eventData.notificationEnabled) {
                const ev = events.find((e) => e.id === editEventId);
                if (ev) {
                  await notificationService.scheduleEventReminder(ev, eventData.reminderMinutesBefore);
                }
              }
            } catch {}
          } else {
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
          }
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
  monthHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.lg,
  },
  navArrow: {
    padding: Spacing.sm,
  },
  navArrowText: {
    fontSize: FontSize.xl,
    fontWeight: '700',
    color: Colors.primary,
  },
  monthTitle: {
    fontSize: FontSize.xl,
    fontWeight: '700',
    color: Colors.text,
  },
  weekdayRow: {
    flexDirection: 'row',
    marginBottom: Spacing.xs,
  },
  weekdayCell: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: Spacing.sm,
  },
  weekdayText: {
    fontSize: FontSize.sm,
    fontWeight: '600',
    color: Colors.textSecondary,
  },
  gridRow: {
    flexDirection: 'row',
  },
  dayCell: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: Spacing.md,
    borderRadius: BorderRadius.sm,
    marginVertical: 2,
  },
  dayCellSelected: {
    borderWidth: 2,
    borderColor: Colors.primary,
  },
  todayCircle: {
    width: 30,
    height: 30,
    borderRadius: 15,
    backgroundColor: Colors.primary,
    justifyContent: 'center',
    alignItems: 'center',
  },
  dayText: {
    fontSize: FontSize.md,
    color: Colors.text,
  },
  dayTextOutside: {
    color: Colors.textTertiary,
  },
  todayText: {
    color: '#FFFFFF',
    fontWeight: '700',
  },
  dayTextSelected: {
    fontWeight: '700',
  },
  dotsRow: {
    flexDirection: 'row',
    marginTop: Spacing.xs,
    height: 8,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 2,
  },
  dot: {
    width: 5,
    height: 5,
    borderRadius: 3,
    backgroundColor: Colors.warning,
  },
  agendaSection: {
    marginTop: Spacing.xxl,
  },
  agendaTitle: {
    fontSize: FontSize.lg,
    fontWeight: '700',
    color: Colors.text,
    marginBottom: Spacing.md,
  },
  emptyAgenda: {
    paddingVertical: Spacing.xxxl,
    alignItems: 'center',
  },
  emptyAgendaText: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
  },
  agendaItem: {
    backgroundColor: Colors.card,
    borderRadius: BorderRadius.md,
    padding: Spacing.lg,
    marginBottom: Spacing.sm,
    ...Shadow.sm,
  },
  agendaRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.xs,
  },
  categoryBadge: {
    paddingHorizontal: Spacing.sm,
    paddingVertical: 2,
    borderRadius: BorderRadius.sm,
  },
  categoryBadgeText: {
    fontSize: FontSize.xs,
    fontWeight: '600',
  },
  outdoorBadge: {},
  outdoorBadgeText: {
    fontSize: FontSize.sm,
  },
  agendaEventTitle: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.text,
    marginBottom: 4,
  },
  agendaEventTime: {
    fontSize: FontSize.sm,
    color: Colors.textSecondary,
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
