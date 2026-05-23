// ============ Enums ============
export enum EventNoteType { general = 'general', prep = 'prep', checklist = 'checklist', link = 'link', postEvent = 'postEvent', aiSummary = 'aiSummary' }
export enum SmartNotificationKind { upcomingEvent = 'upcomingEvent', freeDay = 'freeDay', freeAfternoon = 'freeAfternoon', weatherSummary = 'weatherSummary', weatherAlert = 'weatherAlert', eventPrep = 'eventPrep', moneyReminder = 'moneyReminder' }
export enum IncomeCategory { salary = 'salary', freelance = 'freelance', gig = 'gig', other = 'other' }
export enum AIProviderKind { openAI = 'openAI', claude = 'claude', deepSeek = 'deepSeek', openAICompatible = 'openAICompatible' }

// ============ Interfaces ============
export interface CalendarEvent {
  id: string
  title: string
  startDate: string
  endDate: string
  isAllDay: boolean
  location?: string
  notes?: string
  category?: string
  isOutdoor: boolean
  recurrenceRule?: string
  notificationEnabled: boolean
  reminderMinutesBefore: number
  createdAt: string
  updatedAt: string
}

export interface EventNote {
  id: string
  eventId: string
  body: string
  noteType: EventNoteType
  checklistItems: string[]
  links: string[]
  createdAt: string
  updatedAt: string
}

export interface EventReminder {
  id: string
  eventId: string
  reminderDate: string
  isCompleted: boolean
  isSnoozed: boolean
  snoozedUntil?: string
  notificationId?: string
  createdAt: string
}

export interface SmartNotificationRule {
  id: string
  kind: SmartNotificationKind
  isEnabled: boolean
  preferredHour: number
  preferredMinute: number
  quietHoursStart: number
  quietHoursEnd: number
  maxPerDay: number
  createdAt: string
  updatedAt: string
}

export interface NotificationLog {
  id: string
  notificationId: string
  kind: SmartNotificationKind
  title: string
  body: string
  scheduledFor: string
  deliveredEstimate?: string
  relatedEventId?: string
  relatedSuggestionId?: string
  createdAt: string
}

export interface ActivitySuggestion {
  id: string
  date: string
  title: string
  summary: string
  category: string
  estimatedDurationMinutes: number
  estimatedCostLevel: number
  placeName?: string
  placeId?: string
  weatherReason?: string
  aiProvider?: string
  createdAt: string
}

export interface WeatherSnapshot {
  id: string
  latitude: number
  longitude: number
  fetchedAt: string
  forecastDate: string
  condition: string
  temperatureCelsius: number
  precipitationChance: number
  windSpeedKph?: number
  summary: string
}

export interface PlaceCandidate {
  id: string
  name: string
  category: string
  address: string
  latitude: number
  longitude: number
  openNow?: boolean
  rating?: number
  placeId: string
  distanceMeters: number
  createdAt: string
}

export interface IncomeEntry {
  id: string
  date: string
  amount: number
  source: string
  descriptionText: string
  category: IncomeCategory
  createdAt: string
}

export interface WorkSession {
  id: string
  date: string
  startTime: string
  endTime: string
  hourlyRate: number
  totalEarned: number
  descriptionText: string
  createdAt: string
}

export interface UserSettings {
  id: string
  aiProviderKind: string
  aiModelName: string
  aiBaseURL?: string
  aiMaxTokens: number
  freeDayThresholdHours: number
  freeDayCheckHour: number
  freeDayCheckMinute: number
  rainThreshold: number
  heatThresholdCelsius: number
  coldThresholdCelsius: number
  dailyWeatherSummaryEnabled: boolean
  weatherAlertsEnabled: boolean
  quietHoursStart: number
  quietHoursEnd: number
  maxSmartNotificationsPerDay: number
  nextDayFreePreviewEnabled: boolean
  monthlyIncomeGoal?: number
  currencyCode: string
  createdAt: string
  updatedAt: string
}

// ============ DTOs ============
export interface AIMessage { role: 'system' | 'user' | 'assistant'; content: string }
export interface AIRequestConfig { model: string; maxTokens: number; temperature: number; baseURL?: string }
export interface AIResponse { content: string; finishReason?: string; tokenUsage?: number }

export interface AIPlannerRequest {
  date: string
  freeWindows: { start: string; end: string }[]
  eventsSummary: string
  weatherSummary: string
  locationSummary: string
  nearbyPlaces: PlaceCandidate[]
  userPreferences: string[]
  budgetPreference?: string
  energyLevel?: string
}

export interface AIPlannerResponse {
  daySummary: string
  suggestions: ActivitySuggestion[]
  recommendedPlan: string
  notificationTitle: string
  notificationBody: string
  reasons: string[]
}

export interface ChatMessage {
  id: string
  role: 'user' | 'assistant' | 'system'
  content: string
  timestamp: string
}

export const DEFAULT_USER_SETTINGS: UserSettings = {
  id: 'default',
  aiProviderKind: 'openAI',
  aiModelName: 'gpt-4o',
  aiBaseURL: undefined,
  aiMaxTokens: 1024,
  freeDayThresholdHours: 4,
  freeDayCheckHour: 9,
  freeDayCheckMinute: 0,
  rainThreshold: 0.5,
  heatThresholdCelsius: 35,
  coldThresholdCelsius: 0,
  dailyWeatherSummaryEnabled: true,
  weatherAlertsEnabled: true,
  quietHoursStart: 22,
  quietHoursEnd: 8,
  maxSmartNotificationsPerDay: 2,
  nextDayFreePreviewEnabled: false,
  monthlyIncomeGoal: undefined,
  currencyCode: 'USD',
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
}

export const SMART_NOTIFICATION_RULES: SmartNotificationRule[] = [
  { id: 'rule_upcoming', kind: SmartNotificationKind.upcomingEvent, isEnabled: true, preferredHour: 0, preferredMinute: 0, quietHoursStart: 22, quietHoursEnd: 8, maxPerDay: 5, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() },
  { id: 'rule_free_day', kind: SmartNotificationKind.freeDay, isEnabled: true, preferredHour: 9, preferredMinute: 0, quietHoursStart: 22, quietHoursEnd: 8, maxPerDay: 1, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() },
  { id: 'rule_free_afternoon', kind: SmartNotificationKind.freeAfternoon, isEnabled: true, preferredHour: 11, preferredMinute: 0, quietHoursStart: 22, quietHoursEnd: 8, maxPerDay: 1, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() },
  { id: 'rule_weather_summary', kind: SmartNotificationKind.weatherSummary, isEnabled: true, preferredHour: 7, preferredMinute: 30, quietHoursStart: 22, quietHoursEnd: 8, maxPerDay: 1, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() },
  { id: 'rule_weather_alert', kind: SmartNotificationKind.weatherAlert, isEnabled: true, preferredHour: 0, preferredMinute: 0, quietHoursStart: 22, quietHoursEnd: 8, maxPerDay: 3, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() },
  { id: 'rule_event_prep', kind: SmartNotificationKind.eventPrep, isEnabled: true, preferredHour: 0, preferredMinute: 0, quietHoursStart: 22, quietHoursEnd: 8, maxPerDay: 3, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() },
  { id: 'rule_money', kind: SmartNotificationKind.moneyReminder, isEnabled: true, preferredHour: 19, preferredMinute: 0, quietHoursStart: 22, quietHoursEnd: 8, maxPerDay: 1, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() },
]
