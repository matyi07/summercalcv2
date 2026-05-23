import * as SQLite from 'expo-sqlite';
import { EventNote, EventNoteType } from '../models';
import { v4 as uuidv4 } from 'uuid';

export class EventNoteService {
  async fetchNotesByEventId(db: SQLite.SQLiteDatabase, eventId: string): Promise<EventNote[]> {
    const rows = await db.getAllAsync<any>(
      'SELECT * FROM event_notes WHERE event_id = ? ORDER BY created_at DESC',
      eventId
    );
    return rows.map(row => this.mapNote(row));
  }

  async addNote(
    db: SQLite.SQLiteDatabase,
    eventId: string,
    body: string,
    noteType: EventNoteType = EventNoteType.general,
    checklistItems: string[] = [],
    links: string[] = []
  ): Promise<EventNote> {
    const id = uuidv4();
    const now = new Date().toISOString();
    const checklistJson = JSON.stringify(checklistItems);
    const linksJson = JSON.stringify(links);

    await db.runAsync(
      `INSERT INTO event_notes (id, event_id, body, note_type, checklist_items, links, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      id, eventId, body, noteType, checklistJson, linksJson, now, now
    );

    return {
      id,
      eventId,
      body,
      noteType,
      checklistItems,
      links,
      createdAt: now,
      updatedAt: now,
    };
  }

  async updateNote(
    db: SQLite.SQLiteDatabase,
    noteId: string,
    updates: { body?: string; noteType?: EventNoteType }
  ): Promise<void> {
    const now = new Date().toISOString();
    const fields: string[] = [];
    const values: any[] = [];

    if (updates.body !== undefined) {
      fields.push('body = ?');
      values.push(updates.body);
    }
    if (updates.noteType !== undefined) {
      fields.push('note_type = ?');
      values.push(updates.noteType);
    }

    if (fields.length === 0) return;

    fields.push('updated_at = ?');
    values.push(now);
    values.push(noteId);

    await db.runAsync(
      `UPDATE event_notes SET ${fields.join(', ')} WHERE id = ?`,
      ...values
    );
  }

  async deleteNote(db: SQLite.SQLiteDatabase, noteId: string): Promise<void> {
    await db.runAsync('DELETE FROM event_notes WHERE id = ?', noteId);
  }

  async addChecklistItem(
    db: SQLite.SQLiteDatabase,
    noteId: string,
    item: string
  ): Promise<string[]> {
    const row = await db.getFirstAsync<any>(
      'SELECT checklist_items FROM event_notes WHERE id = ?',
      noteId
    );
    if (!row) throw new Error(`Note ${noteId} not found`);

    const items: string[] = JSON.parse(row.checklist_items ?? '[]');
    items.push(item);
    const json = JSON.stringify(items);
    const now = new Date().toISOString();

    await db.runAsync(
      'UPDATE event_notes SET checklist_items = ?, updated_at = ? WHERE id = ?',
      json, now, noteId
    );

    return items;
  }

  async toggleChecklistItem(
    db: SQLite.SQLiteDatabase,
    noteId: string,
    index: number
  ): Promise<string[]> {
    const row = await db.getFirstAsync<any>(
      'SELECT checklist_items FROM event_notes WHERE id = ?',
      noteId
    );
    if (!row) throw new Error(`Note ${noteId} not found`);

    const items: string[] = JSON.parse(row.checklist_items ?? '[]');
    if (index >= 0 && index < items.length) {
      const item = items[index];
      if (item.startsWith('[x] ')) {
        items[index] = item.slice(4);
      } else if (item.startsWith('[ ] ')) {
        items[index] = '[x] ' + item.slice(4);
      } else {
        items[index] = '[x] ' + item;
      }
    }
    const json = JSON.stringify(items);
    const now = new Date().toISOString();

    await db.runAsync(
      'UPDATE event_notes SET checklist_items = ?, updated_at = ? WHERE id = ?',
      json, now, noteId
    );

    return items;
  }

  async addLink(
    db: SQLite.SQLiteDatabase,
    noteId: string,
    link: string
  ): Promise<string[]> {
    const row = await db.getFirstAsync<any>(
      'SELECT links FROM event_notes WHERE id = ?',
      noteId
    );
    if (!row) throw new Error(`Note ${noteId} not found`);

    const links: string[] = JSON.parse(row.links ?? '[]');
    links.push(link);
    const json = JSON.stringify(links);
    const now = new Date().toISOString();

    await db.runAsync(
      'UPDATE event_notes SET links = ?, updated_at = ? WHERE id = ?',
      json, now, noteId
    );

    return links;
  }

  async removeLink(
    db: SQLite.SQLiteDatabase,
    noteId: string,
    index: number
  ): Promise<string[]> {
    const row = await db.getFirstAsync<any>(
      'SELECT links FROM event_notes WHERE id = ?',
      noteId
    );
    if (!row) throw new Error(`Note ${noteId} not found`);

    const links: string[] = JSON.parse(row.links ?? '[]');
    if (index >= 0 && index < links.length) {
      links.splice(index, 1);
    }
    const json = JSON.stringify(links);
    const now = new Date().toISOString();

    await db.runAsync(
      'UPDATE event_notes SET links = ?, updated_at = ? WHERE id = ?',
      json, now, noteId
    );

    return links;
  }

  private mapNote(row: any): EventNote {
    return {
      id: row.id,
      eventId: row.event_id,
      body: row.body,
      noteType: (row.note_type as EventNoteType) ?? EventNoteType.general,
      checklistItems: this.parseJsonArray(row.checklist_items),
      links: this.parseJsonArray(row.links),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  private parseJsonArray(value: string | null | undefined): string[] {
    if (!value) return [];
    try {
      return JSON.parse(value);
    } catch {
      return [];
    }
  }
}
