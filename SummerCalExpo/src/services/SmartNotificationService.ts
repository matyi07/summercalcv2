import { CalendarEvent, WeatherSnapshot, SmartNotificationRule, SmartNotificationKind, ActivitySuggestion, NotificationLog, UserSettings } from '../models';
import { NotificationService } from './NotificationService';
import { FreeDayDetectionService } from './FreeDayDetectionService';
import { ActivitySuggestionService } from './ActivitySuggestionService';
import { WeatherService } from './WeatherService';
import * as SQLite from 'expo-sqlite';
import { v4 as uuidv4 } from 'uuid';

export class SmartNotificationService {
  private notificationService: NotificationService;
  private freeDayService: FreeDayDetectionService;
  private activityService: ActivitySuggestionService;
  private weatherService: WeatherService;

  constructor(
    notificationService?: NotificationService,
    freeDayService?: FreeDayDetectionService,
    activityService?: ActivitySuggestionService,
    weatherService?: WeatherService
  ) {
    this.notificationService = notificationService ?? new NotificationService();
    this.freeDayService = freeDayService ?? new FreeDayDetectionService();
    this.activityService = activityService ?? new ActivitySuggestionService();
    this.weatherService = weatherService ?? new WeatherService();
  }

  async runDailyPipeline(
    date: Date,
    db: SQLite.SQLiteDatabase,
    events: CalendarEvent[],
    settings: UserSettings,
    rules: SmartNotificationRule[],
    weather?: WeatherSnapshot
  ): Promise<NotificationLog[]> {
    const logs: NotificationLog[] = [];
    const now = new Date().toISOString();
    const nowHour = date.getHours();

    const todaySent = await this.todaySentCount(db, date);
    const maxTotal = settings.maxSmartNotificationsPerDay;

    if (todaySent >= maxTotal) {
      this.addQuietLog(date, 'global_limit', logs, now);
      return logs;
    }

    let remaining = maxTotal - todaySent;

    for (const rule of rules) {
      if (remaining <= 0) break;
      if (!rule.isEnabled) continue;
      if (rule.preferredHour !== 0 && nowHour < rule.preferredHour) continue;

      const inQuiet = this.isQuietHours(nowHour, rule.quietHoursStart, rule.quietHoursEnd);
      if (inQuiet) continue;

      const ruleCount = await this.todayRuleCount(db, rule.kind, date);
      if (ruleCount >= rule.maxPerDay) continue;

      switch (rule.kind) {
        case SmartNotificationKind.freeDay: {
          const freeWindows = this.freeDayService.freeWindows(date, events);
          const freeHours = freeWindows.reduce((s, w) => s + (w.end.getTime() - w.start.getTime()) / 3600000, 0);
          const threshold = settings.freeDayThresholdHours;

          if (freeHours >= threshold) {
            const notificationId = `smart_free_day_${date.toISOString().slice(0, 10)}`;
            const body = this.freeDayService.notificationBody(
              freeWindows,
              weather ? { precipitationChance: weather.precipitationChance, temperatureCelsius: weather.temperatureCelsius } : undefined
            );
            const scheduledDate = this.buildScheduleDate(date, rule.preferredHour, rule.preferredMinute);
            await this.notificationService.scheduleSmartNotification(
              notificationId, `Free afternoon — about ${Math.round(freeHours)} hours`, body, scheduledDate,
              { kind: SmartNotificationKind.freeDay }
            );
            logs.push(this.makeLog(notificationId, SmartNotificationKind.freeDay, `Free afternoon`, body, scheduledDate.toISOString(), now));
            remaining--;
          }
          break;
        }

        case SmartNotificationKind.freeAfternoon: {
          const freeWindows = this.freeDayService.freeWindows(date, events);
          const afternoonWindows = freeWindows.filter(w => w.start.getHours() >= 12 && w.start.getHours() < 17);
          const afternoonHours = afternoonWindows.reduce((s, w) => s + (w.end.getTime() - w.start.getTime()) / 3600000, 0);

          if (afternoonHours >= 2) {
            const notificationId = `smart_free_afternoon_${date.toISOString().slice(0, 10)}`;
            const body = `You have about ${Math.round(afternoonHours)} hours free this afternoon. ${weather ? `Weather: ${this.weatherService.generateWeatherSummary(weather)}` : ''}`;
            const scheduledDate = this.buildScheduleDate(date, rule.preferredHour, rule.preferredMinute);
            await this.notificationService.scheduleSmartNotification(
              notificationId, 'Free afternoon', body, scheduledDate,
              { kind: SmartNotificationKind.freeAfternoon }
            );
            logs.push(this.makeLog(notificationId, SmartNotificationKind.freeAfternoon, 'Free afternoon', body, scheduledDate.toISOString(), now));
            remaining--;
          }
          break;
        }

        case SmartNotificationKind.upcomingEvent: {
          const upcoming = events
            .filter(e => new Date(e.startDate) > date && new Date(e.startDate).getTime() - date.getTime() < 72 * 3600000)
            .sort((a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime());

          for (const event of upcoming.slice(0, 3)) {
            if (remaining <= 0) break;
            const notificationId = `smart_upcoming_${event.id}`;
            const timeUntil = Math.round((new Date(event.startDate).getTime() - date.getTime()) / 3600000);
            const body = `"${event.title}" ${event.location ? `at ${event.location} ` : ''}in ${timeUntil} hours`;
            const triggerDate = new Date(date);
            triggerDate.setHours(rule.preferredHour || 7, rule.preferredMinute || 0, 0, 0);
            await this.notificationService.scheduleSmartNotification(
              notificationId, 'Upcoming event', body, triggerDate,
              { kind: SmartNotificationKind.upcomingEvent, eventId: event.id }
            );
            logs.push(this.makeLog(notificationId, SmartNotificationKind.upcomingEvent, 'Upcoming event', body, triggerDate.toISOString(), now, event.id));
            remaining--;
          }
          break;
        }

        case SmartNotificationKind.weatherSummary: {
          if (!weather) break;
          const notificationId = `smart_weather_${date.toISOString().slice(0, 10)}`;
          const body = this.weatherService.generateWeatherSummary(weather);
          const scheduledDate = this.buildScheduleDate(date, rule.preferredHour, rule.preferredMinute);
          await this.notificationService.scheduleSmartNotification(
            notificationId, 'Weather today', body, scheduledDate,
            { kind: SmartNotificationKind.weatherSummary }
          );
          logs.push(this.makeLog(notificationId, SmartNotificationKind.weatherSummary, 'Weather today', body, scheduledDate.toISOString(), now));
          remaining--;
          break;
        }

        case SmartNotificationKind.weatherAlert: {
          if (!weather) break;
          let alertTitle = '';
          let alertBody = '';
          if (this.weatherService.shouldNotifyRain(weather, settings.rainThreshold)) {
            alertTitle = 'Rain alert';
            alertBody = `Rain expected today (${Math.round(weather.precipitationChance * 100)}% chance). Bring an umbrella!`;
          } else if (this.weatherService.shouldNotifyHeat(weather, settings.heatThresholdCelsius)) {
            alertTitle = 'Heat alert';
            alertBody = `High of ${Math.round(weather.temperatureCelsius)}°C today. Stay hydrated!`;
          } else if (this.weatherService.shouldNotifyCold(weather, settings.coldThresholdCelsius)) {
            alertTitle = 'Cold alert';
            alertBody = `Low of ${Math.round(weather.temperatureCelsius)}°C today. Dress warmly!`;
          }
          if (alertTitle) {
            const notificationId = `smart_weather_alert_${date.toISOString().slice(0, 10)}`;
            const scheduledDate = this.buildScheduleDate(date, rule.preferredHour || 7, rule.preferredMinute || 0);
            await this.notificationService.scheduleSmartNotification(
              notificationId, alertTitle, alertBody, scheduledDate,
              { kind: SmartNotificationKind.weatherAlert }
            );
            logs.push(this.makeLog(notificationId, SmartNotificationKind.weatherAlert, alertTitle, alertBody, scheduledDate.toISOString(), now));
            remaining--;
          }
          break;
        }

        case SmartNotificationKind.eventPrep: {
          const soonEvents = events.filter(e => {
            const diff = new Date(e.startDate).getTime() - date.getTime();
            return diff > 0 && diff < 24 * 3600000;
          });
          for (const event of soonEvents.slice(0, 2)) {
            if (remaining <= 0) break;
            const notificationId = `smart_prep_${event.id}`;
            const body = `"${event.title}" is coming up. Check notes and prepare.`;
            const scheduledDate = this.buildScheduleDate(date, rule.preferredHour || 8, rule.preferredMinute || 0);
            await this.notificationService.scheduleSmartNotification(
              notificationId, 'Event prep reminder', body, scheduledDate,
              { kind: SmartNotificationKind.eventPrep, eventId: event.id }
            );
            logs.push(this.makeLog(notificationId, SmartNotificationKind.eventPrep, 'Event prep reminder', body, scheduledDate.toISOString(), now, event.id));
            remaining--;
          }
          break;
        }

        case SmartNotificationKind.moneyReminder: {
          const notificationId = `smart_money_${date.toISOString().slice(0, 10)}`;
          const body = 'Reminder: log today\'s earnings and expenses.';
          const scheduledDate = this.buildScheduleDate(date, rule.preferredHour, rule.preferredMinute);
          await this.notificationService.scheduleSmartNotification(
            notificationId, 'Money reminder', body, scheduledDate,
            { kind: SmartNotificationKind.moneyReminder }
          );
          logs.push(this.makeLog(notificationId, SmartNotificationKind.moneyReminder, 'Money reminder', body, scheduledDate.toISOString(), now));
          remaining--;
          break;
        }
      }
    }

    return logs;
  }

  async saveLogs(logs: NotificationLog[], db: SQLite.SQLiteDatabase): Promise<void> {
    for (const log of logs) {
      await db.runAsync(
        `INSERT INTO notification_logs (id, notification_id, kind, title, body, scheduled_for, delivered_estimate, related_event_id, related_suggestion_id, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        log.id, log.notificationId, log.kind, log.title, log.body,
        log.scheduledFor, log.deliveredEstimate ?? null,
        log.relatedEventId ?? null, log.relatedSuggestionId ?? null,
        log.createdAt
      );
    }
  }

  private async todaySentCount(db: SQLite.SQLiteDatabase, date: Date): Promise<number> {
    const day = date.toISOString().slice(0, 10);
    const row = await db.getFirstAsync<{ cnt: number }>(
      "SELECT COUNT(*) as cnt FROM notification_logs WHERE date(scheduled_for) = ? AND kind NOT IN ('global_limit')",
      day
    );
    return row?.cnt ?? 0;
  }

  private async todayRuleCount(db: SQLite.SQLiteDatabase, kind: SmartNotificationKind, date: Date): Promise<number> {
    const day = date.toISOString().slice(0, 10);
    const row = await db.getFirstAsync<{ cnt: number }>(
      'SELECT COUNT(*) as cnt FROM notification_logs WHERE kind = ? AND date(scheduled_for) = ?',
      kind, day
    );
    return row?.cnt ?? 0;
  }

  private isQuietHours(hour: number, quietStart: number, quietEnd: number): boolean {
    if (quietStart > quietEnd) {
      return hour >= quietStart || hour < quietEnd;
    }
    return hour >= quietStart && hour < quietEnd;
  }

  private buildScheduleDate(date: Date, hour: number, minute: number): Date {
    const d = new Date(date);
    d.setHours(hour || 0, minute || 0, 0, 0);
    return d;
  }

  private makeLog(
    notificationId: string,
    kind: SmartNotificationKind,
    title: string,
    body: string,
    scheduledFor: string,
    now: string,
    relatedEventId?: string,
    relatedSuggestionId?: string
  ): NotificationLog {
    return {
      id: uuidv4(),
      notificationId,
      kind,
      title,
      body,
      scheduledFor,
      relatedEventId,
      relatedSuggestionId,
      createdAt: now,
    };
  }

  private addQuietLog(date: Date, kind: string, logs: NotificationLog[], now: string): void {
    logs.push({
      id: uuidv4(),
      notificationId: 'limit_reached',
      kind: SmartNotificationKind.freeDay,
      title: 'Limit reached',
      body: `Daily notification limit reached for ${date.toISOString().slice(0, 10)}`,
      scheduledFor: now,
      createdAt: now,
    });
  }
}
