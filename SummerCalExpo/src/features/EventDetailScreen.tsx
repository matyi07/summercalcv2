import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  TextInput,
  Alert,
  Switch,
  RefreshControl,
  Modal,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { v4 as uuidv4 } from 'uuid';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';
import { useEventStore, useSettingsStore } from '../store';
import { useDatabase } from '../hooks/useDatabase';
import { EventNote, EventNoteType, AIMessage, CalendarEvent } from '../models';
import { EventNoteService } from '../services/EventNoteService';
import { AIProviderRouter, AIProviderClient } from '../services/AIProviderRouter';
import { Card } from '../components/Card';
import { EmptyState } from '../components/EmptyState';
import { AddEventSheet } from './AddEventSheet';
import { EventNoteSheet } from './EventNoteSheet';

interface EventDetailScreenProps {
  eventId: string;
}

type TabKey = 'notes' | 'prep' | 'checklist' | 'links';

const TAB_KEYS: TabKey[] = ['notes', 'prep', 'checklist', 'links'];
const TAB_LABELS: Record<TabKey, string> = {
  notes: '📋 Notes',
  prep: '🎯 Prep',
  checklist: '✅ Checklist',
  links: '🔗 Links',
};

const eventNoteService = new EventNoteService();

function formatDateTime(startIso: string, endIso: string, isAllDay: boolean): string {
  if (isAllDay) return 'All Day';
  const fmt = (iso: string) => {
    const d = new Date(iso);
    return d.toLocaleDateString('en-US', {
      weekday: 'short', month: 'short', day: 'numeric',
      hour: 'numeric', minute: '2-digit', hour12: true,
    });
  };
  return `${fmt(startIso)} - ${fmt(endIso)}`;
}

function formatTabDate(dateStr: string): string {
  return new Date(dateStr).toLocaleTimeString('en-US', {
    hour: 'numeric', minute: '2-digit', hour12: true,
  });
}

export function EventDetailScreen({ eventId }: EventDetailScreenProps) {
  const insets = useSafeAreaInsets();
  const { db, ready } = useDatabase();

  const events = useEventStore((s) => s.events);
  const deleteEventFromStore = useEventStore((s) => s.deleteEvent);
  const updateEventInStore = useEventStore((s) => s.updateEvent);

  const settings = useSettingsStore((s) => s.settings);

  const [activeTab, setActiveTab] = useState<TabKey>('notes');
  const [allNotes, setAllNotes] = useState<EventNote[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const [editSheetVisible, setEditSheetVisible] = useState(false);
  const [noteSheetVisible, setNoteSheetVisible] = useState(false);
  const [editNoteId, setEditNoteId] = useState<string | undefined>(undefined);
  const [generatingPrep, setGeneratingPrep] = useState(false);
  const [newChecklistItem, setNewChecklistItem] = useState('');
  const [newLinkUrl, setNewLinkUrl] = useState('');
  const [notificationEnabled, setNotificationEnabled] = useState(true);
  const [reminderMinutes, setReminderMinutes] = useState('30');

  const event = events.find((e) => e.id === eventId);

  useEffect(() => {
    if (event) {
      setNotificationEnabled(event.notificationEnabled);
      setReminderMinutes(String(event.reminderMinutesBefore));
    }
  }, [event]);

  const loadNotes = useCallback(async () => {
    if (!db) return;
    const notes = await eventNoteService.fetchNotesByEventId(db, eventId);
    setAllNotes(notes);
  }, [db, eventId]);

  useEffect(() => {
    if (ready) {
      loadNotes();
    }
  }, [ready, loadNotes]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await loadNotes();
    setRefreshing(false);
  }, [loadNotes]);

  const filteredNotes = allNotes.filter((n) => {
    switch (activeTab) {
      case 'notes': return n.noteType === EventNoteType.general || n.noteType === EventNoteType.postEvent || n.noteType === EventNoteType.aiSummary;
      case 'prep': return n.noteType === EventNoteType.prep;
      case 'checklist': return n.noteType === EventNoteType.checklist;
      case 'links': return n.noteType === EventNoteType.link;
    }
  });

  const handleDeleteEvent = () => {
    Alert.alert('Delete Event', 'Are you sure you want to delete this event?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          if (!db) return;
          await db.runAsync('DELETE FROM calendar_events WHERE id = ?', eventId);
          await db.runAsync('DELETE FROM event_notes WHERE event_id = ?', eventId);
          deleteEventFromStore(eventId);
          router.back();
        },
      },
    ]);
  };

  const handleDeleteNote = (noteId: string) => {
    Alert.alert('Delete Note', 'Delete this note?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          if (!db) return;
          await eventNoteService.deleteNote(db, noteId);
          setAllNotes((prev) => prev.filter((n) => n.id !== noteId));
        },
      },
    ]);
  };

  const handleAddChecklistItem = async (noteId: string) => {
    if (!db || !newChecklistItem.trim()) return;
    const updated = await eventNoteService.addChecklistItem(db, noteId, newChecklistItem.trim());
    setAllNotes((prev) =>
      prev.map((n) => (n.id === noteId ? { ...n, checklistItems: updated } : n))
    );
    setNewChecklistItem('');
  };

  const handleToggleChecklistItem = async (noteId: string, index: number) => {
    if (!db) return;
    const updated = await eventNoteService.toggleChecklistItem(db, noteId, index);
    setAllNotes((prev) =>
      prev.map((n) => (n.id === noteId ? { ...n, checklistItems: updated } : n))
    );
  };

  const handleAddLink = async (noteId: string) => {
    if (!db || !newLinkUrl.trim()) return;
    const updated = await eventNoteService.addLink(db, noteId, newLinkUrl.trim());
    setAllNotes((prev) =>
      prev.map((n) => (n.id === noteId ? { ...n, links: updated } : n))
    );
    setNewLinkUrl('');
  };

  const handleRemoveLink = async (noteId: string, index: number) => {
    if (!db) return;
    const updated = await eventNoteService.removeLink(db, noteId, index);
    setAllNotes((prev) =>
      prev.map((n) => (n.id === noteId ? { ...n, links: updated } : n))
    );
  };

  const handleGeneratePrep = async () => {
    if (!settings || generatingPrep) return;
    setGeneratingPrep(true);

    try {
      const apiKey = 'dummy';
      const router = new AIProviderRouter(() => apiKey);
      const client = router.getClient(settings.aiProviderKind as any, settings.aiBaseURL);
      if (!client) throw new Error('No AI client available');

      const messages: AIMessage[] = [
        {
          role: 'system',
          content: 'You are an event preparation assistant. Generate 3-5 practical preparation notes for the given event. Format as a list with each item prefixed by "- ". Keep each item concise (one sentence).',
        },
        {
          role: 'user',
          content: `Event: ${event?.title ?? 'Unknown'}\nDate: ${event?.startDate ?? 'Unknown'}\nLocation: ${event?.location ?? 'N/A'}\nCategory: ${event?.category ?? 'General'}\n${event?.isOutdoor ? 'This is an outdoor event.' : ''}\n\nGenerate preparation notes.`,
        },
      ];

      const response = await client.sendChat(messages, {
        model: settings.aiModelName,
        maxTokens: settings.aiMaxTokens,
        temperature: 0.7,
        baseURL: settings.aiBaseURL,
      });

      const items = response.content
        .split('\n')
        .filter((line) => line.trim().startsWith('-'))
        .map((line) => line.trim().replace(/^-\s*/, ''))
        .filter(Boolean);

      if (items.length === 0) {
        items.push(response.content.trim().slice(0, 500));
      }

      if (db) {
        const now = new Date().toISOString();
        const combinedBody = items.join('\n');
        const note: EventNote = {
          id: uuidv4(),
          eventId,
          body: combinedBody,
          noteType: EventNoteType.prep,
          checklistItems: [],
          links: [],
          createdAt: now,
          updatedAt: now,
        };

        await db.runAsync(
          `INSERT INTO event_notes (id, event_id, body, note_type, checklist_items, links, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          note.id, note.eventId, note.body, note.noteType, '[]', '[]', note.createdAt, note.updatedAt
        );

        setAllNotes((prev) => [...prev, note]);
      }
    } catch (err: any) {
      Alert.alert('Generation Failed', err.message || 'Could not generate prep notes. Check your AI settings.');
    } finally {
      setGeneratingPrep(false);
    }
  };

  const handleSaveNotification = async () => {
    if (!db || !event) return;
    const minutes = parseInt(reminderMinutes, 10) || 30;
    await db.runAsync(
      'UPDATE calendar_events SET notification_enabled = ?, reminder_minutes_before = ?, updated_at = ? WHERE id = ?',
      notificationEnabled ? 1 : 0, minutes, new Date().toISOString(), eventId
    );

    const updated: CalendarEvent = { ...event, notificationEnabled, reminderMinutesBefore: minutes, updatedAt: new Date().toISOString() };
    updateEventInStore(updated);

    try {
      const { notificationService } = require('../services/NotificationService');
      await notificationService.cancelEventReminders(eventId);
      if (notificationEnabled) {
        await notificationService.scheduleEventReminder(updated, minutes);
      }
    } catch {}
  };

  if (!event) {
    return (
      <View style={[styles.container, { paddingTop: insets.top, justifyContent: 'center', alignItems: 'center' }]}>
        <Text style={styles.notFoundText}>Event not found</Text>
        <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
          <Text style={styles.backButtonText}>Go Back</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.primary} />}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.header}>
          <Text style={styles.title}>{event.title}</Text>
          <Text style={styles.dateTime}>{formatDateTime(event.startDate, event.endDate, event.isAllDay)}</Text>
          {event.location ? (
            <Text style={styles.location}>📍 {event.location}</Text>
          ) : null}
          {event.isOutdoor && (
            <View style={styles.outdoorBadge}>
              <Text style={styles.outdoorBadgeText}>🌿 Outdoor Event</Text>
            </View>
          )}
          {event.category ? (
            <View style={styles.categoryBadge}>
              <Text style={styles.categoryBadgeText}>{event.category}</Text>
            </View>
          ) : null}
        </View>

        <View style={styles.actionButtons}>
          <TouchableOpacity style={styles.actionBtn} onPress={() => setEditSheetVisible(true)}>
            <Text style={styles.actionBtnText}>✏️ Edit</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.actionBtn, styles.deleteBtn]} onPress={handleDeleteEvent}>
            <Text style={[styles.actionBtnText, styles.deleteBtnText]}>🗑️ Delete</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.tabBar}>
          {TAB_KEYS.map((key) => (
            <TouchableOpacity
              key={key}
              style={[styles.tab, activeTab === key && styles.tabActive]}
              onPress={() => setActiveTab(key)}
            >
              <Text style={[styles.tabText, activeTab === key && styles.tabTextActive]}>
                {TAB_LABELS[key]}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        <View style={styles.tabContent}>
          {activeTab === 'notes' && (
            <View>
              <TouchableOpacity
                style={styles.addButton}
                onPress={() => {
                  setEditNoteId(undefined);
                  setNoteSheetVisible(true);
                }}
              >
                <Text style={styles.addButtonText}>+ Add Note</Text>
              </TouchableOpacity>
              {filteredNotes.length === 0 ? (
                <EmptyState icon="📝" title="No notes yet" subtitle="Add a note for this event" />
              ) : (
                filteredNotes.map((note) => (
                  <Card key={note.id} style={styles.noteCard}>
                    <Text style={styles.noteBody}>{note.body}</Text>
                    <Text style={styles.noteTime}>{formatTabDate(note.createdAt)}</Text>
                    <View style={styles.noteActions}>
                      <TouchableOpacity
                        onPress={() => {
                          setEditNoteId(note.id);
                          setNoteSheetVisible(true);
                        }}
                      >
                        <Text style={styles.noteAction}>Edit</Text>
                      </TouchableOpacity>
                      <TouchableOpacity onPress={() => handleDeleteNote(note.id)}>
                        <Text style={[styles.noteAction, styles.noteActionDelete]}>Delete</Text>
                      </TouchableOpacity>
                    </View>
                  </Card>
                ))
              )}
            </View>
          )}

          {activeTab === 'prep' && (
            <View>
              <TouchableOpacity
                style={styles.addButton}
                onPress={() => {
                  setEditNoteId(undefined);
                  setNoteSheetVisible(true);
                }}
              >
                <Text style={styles.addButtonText}>+ Add Prep Note</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.addButton, styles.aiButton, generatingPrep && styles.buttonDisabled]}
                onPress={handleGeneratePrep}
                disabled={generatingPrep}
              >
                <Text style={[styles.addButtonText, styles.aiButtonText]}>
                  {generatingPrep ? '🤖 Generating...' : '🤖 Generate with AI'}
                </Text>
              </TouchableOpacity>
              {filteredNotes.length === 0 ? (
                <EmptyState icon="🎯" title="No prep notes" subtitle="Add prep notes or generate with AI" />
              ) : (
                filteredNotes.map((note) => (
                  <Card key={note.id} style={styles.noteCard}>
                    <Text style={styles.noteBody}>{note.body}</Text>
                    <Text style={styles.noteTime}>{formatTabDate(note.createdAt)}</Text>
                    <View style={styles.noteActions}>
                      <TouchableOpacity
                        onPress={() => {
                          setEditNoteId(note.id);
                          setNoteSheetVisible(true);
                        }}
                      >
                        <Text style={styles.noteAction}>Edit</Text>
                      </TouchableOpacity>
                      <TouchableOpacity onPress={() => handleDeleteNote(note.id)}>
                        <Text style={[styles.noteAction, styles.noteActionDelete]}>Delete</Text>
                      </TouchableOpacity>
                    </View>
                  </Card>
                ))
              )}
            </View>
          )}

          {activeTab === 'checklist' && (
            <View>
              <TouchableOpacity
                style={styles.addButton}
                onPress={() => {
                  setEditNoteId(undefined);
                  setNoteSheetVisible(true);
                }}
              >
                <Text style={styles.addButtonText}>+ Add Checklist</Text>
              </TouchableOpacity>
              {filteredNotes.length === 0 ? (
                <EmptyState icon="✅" title="No checklists" subtitle="Add a checklist for this event" />
              ) : (
                filteredNotes.map((note) => (
                  <Card key={note.id} style={styles.noteCard}>
                    <Text style={styles.noteBody}>{note.body}</Text>
                    {note.checklistItems.map((item, idx) => {
                      const checked = item.startsWith('[x] ');
                      const display = checked ? item.slice(4) : item.startsWith('[ ] ') ? item.slice(4) : item;
                      return (
                        <TouchableOpacity
                          key={`${note.id}-${idx}`}
                          style={styles.checklistRow}
                          onPress={() => handleToggleChecklistItem(note.id, idx)}
                        >
                          <View style={[styles.checkbox, checked && styles.checkboxChecked]}>
                            {checked && <Text style={styles.checkmark}>✓</Text>}
                          </View>
                          <Text style={[styles.checklistText, checked && styles.checklistTextDone]}>
                            {display}
                          </Text>
                        </TouchableOpacity>
                      );
                    })}
                    <View style={styles.addItemRow}>
                      <TextInput
                        style={styles.addItemInput}
                        placeholder="Add item..."
                        placeholderTextColor={Colors.textTertiary}
                        value={newChecklistItem}
                        onChangeText={setNewChecklistItem}
                        onSubmitEditing={() => handleAddChecklistItem(note.id)}
                      />
                      <TouchableOpacity
                        style={styles.addItemBtn}
                        onPress={() => handleAddChecklistItem(note.id)}
                      >
                        <Text style={styles.addItemBtnText}>+</Text>
                      </TouchableOpacity>
                    </View>
                    <View style={styles.noteActions}>
                      <TouchableOpacity onPress={() => handleDeleteNote(note.id)}>
                        <Text style={[styles.noteAction, styles.noteActionDelete]}>Delete</Text>
                      </TouchableOpacity>
                    </View>
                  </Card>
                ))
              )}
            </View>
          )}

          {activeTab === 'links' && (
            <View>
              <TouchableOpacity
                style={styles.addButton}
                onPress={() => {
                  setEditNoteId(undefined);
                  setNoteSheetVisible(true);
                }}
              >
                <Text style={styles.addButtonText}>+ Add Link Note</Text>
              </TouchableOpacity>
              {filteredNotes.length === 0 ? (
                <EmptyState icon="🔗" title="No links" subtitle="Add useful links for this event" />
              ) : (
                filteredNotes.map((note) => (
                  <Card key={note.id} style={styles.noteCard}>
                    <Text style={styles.noteBody}>{note.body}</Text>
                    {note.links.map((link, idx) => (
                      <View key={`${note.id}-link-${idx}`} style={styles.linkRow}>
                        <TouchableOpacity
                          onPress={() => {
                            const { Linking } = require('react-native');
                            Linking.openURL(link.startsWith('http') ? link : `https://${link}`);
                          }}
                          style={{ flex: 1 }}
                        >
                          <Text style={styles.linkText} numberOfLines={1}>🔗 {link}</Text>
                        </TouchableOpacity>
                        <TouchableOpacity onPress={() => handleRemoveLink(note.id, idx)}>
                          <Text style={styles.linkRemove}>✕</Text>
                        </TouchableOpacity>
                      </View>
                    ))}
                    <View style={styles.addItemRow}>
                      <TextInput
                        style={styles.addItemInput}
                        placeholder="Add URL..."
                        placeholderTextColor={Colors.textTertiary}
                        value={newLinkUrl}
                        onChangeText={setNewLinkUrl}
                        autoCapitalize="none"
                        keyboardType="url"
                        onSubmitEditing={() => handleAddLink(note.id)}
                      />
                      <TouchableOpacity
                        style={styles.addItemBtn}
                        onPress={() => handleAddLink(note.id)}
                      >
                        <Text style={styles.addItemBtnText}>+</Text>
                      </TouchableOpacity>
                    </View>
                    <View style={styles.noteActions}>
                      <TouchableOpacity onPress={() => handleDeleteNote(note.id)}>
                        <Text style={[styles.noteAction, styles.noteActionDelete]}>Delete</Text>
                      </TouchableOpacity>
                    </View>
                  </Card>
                ))
              )}
            </View>
          )}
        </View>

        <View style={styles.notificationSection}>
          <Text style={styles.sectionTitle}>🔔 Notifications</Text>
          <View style={styles.switchRow}>
            <Text style={styles.switchLabel}>Enable Reminder</Text>
            <Switch
              value={notificationEnabled}
              onValueChange={setNotificationEnabled}
              trackColor={{ false: Colors.border, true: Colors.primaryLight }}
              thumbColor={notificationEnabled ? Colors.primary : Colors.textTertiary}
            />
          </View>
          {notificationEnabled && (
            <View style={styles.reminderRow}>
              <Text style={styles.switchLabel}>Minutes Before</Text>
              <TextInput
                style={styles.reminderInput}
                value={reminderMinutes}
                onChangeText={setReminderMinutes}
                keyboardType="number-pad"
                placeholder="30"
                placeholderTextColor={Colors.textTertiary}
              />
            </View>
          )}
          <TouchableOpacity style={styles.saveNotifBtn} onPress={handleSaveNotification}>
            <Text style={styles.saveNotifBtnText}>Save Notification Settings</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>

      <AddEventSheet
        visible={editSheetVisible}
        onClose={() => setEditSheetVisible(false)}
        eventId={eventId}
        onSave={async (eventData) => {
          if (!db) return;
          const now = new Date().toISOString();
          await db.runAsync(
            `UPDATE calendar_events SET title = ?, start_date = ?, end_date = ?, is_all_day = ?, location = ?, notes = ?, category = ?, is_outdoor = ?, notification_enabled = ?, reminder_minutes_before = ?, updated_at = ?
             WHERE id = ?`,
            eventData.title, eventData.startDate, eventData.endDate,
            eventData.isAllDay ? 1 : 0, eventData.location ?? null, eventData.notes ?? null,
            eventData.category ?? null, eventData.isOutdoor ? 1 : 0,
            eventData.notificationEnabled ? 1 : 0, eventData.reminderMinutesBefore,
            now, eventId
          );
          const updated: CalendarEvent = { ...event, ...eventData, id: eventId, updatedAt: now };
          updateEventInStore(updated);
        }}
      />

      <EventNoteSheet
        visible={noteSheetVisible}
        onClose={() => {
          setNoteSheetVisible(false);
          setEditNoteId(undefined);
        }}
        eventId={eventId}
        noteId={editNoteId}
        onSave={() => loadNotes()}
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
  header: {
    paddingVertical: Spacing.xl,
  },
  title: {
    fontSize: FontSize.title,
    fontWeight: '700',
    color: Colors.text,
    marginBottom: Spacing.sm,
  },
  dateTime: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
    marginBottom: Spacing.xs,
  },
  location: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
    marginBottom: Spacing.xs,
  },
  outdoorBadge: {
    backgroundColor: '#E8F5E9',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.xs,
    borderRadius: BorderRadius.sm,
    alignSelf: 'flex-start',
    marginTop: Spacing.sm,
  },
  outdoorBadgeText: {
    fontSize: FontSize.sm,
    color: '#2E7D32',
    fontWeight: '600',
  },
  categoryBadge: {
    backgroundColor: Colors.primaryLight + '30',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.xs,
    borderRadius: BorderRadius.sm,
    alignSelf: 'flex-start',
    marginTop: Spacing.sm,
  },
  categoryBadgeText: {
    fontSize: FontSize.sm,
    color: Colors.primary,
    fontWeight: '600',
  },
  actionButtons: {
    flexDirection: 'row',
    gap: Spacing.md,
    marginBottom: Spacing.xl,
  },
  actionBtn: {
    flex: 1,
    paddingVertical: Spacing.md,
    borderRadius: BorderRadius.md,
    backgroundColor: Colors.surface,
    alignItems: 'center',
    ...Shadow.sm,
  },
  actionBtnText: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.primary,
  },
  deleteBtn: {
    backgroundColor: '#FFF5F5',
  },
  deleteBtnText: {
    color: Colors.error,
  },
  tabBar: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
    marginBottom: Spacing.lg,
  },
  tab: {
    flex: 1,
    paddingVertical: Spacing.md,
    alignItems: 'center',
  },
  tabActive: {
    borderBottomWidth: 2,
    borderBottomColor: Colors.primary,
  },
  tabText: {
    fontSize: FontSize.sm,
    color: Colors.textSecondary,
    fontWeight: '500',
  },
  tabTextActive: {
    color: Colors.primary,
    fontWeight: '700',
  },
  tabContent: {
    minHeight: 200,
  },
  addButton: {
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
    borderRadius: BorderRadius.md,
    backgroundColor: Colors.surface,
    alignItems: 'center',
    marginBottom: Spacing.md,
  },
  addButtonText: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.primary,
  },
  aiButton: {
    backgroundColor: '#F0E6FF',
  },
  aiButtonText: {
    color: '#7C3AED',
  },
  buttonDisabled: {
    opacity: 0.5,
  },
  noteCard: {
    marginBottom: Spacing.sm,
  },
  noteBody: {
    fontSize: FontSize.md,
    color: Colors.text,
    lineHeight: 22,
    marginBottom: Spacing.sm,
  },
  noteTime: {
    fontSize: FontSize.xs,
    color: Colors.textTertiary,
    marginBottom: Spacing.sm,
  },
  noteActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: Spacing.lg,
  },
  noteAction: {
    fontSize: FontSize.sm,
    color: Colors.info,
    fontWeight: '500',
  },
  noteActionDelete: {
    color: Colors.error,
  },
  checklistRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Spacing.sm,
  },
  checkbox: {
    width: 22,
    height: 22,
    borderRadius: BorderRadius.sm,
    borderWidth: 2,
    borderColor: Colors.border,
    marginRight: Spacing.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  checkboxChecked: {
    backgroundColor: Colors.success,
    borderColor: Colors.success,
  },
  checkmark: {
    color: '#FFFFFF',
    fontSize: FontSize.xs,
    fontWeight: '700',
  },
  checklistText: {
    fontSize: FontSize.md,
    color: Colors.text,
    flex: 1,
  },
  checklistTextDone: {
    textDecorationLine: 'line-through',
    color: Colors.textSecondary,
  },
  addItemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: Spacing.sm,
    gap: Spacing.sm,
  },
  addItemInput: {
    flex: 1,
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: BorderRadius.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    fontSize: FontSize.sm,
    color: Colors.text,
  },
  addItemBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.primary,
    justifyContent: 'center',
    alignItems: 'center',
  },
  addItemBtnText: {
    color: '#FFFFFF',
    fontSize: FontSize.lg,
    fontWeight: '600',
  },
  linkRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  linkText: {
    fontSize: FontSize.sm,
    color: Colors.info,
  },
  linkRemove: {
    fontSize: FontSize.sm,
    color: Colors.error,
    padding: Spacing.sm,
    fontWeight: '700',
  },
  notificationSection: {
    marginTop: Spacing.xxl,
    backgroundColor: Colors.card,
    borderRadius: BorderRadius.lg,
    padding: Spacing.lg,
    ...Shadow.sm,
  },
  sectionTitle: {
    fontSize: FontSize.lg,
    fontWeight: '700',
    color: Colors.text,
    marginBottom: Spacing.lg,
  },
  switchRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.sm,
  },
  switchLabel: {
    fontSize: FontSize.md,
    color: Colors.text,
  },
  reminderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.sm,
  },
  reminderInput: {
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: BorderRadius.sm,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.xs,
    fontSize: FontSize.md,
    color: Colors.text,
    width: 80,
    textAlign: 'center',
  },
  saveNotifBtn: {
    marginTop: Spacing.lg,
    paddingVertical: Spacing.md,
    borderRadius: BorderRadius.md,
    backgroundColor: Colors.primary,
    alignItems: 'center',
  },
  saveNotifBtnText: {
    color: '#FFFFFF',
    fontSize: FontSize.md,
    fontWeight: '600',
  },
  notFoundText: {
    fontSize: FontSize.lg,
    color: Colors.textSecondary,
    marginBottom: Spacing.lg,
  },
  backButton: {
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xxxl,
    backgroundColor: Colors.primary,
    borderRadius: BorderRadius.md,
  },
  backButtonText: {
    color: '#FFFFFF',
    fontSize: FontSize.md,
    fontWeight: '600',
  },
});
