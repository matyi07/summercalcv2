import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  ScrollView,
  TouchableOpacity,
  TextInput,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { v4 as uuidv4 } from 'uuid';
import { Colors, Spacing, FontSize, BorderRadius } from '../constants/theme';
import { useDatabase } from '../hooks/useDatabase';
import { EventNote, EventNoteType } from '../models';
import { EventNoteService } from '../services/EventNoteService';

interface EventNoteSheetProps {
  visible: boolean;
  onClose: () => void;
  eventId: string;
  noteId?: string;
  onSave?: () => void;
}

const NOTE_TYPES: { key: EventNoteType; label: string }[] = [
  { key: EventNoteType.general, label: '📋 General' },
  { key: EventNoteType.prep, label: '🎯 Prep' },
  { key: EventNoteType.checklist, label: '✅ Checklist' },
  { key: EventNoteType.link, label: '🔗 Link' },
  { key: EventNoteType.postEvent, label: '📝 Post-Event' },
];

const eventNoteService = new EventNoteService();

function parseJsonArray(value: string | null | undefined): string[] {
  if (!value) return [];
  try {
    return JSON.parse(value);
  } catch {
    return [];
  }
}

export function EventNoteSheet({ visible, onClose, eventId, noteId, onSave }: EventNoteSheetProps) {
  const insets = useSafeAreaInsets();
  const { db } = useDatabase();

  const [noteType, setNoteType] = useState<EventNoteType>(EventNoteType.general);
  const [body, setBody] = useState('');
  const [checklistItems, setChecklistItems] = useState<string[]>([]);
  const [links, setLinks] = useState<string[]>([]);
  const [newChecklistInput, setNewChecklistInput] = useState('');
  const [newLinkInput, setNewLinkInput] = useState('');

  const isEditing = !!noteId;

  useEffect(() => {
    if (!visible) return;

    if (noteId) {
      loadExistingNote(noteId);
    } else {
      resetForm();
    }
  }, [visible, noteId]);

  const loadExistingNote = async (id: string) => {
    if (!db) return;

    const row = await db.getFirstAsync<any>(
      'SELECT * FROM event_notes WHERE id = ?',
      id
    );

    if (row) {
      setNoteType((row.note_type as EventNoteType) ?? EventNoteType.general);
      setBody(row.body ?? '');
      setChecklistItems(parseJsonArray(row.checklist_items));
      setLinks(parseJsonArray(row.links));
    }
  };

  const resetForm = () => {
    setNoteType(EventNoteType.general);
    setBody('');
    setChecklistItems([]);
    setLinks([]);
    setNewChecklistInput('');
    setNewLinkInput('');
  };

  const handleSave = async () => {
    if (!db || !body.trim()) return;

    if (isEditing && noteId) {
      const now = new Date().toISOString();

      await db.runAsync(
        `UPDATE event_notes SET body = ?, note_type = ?, checklist_items = ?, links = ?, updated_at = ? WHERE id = ?`,
        body.trim(),
        noteType,
        JSON.stringify(checklistItems),
        JSON.stringify(links),
        now,
        noteId
      );
    } else {
      await eventNoteService.addNote(db, eventId, body.trim(), noteType, checklistItems, links);
    }

    onSave?.();
    onClose();
  };

  const addChecklistItem = () => {
    if (!newChecklistInput.trim()) return;
    setChecklistItems((prev) => [...prev, newChecklistInput.trim()]);
    setNewChecklistInput('');
  };

  const removeChecklistItem = (index: number) => {
    setChecklistItems((prev) => prev.filter((_, i) => i !== index));
  };

  const addLink = () => {
    if (!newLinkInput.trim()) return;
    setLinks((prev) => [...prev, newLinkInput.trim()]);
    setNewLinkInput('');
  };

  const removeLink = (index: number) => {
    setLinks((prev) => prev.filter((_, i) => i !== index));
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
          <Text style={styles.headerTitle}>{isEditing ? 'Edit Note' : 'New Note'}</Text>
          <TouchableOpacity onPress={handleSave}>
            <Text style={[
              styles.saveText,
              !body.trim() && { opacity: 0.5 }
            ]}>Save</Text>
          </TouchableOpacity>
        </View>

        <ScrollView
          contentContainerStyle={styles.formContent}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <Text style={styles.fieldLabel}>Note Type</Text>
          <View style={styles.typeRow}>
            {NOTE_TYPES.map((t) => (
              <TouchableOpacity
                key={t.key}
                style={[
                  styles.typeChip,
                  noteType === t.key && styles.typeChipActive,
                ]}
                onPress={() => setNoteType(t.key)}
              >
                <Text
                  style={[
                    styles.typeChipText,
                    noteType === t.key && styles.typeChipTextActive,
                  ]}
                >
                  {t.label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          <Text style={styles.fieldLabel}>Content</Text>
          <TextInput
            style={[styles.textInput, styles.textArea]}
            value={body}
            onChangeText={setBody}
            placeholder={
              noteType === EventNoteType.checklist ? 'Checklist title...' :
              noteType === EventNoteType.link ? 'Link note title...' :
              'Write your note...'
            }
            placeholderTextColor={Colors.textTertiary}
            multiline
            numberOfLines={4}
            textAlignVertical="top"
            autoFocus
          />

          {noteType === EventNoteType.checklist && (
            <View style={styles.subSection}>
              <Text style={styles.fieldLabel}>Checklist Items</Text>
              {checklistItems.map((item, idx) => (
                <View key={`cl-${idx}`} style={styles.listItemRow}>
                  <View style={styles.listItemBullet}>
                    <Text style={styles.listItemBulletText}>{idx + 1}</Text>
                  </View>
                  <Text style={styles.listItemText}>{item}</Text>
                  <TouchableOpacity onPress={() => removeChecklistItem(idx)}>
                    <Text style={styles.removeText}>✕</Text>
                  </TouchableOpacity>
                </View>
              ))}
              <View style={styles.addRow}>
                <TextInput
                  style={[styles.textInput, styles.addInput]}
                  value={newChecklistInput}
                  onChangeText={setNewChecklistInput}
                  placeholder="Add checklist item..."
                  placeholderTextColor={Colors.textTertiary}
                  onSubmitEditing={addChecklistItem}
                />
                <TouchableOpacity style={styles.addBtn} onPress={addChecklistItem}>
                  <Text style={styles.addBtnText}>+</Text>
                </TouchableOpacity>
              </View>
            </View>
          )}

          {noteType === EventNoteType.link && (
            <View style={styles.subSection}>
              <Text style={styles.fieldLabel}>URLs</Text>
              {links.map((link, idx) => (
                <View key={`lk-${idx}`} style={styles.listItemRow}>
                  <Text style={styles.linkIconText}>🔗</Text>
                  <Text style={styles.listItemText} numberOfLines={1}>{link}</Text>
                  <TouchableOpacity onPress={() => removeLink(idx)}>
                    <Text style={styles.removeText}>✕</Text>
                  </TouchableOpacity>
                </View>
              ))}
              <View style={styles.addRow}>
                <TextInput
                  style={[styles.textInput, styles.addInput]}
                  value={newLinkInput}
                  onChangeText={setNewLinkInput}
                  placeholder="Add URL..."
                  placeholderTextColor={Colors.textTertiary}
                  autoCapitalize="none"
                  keyboardType="url"
                  onSubmitEditing={addLink}
                />
                <TouchableOpacity style={styles.addBtn} onPress={addLink}>
                  <Text style={styles.addBtnText}>+</Text>
                </TouchableOpacity>
              </View>
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
    marginBottom: Spacing.sm,
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
    minHeight: 120,
    textAlignVertical: 'top',
  },
  typeRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.sm,
  },
  typeChip: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.full,
    borderWidth: 1,
    borderColor: Colors.border,
    backgroundColor: Colors.surface,
  },
  typeChipActive: {
    backgroundColor: Colors.primary,
    borderColor: Colors.primary,
  },
  typeChipText: {
    fontSize: FontSize.sm,
    color: Colors.textSecondary,
    fontWeight: '500',
  },
  typeChipTextActive: {
    color: '#FFFFFF',
  },
  subSection: {
    marginTop: Spacing.lg,
  },
  listItemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  listItemBullet: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: Colors.surface,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: Spacing.md,
  },
  listItemBulletText: {
    fontSize: FontSize.xs,
    fontWeight: '700',
    color: Colors.textSecondary,
  },
  linkIconText: {
    fontSize: FontSize.sm,
    marginRight: Spacing.md,
  },
  listItemText: {
    flex: 1,
    fontSize: FontSize.md,
    color: Colors.text,
  },
  removeText: {
    fontSize: FontSize.sm,
    color: Colors.error,
    padding: Spacing.sm,
    fontWeight: '700',
  },
  addRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: Spacing.sm,
    gap: Spacing.sm,
  },
  addInput: {
    flex: 1,
  },
  addBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: Colors.primary,
    justifyContent: 'center',
    alignItems: 'center',
  },
  addBtnText: {
    color: '#FFFFFF',
    fontSize: FontSize.xl,
    fontWeight: '600',
    lineHeight: FontSize.xl + 4,
  },
});
