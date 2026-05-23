import { useCallback, useEffect, useState } from 'react';
import { useDatabase } from './useDatabase';

export interface UserSettings {
  id: number;
  city: string;
  currency: string;
  costPreference: number;
  notificationsEnabled: boolean;
  darkMode: boolean;
  preferredCategories: string;
  monthlyGoal: number;
}

const DEFAULT_SETTINGS: UserSettings = {
  id: 1,
  city: '',
  currency: 'USD',
  costPreference: 2,
  notificationsEnabled: true,
  darkMode: false,
  preferredCategories: '',
  monthlyGoal: 0,
};

export function useSettings() {
  const { db, ready } = useDatabase();
  const [settings, setSettings] = useState<UserSettings | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!ready || !db) return;

    (async () => {
      try {
        await db.execAsync(
          `CREATE TABLE IF NOT EXISTS settings (
            id INTEGER PRIMARY KEY,
            city TEXT NOT NULL DEFAULT '',
            currency TEXT NOT NULL DEFAULT 'USD',
            costPreference INTEGER NOT NULL DEFAULT 2,
            notificationsEnabled INTEGER NOT NULL DEFAULT 1,
            darkMode INTEGER NOT NULL DEFAULT 0,
            preferredCategories TEXT NOT NULL DEFAULT '',
            monthlyGoal REAL NOT NULL DEFAULT 0
          );`
        );

        const existing = await db.getFirstAsync<UserSettings>(
          'SELECT * FROM settings WHERE id = 1'
        );

        if (!existing) {
          await db.runAsync(
            `INSERT INTO settings (id, city, currency, costPreference, notificationsEnabled, darkMode, preferredCategories, monthlyGoal)
             VALUES (1, '', 'USD', 2, 1, 0, '', 0);`
          );
          setSettings(DEFAULT_SETTINGS);
        } else {
          setSettings(existing);
        }
      } catch (err) {
        console.error('useSettings init error:', err);
      } finally {
        setLoading(false);
      }
    })();
  }, [db, ready]);

  const updateSetting = useCallback(
    async (key: keyof UserSettings, value: UserSettings[typeof key]) => {
      if (!db) return;

      try {
        const dbValue = typeof value === 'boolean' ? (value ? 1 : 0) : value;
        await db.runAsync(
          `UPDATE settings SET ${key} = ? WHERE id = 1;`,
          [dbValue as string | number]
        );

        setSettings(prev => {
          if (!prev) return prev;
          return { ...prev, [key]: value };
        });
      } catch (err) {
        console.error('useSettings update error:', err);
      }
    },
    [db]
  );

  return { settings, updateSetting, loading };
}
