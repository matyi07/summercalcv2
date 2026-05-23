import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  ScrollView,
  TouchableOpacity,
  TextInput,
  Switch,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { v4 as uuidv4 } from 'uuid';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';
import { useEventStore, useSettingsStore } from '../store';
import { useDatabase } from '../hooks/useDatabase';
import { CalendarEvent } from '../models';

interface AddEventSheetProps {
  visible: boolean;
  onClose: () => void;
  eventId?: string;
  onSave?: (eventData: {
    title: string;
    startDate: string;
    endDate: string;
    isAllDay: boolean;
    location?: string;
    notes?: string;
    category?: string;
    isOutdoor: boolean;
    notificationEnabled: boolean;
    reminderMinutesBefore: number;
  }) => void | Promise<void>;
}

const CATEGORIES = ['Meeting', 'Workout', 'Appointment', 'Travel', 'Social', 'Errand', 'Other'];

function toLocalDateString(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function toLocalTimeString(date: Date): string {
  const h = String(date.getHours()).padStart(2, '0');
  const min = String(date.getMinutes()).padStart(2, '0');
  return `${h}:${min}`;
}

function combineDateAndTime(dateStr: string, timeStr: string): string {
  const [h, m] = timeStr.split(':').map(Number);
  const d = new Date(dateStr + 'T00:00:00');
  d.setHours(h || 0, m || 0, 0, 0);
  return d.toISOString();
}

export function AddEventSheet({ visible, onClose, eventId, onSave }: AddEventSheetProps) {
  const insets = useSafeAreaInsets();
  const { db } = useDatabase();

  const events = useEventStore((s) => s.events);
  const addEventToStore = useEventStore((s) => s.addEvent);
  const updateEventInStore = useEventStore((s) => s.updateEvent);

  const settings = useSettingsStore((s) => s.settings);

  const [title, setTitle] = useState('');
  const [isAllDay, setIsAllDay] = useState(false);
  const [startDate, setStartDate] = useState(toLocalDateString(new Date()));
  const [startTime, setStartTime] = useState('09:00');
  const [endDate, setEndDate] = useState(toLocalDateString(new Date()));
  const [endTime, setEndTime] = useState('10:00');
  const [location, setLocation] = useState('');
  const [notes, setNotes] = useState('');
  const [category, setCategory] = useState('Other');
  const [isOutdoor, setIsOutdoor] = useState(false);
  const [notificationEnabled, setNotificationEnabled] = useState(true);
  const [reminderMinutes, setReminderMinutes] = useState('30');

  const isEditing = !!eventId;

  useEffect(() => {
    if (!visible) return;
    if (eventId) {
      const existing = events.find((e) => e.id === eventId);
      if (existing) {
        setTitle(existing.title);
        setIsAllDay(existing.isAllDay);

        const sDate = new Date(existing.startDate);
        const eDate = new Date(existing.endDate);
        setStartDate(toLocalDateString(sDate));
        setStartTime(toLocalTimeString(sDate));
        setEndDate(toLocalDateString(eDate));
        setEndTime(toLocalTimeString(eDate));

        setLocation(existing.location || '');
        setNotes(existing.notes || '');
        setCategory(existing.category || 'Other');
        setIsOutdoor(existing.isOutdoor);
        setNotificationEnabled(existing.notificationEnabled);
        setReminderMinutes(String(existing.reminderMinutesBefore));
      }
    } else {
      resetForm();
    }
  }, [visible, eventId, events]);

  const resetForm = () => {
    setTitle('');
    setIsAllDay(false);
    const now = new Date();
    const later = new Date(now.getTime() + 60 * 60 * 1000);
    setStartDate(toLocalDateString(now));
    setStartTime(toLocalTimeString(now));
    setEndDate(toLocalDateString(later));
    setEndTime(toLocalTimeString(later));
    setLocation('');
    setNotes('');
    setCategory('Other');
    setIsOutdoor(false);
    setNotificationEnabled(true);
    setReminderMinutes('30');
  };

  const buildEventData = (): {
    title: string;
    startDate: string;
    endDate: string;
    isAllDay: boolean;
    location?: string;
    notes?: string;
    category?: string;
    isOutdoor: boolean;
    notificationEnabled: boolean;
    reminderMinutesBefore: number;
  } => {
    return {
      title,
      startDate: isAllDay ? startDate + 'T00:00:00.000Z' : combineDateAndTime(startDate, startTime),
      endDate: isAllDay ? endDate + 'T23:59:59.000Z' : combineDateAndTime(endDate, endTime),
      isAllDay,
      location: location.trim() || undefined,
      notes: notes.trim() || undefined,
      category: category || undefined,
      isOutdoor,
      notificationEnabled,
      reminderMinutesBefore: parseInt(reminderMinutes, 10) || 30,
    };
  };

  const handleSave = async () => {
    if (!title.trim()) return;

    const eventData = buildEventData();

    if (onSave) {
      await onSave(eventData);
      onClose();
      return;
    }

    if (!db) return;

    const now = new Date().toISOString();

    if (isEditing && eventId) {
      await db.runAsync(
        `UPDATE calendar_events SET title = ?, start_date = ?, end_date = ?, is_all_day = ?, location = ?, notes = ?, category = ?, is_outdoor = ?, notification_enabled = ?, reminder_minutes_before = ?, updated_at = ?
         WHERE id = ?`,
        eventData.title, eventData.startDate, eventData.endDate,
        eventData.isAllDay ? 1 : 0, eventData.location ?? null, eventData.notes ?? null,
        eventData.category ?? null, eventData.isOutdoor ? 1 : 0,
        eventData.notificationEnabled ? 1 : 0, eventData.reminderMinutesBefore,
        now, eventId
      );

      const existingEvent = events.find((e) => e.id === eventId);
      if (existingEvent) {
        const updated: CalendarEvent = { ...existingEvent, ...eventData, id: eventId, updatedAt: now };
        updateEventInStore(updated);

        try {
          const { notificationService } = require('../services/NotificationService');
          await notificationService.cancelEventReminders(eventId);
          if (eventData.notificationEnabled) {
            await notificationService.scheduleEventReminder(updated, eventData.reminderMinutesBefore);
          }
        } catch {}
      }
    } else {
      const newEvent: CalendarEvent = {
        id: uuidv4(),
        title: eventData.title,
        startDate: eventData.startDate,
        endDate: eventData.endDate,
        isAllDay: eventData.isAllDay,
        location: eventData.location,
        notes: eventData.notes,
        category: eventData.category,
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

    onClose();
  };

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="formSheet"
      onRequestClose={onClose}
    >
      <KeyboardAvoidingView
        style={styles.modalContainer}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <View style={[styles.header, { paddingTop: insets.top + Spacing.md }]}>
          <TouchableOpacity onPress={onClose}>
            <Text style={styles.cancelText}>Cancel</Text>
          </TouchableOpacity>
          <Text style={styles.headerTitle}>{isEditing ? 'Edit Event' : 'New Event'}</Text>
          <TouchableOpacity onPress={handleSave}>
            <Text style={styles.saveText}>Save</Text>
          </TouchableOpacity>
        </View>

        <ScrollView
          contentContainerStyle={styles.formContent}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <Text style={styles.fieldLabel}>Title</Text>
          <TextInput
            style={styles.textInput}
            value={title}
            onChangeText={setTitle}
            placeholder="Event title"
            placeholderTextColor={Colors.textTertiary}
            autoFocus={!isEditing}
          />

          <View style={styles.switchRow}>
            <Text style={styles.fieldLabel}>All-day</Text>
            <Switch
              value={isAllDay}
              onValueChange={setIsAllDay}
              trackColor={{ false: Colors.border, true: Colors.primaryLight }}
              thumbColor={isAllDay ? Colors.primary : Colors.textTertiary}
            />
          </View>

          <Text style={styles.fieldLabel}>Start</Text>
          <View style={styles.dateTimeRow}>
            <TextInput
              style={[styles.textInput, styles.dateInput]}
              value={startDate}
              onChangeText={setStartDate}
              placeholder="YYYY-MM-DD"
              placeholderTextColor={Colors.textTertiary}
              autoCapitalize="none"
            />
            {!isAllDay && (
              <TextInput
                style={[styles.textInput, styles.timeInput]}
                value={startTime}
                onChangeText={setStartTime}
                placeholder="HH:MM"
                placeholderTextColor={Colors.textTertiary}
                autoCapitalize="none"
              />
            )}
          </View>

          <Text style={styles.fieldLabel}>End</Text>
          <View style={styles.dateTimeRow}>
            <TextInput
              style={[styles.textInput, styles.dateInput]}
              value={endDate}
              onChangeText={setEndDate}
              placeholder="YYYY-MM-DD"
              placeholderTextColor={Colors.textTertiary}
              autoCapitalize="none"
            />
            {!isAllDay && (
              <TextInput
                style={[styles.textInput, styles.timeInput]}
                value={endTime}
                onChangeText={setEndTime}
                placeholder="HH:MM"
                placeholderTextColor={Colors.textTertiary}
                autoCapitalize="none"
              />
            )}
          </View>

          <Text style={styles.fieldLabel}>Location</Text>
          <TextInput
            style={styles.textInput}
            value={location}
            onChangeText={setLocation}
            placeholder="Event location"
            placeholderTextColor={Colors.textTertiary}
          />

          <Text style={styles.fieldLabel}>Notes</Text>
          <TextInput
            style={[styles.textInput, styles.textArea]}
            value={notes}
            onChangeText={setNotes}
            placeholder="Event notes..."
            placeholderTextColor={Colors.textTertiary}
            multiline
            numberOfLines={3}
            textAlignVertical="top"
          />

          <Text style={styles.fieldLabel}>Category</Text>
          <View style={styles.categoryRow}>
            {CATEGORIES.map((cat) => (
              <TouchableOpacity
                key={cat}
                style={[
                  styles.categoryChip,
                  category === cat && styles.categoryChipActive,
                ]}
                onPress={() => setCategory(cat)}
              >
                <Text
                  style={[
                    styles.categoryChipText,
                    category === cat && styles.categoryChipTextActive,
                  ]}
                >
                  {cat}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          <View style={styles.switchRow}>
            <Text style={styles.fieldLabel}>Outdoor Event</Text>
            <Switch
              value={isOutdoor}
              onValueChange={setIsOutdoor}
              trackColor={{ false: Colors.border, true: Colors.primaryLight }}
              thumbColor={isOutdoor ? Colors.primary : Colors.textTertiary}
            />
          </View>

          <View style={styles.divider} />

          <View style={styles.switchRow}>
            <Text style={styles.fieldLabel}>Enable Notification</Text>
            <Switch
              value={notificationEnabled}
              onValueChange={setNotificationEnabled}
              trackColor={{ false: Colors.border, true: Colors.primaryLight }}
              thumbColor={notificationEnabled ? Colors.primary : Colors.textTertiary}
            />
          </View>

          {notificationEnabled && (
            <View style={styles.reminderRow}>
              <Text style={styles.fieldLabel}>Reminder (minutes before)</Text>
              <TextInput
                style={[styles.textInput, styles.reminderInput]}
                value={reminderMinutes}
                onChangeText={setReminderMinutes}
                placeholder="30"
                placeholderTextColor={Colors.textTertiary}
                keyboardType="number-pad"
              />
            </View>
          )}
        </ScrollView>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalContainer: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  cancelText: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
  },
  headerTitle: {
    fontSize: FontSize.lg,
    fontWeight: '700',
    color: Colors.text,
  },
  saveText: {
    fontSize: FontSize.md,
    fontWeight: '700',
    color: Colors.primary,
  },
  formContent: {
    padding: Spacing.lg,
    paddingBottom: Spacing.xxxl * 2,
  },
  fieldLabel: {
    fontSize: FontSize.sm,
    fontWeight: '600',
    color: Colors.textSecondary,
    marginBottom: Spacing.xs,
    marginTop: Spacing.md,
  },
  textInput: {
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: BorderRadius.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
    fontSize: FontSize.md,
    color: Colors.text,
    backgroundColor: Colors.card,
  },
  textArea: {
    minHeight: 100,
    textAlignVertical: 'top',
  },
  dateTimeRow: {
    flexDirection: 'row',
    gap: Spacing.sm,
  },
  dateInput: {
    flex: 2,
  },
  timeInput: {
    flex: 1,
  },
  switchRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  categoryRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.sm,
  },
  categoryChip: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.full,
    borderWidth: 1,
    borderColor: Colors.border,
    backgroundColor: Colors.surface,
  },
  categoryChipActive: {
    backgroundColor: Colors.primary,
    borderColor: Colors.primary,
  },
  categoryChipText: {
    fontSize: FontSize.sm,
    color: Colors.textSecondary,
    fontWeight: '500',
  },
  categoryChipTextActive: {
    color: '#FFFFFF',
  },
  divider: {
    height: 1,
    backgroundColor: Colors.border,
    marginVertical: Spacing.lg,
  },
  reminderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  reminderInput: {
    width: 80,
    textAlign: 'center',
  },
});
