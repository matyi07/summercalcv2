import * as SQLite from 'expo-sqlite';
import { CREATE_TABLES } from './schema';
import { SMART_NOTIFICATION_RULES, DEFAULT_USER_SETTINGS } from '../models';
import { v4 as uuidv4 } from 'uuid';

let db: SQLite.SQLiteDatabase | null = null;

export async function getDatabase(): Promise<SQLite.SQLiteDatabase> {
  if (db) return db;
  db = await SQLite.openDatabaseAsync('summercal.db', {
    useNewConnection: true,
  });
  await initializeDatabase(db);
  return db;
}

async function initializeDatabase(database: SQLite.SQLiteDatabase): Promise<void> {
  await database.execAsync(CREATE_TABLES);
  await seedDefaultData(database);
}

async function seedDefaultData(database: SQLite.SQLiteDatabase): Promise<void> {
  // Seed user settings if not present
  const existingSettings = await database.getFirstAsync<{ id: string }>(
    'SELECT id FROM user_settings WHERE id = ?', 'default'
  );
  if (!existingSettings) {
    const s = DEFAULT_USER_SETTINGS;
    await database.runAsync(
      `INSERT INTO user_settings (id, ai_provider_kind, ai_model_name, ai_base_url, ai_max_tokens,
       free_day_threshold_hours, free_day_check_hour, free_day_check_minute, rain_threshold,
       heat_threshold_celsius, cold_threshold_celsius, daily_weather_summary_enabled,
       weather_alerts_enabled, quiet_hours_start, quiet_hours_end, max_smart_notifications_per_day,
       next_day_free_preview_enabled, monthly_income_goal, currency_code, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      s.id, s.aiProviderKind, s.aiModelName, s.aiBaseURL ?? null, s.aiMaxTokens,
      s.freeDayThresholdHours, s.freeDayCheckHour, s.freeDayCheckMinute, s.rainThreshold,
      s.heatThresholdCelsius, s.coldThresholdCelsius, s.dailyWeatherSummaryEnabled ? 1 : 0,
      s.weatherAlertsEnabled ? 1 : 0, s.quietHoursStart, s.quietHoursEnd, s.maxSmartNotificationsPerDay,
      s.nextDayFreePreviewEnabled ? 1 : 0, s.monthlyIncomeGoal ?? null, s.currencyCode,
      s.createdAt, s.updatedAt
    );
  }

  // Seed notification rules if not present
  const existingRules = await database.getFirstAsync<{ cnt: number }>(
    'SELECT COUNT(*) as cnt FROM smart_notification_rules'
  );
  if (existingRules && existingRules.cnt === 0) {
    for (const rule of SMART_NOTIFICATION_RULES) {
      await database.runAsync(
        `INSERT OR IGNORE INTO smart_notification_rules (id, kind, is_enabled, preferred_hour, preferred_minute,
         quiet_hours_start, quiet_hours_end, max_per_day, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        rule.id, rule.kind, rule.isEnabled ? 1 : 0, rule.preferredHour, rule.preferredMinute,
        rule.quietHoursStart, rule.quietHoursEnd, rule.maxPerDay,
        rule.createdAt, rule.updatedAt
      );
    }
  }
}

export function mapRowToObject<T>(row: any): T {
  // Convert snake_case DB columns to camelCase TS properties
  const result: any = {};
  for (const key of Object.keys(row)) {
    const camelKey = key.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
    let value = row[key];
    // Convert integer booleans
    if (typeof value === 'number' && (camelKey.startsWith('is') || camelKey.includes('Enabled'))) {
      value = value === 1;
    }
    result[camelKey] = value;
  }
  return result as T;
}
