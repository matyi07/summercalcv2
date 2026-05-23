// SQLite table creation statements for expo-sqlite
export const CREATE_TABLES = `
CREATE TABLE IF NOT EXISTS calendar_events (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  is_all_day INTEGER DEFAULT 0,
  location TEXT,
  notes TEXT,
  category TEXT,
  is_outdoor INTEGER DEFAULT 0,
  recurrence_rule TEXT,
  notification_enabled INTEGER DEFAULT 1,
  reminder_minutes_before INTEGER DEFAULT 30,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS event_notes (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  body TEXT NOT NULL,
  note_type TEXT DEFAULT 'general',
  checklist_items TEXT DEFAULT '[]',
  links TEXT DEFAULT '[]',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (event_id) REFERENCES calendar_events(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS event_reminders (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  reminder_date TEXT NOT NULL,
  is_completed INTEGER DEFAULT 0,
  is_snoozed INTEGER DEFAULT 0,
  snoozed_until TEXT,
  notification_id TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (event_id) REFERENCES calendar_events(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS smart_notification_rules (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL UNIQUE,
  is_enabled INTEGER DEFAULT 1,
  preferred_hour INTEGER DEFAULT 9,
  preferred_minute INTEGER DEFAULT 0,
  quiet_hours_start INTEGER DEFAULT 22,
  quiet_hours_end INTEGER DEFAULT 8,
  max_per_day INTEGER DEFAULT 2,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS notification_logs (
  id TEXT PRIMARY KEY,
  notification_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  scheduled_for TEXT NOT NULL,
  delivered_estimate TEXT,
  related_event_id TEXT,
  related_suggestion_id TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS activity_suggestions (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  category TEXT NOT NULL,
  estimated_duration_minutes INTEGER DEFAULT 60,
  estimated_cost_level INTEGER DEFAULT 0,
  place_name TEXT,
  place_id TEXT,
  weather_reason TEXT,
  ai_provider TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS weather_snapshots (
  id TEXT PRIMARY KEY,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  fetched_at TEXT NOT NULL,
  forecast_date TEXT NOT NULL,
  condition TEXT NOT NULL,
  temperature_celsius REAL NOT NULL,
  precipitation_chance REAL DEFAULT 0,
  wind_speed_kph REAL,
  summary TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS place_candidates (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  address TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  open_now INTEGER,
  rating REAL,
  place_id TEXT NOT NULL,
  distance_meters REAL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS income_entries (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL,
  amount REAL NOT NULL,
  source TEXT NOT NULL,
  description_text TEXT DEFAULT '',
  category TEXT DEFAULT 'other',
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS work_sessions (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  hourly_rate REAL NOT NULL,
  total_earned REAL NOT NULL,
  description_text TEXT DEFAULT '',
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS user_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  ai_provider_kind TEXT DEFAULT 'openAI',
  ai_model_name TEXT DEFAULT 'gpt-4o',
  ai_base_url TEXT,
  ai_max_tokens INTEGER DEFAULT 1024,
  free_day_threshold_hours REAL DEFAULT 4.0,
  free_day_check_hour INTEGER DEFAULT 9,
  free_day_check_minute INTEGER DEFAULT 0,
  rain_threshold REAL DEFAULT 0.5,
  heat_threshold_celsius REAL DEFAULT 35,
  cold_threshold_celsius REAL DEFAULT 0,
  daily_weather_summary_enabled INTEGER DEFAULT 1,
  weather_alerts_enabled INTEGER DEFAULT 1,
  quiet_hours_start INTEGER DEFAULT 22,
  quiet_hours_end INTEGER DEFAULT 8,
  max_smart_notifications_per_day INTEGER DEFAULT 2,
  next_day_free_preview_enabled INTEGER DEFAULT 0,
  monthly_income_goal REAL,
  currency_code TEXT DEFAULT 'USD',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
`;
