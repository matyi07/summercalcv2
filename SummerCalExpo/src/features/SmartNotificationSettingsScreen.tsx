import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Switch,
  TouchableOpacity,
  TextInput,
  Modal,
  FlatList,
  Alert,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useDatabase } from '../hooks/useDatabase';
import { useSettingsStore } from '../store/settingsStore';
import { useNotificationStore } from '../store/notificationStore';
import { SmartNotificationKind, SmartNotificationRule, NotificationLog, DEFAULT_USER_SETTINGS, SMART_NOTIFICATION_RULES } from '../models';
import { SmartNotificationService } from '../services/SmartNotificationService';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';

const RULE_LABELS: Record<SmartNotificationKind, { title: string; subtitle: string; icon: string }> = {
  [SmartNotificationKind.upcomingEvent]: { title: 'Upcoming Events', subtitle: 'Remind before events', icon: '📅' },
  [SmartNotificationKind.freeDay]: { title: 'Free Day', subtitle: 'Notify when day is free', icon: '🌤️' },
  [SmartNotificationKind.freeAfternoon]: { title: 'Free Afternoon', subtitle: 'Notify afternoon free time', icon: '☀️' },
  [SmartNotificationKind.weatherSummary]: { title: 'Weather Summary', subtitle: 'Morning weather report', icon: '🌡️' },
  [SmartNotificationKind.weatherAlert]: { title: 'Weather Alerts', subtitle: 'Rain, heat, snow warnings', icon: '⚠️' },
  [SmartNotificationKind.eventPrep]: { title: 'Event Preparation', subtitle: 'Prep suggestions', icon: '📝' },
  [SmartNotificationKind.moneyReminder]: { title: 'Money Reminders', subtitle: 'Monthly goal tracking', icon: '💰' },
};

function padTwo(n: number): string {
  return n.toString().padStart(2, '0');
}

export function SmartNotificationSettingsScreen() {
  const insets = useSafeAreaInsets();
  const { db } = useDatabase();
  const { settings, updateSetting } = useSettingsStore();
  const { rules, setRules, updateRule, logs, setLogs, scheduling, setScheduling } = useNotificationStore();

  const [quietHoursStart, setQuietHoursStart] = useState('22');
  const [quietHoursEnd, setQuietHoursEnd] = useState('08');
  const [freeDayThreshold, setFreeDayThreshold] = useState(4);
  const [freeDayCheckHour, setFreeDayCheckHour] = useState('09');
  const [freeDayCheckMinute, setFreeDayCheckMinute] = useState('00');
  const [rainThreshold, setRainThreshold] = useState(50);
  const [heatThreshold, setHeatThreshold] = useState('35');
  const [coldThreshold, setColdThreshold] = useState('0');
  const [maxPerDay, setMaxPerDay] = useState(2);
  const [dailyWeatherEnabled, setDailyWeatherEnabled] = useState(true);
  const [weatherAlertsEnabled, setWeatherAlertsEnabled] = useState(true);
  const [nextDayPreview, setNextDayPreview] = useState(false);
  const [logModalVisible, setLogModalVisible] = useState(false);

  useEffect(() => {
    if (settings) {
      setQuietHoursStart(settings.quietHoursStart.toString().padStart(2, '0'));
      setQuietHoursEnd(settings.quietHoursEnd.toString().padStart(2, '0'));
      setFreeDayThreshold(settings.freeDayThresholdHours);
      setFreeDayCheckHour(settings.freeDayCheckHour.toString().padStart(2, '0'));
      setFreeDayCheckMinute(settings.freeDayCheckMinute.toString().padStart(2, '0'));
      setRainThreshold(Math.round(settings.rainThreshold * 100));
      setHeatThreshold(settings.heatThresholdCelsius.toString());
      setColdThreshold(settings.coldThresholdCelsius.toString());
      setMaxPerDay(settings.maxSmartNotificationsPerDay);
      setDailyWeatherEnabled(settings.dailyWeatherSummaryEnabled);
      setWeatherAlertsEnabled(settings.weatherAlertsEnabled);
      setNextDayPreview(settings.nextDayFreePreviewEnabled);
    }
  }, [settings]);

  useEffect(() => {
    if (db && rules.length === 0) {
      db.getAllAsync<Record<string, any>>('SELECT * FROM smart_notification_rules').then((rows) => {
        const loaded: SmartNotificationRule[] = rows.map((r) => ({
          id: r.id,
          kind: r.kind as SmartNotificationKind,
          isEnabled: r.is_enabled === 1,
          preferredHour: r.preferred_hour,
          preferredMinute: r.preferred_minute,
          quietHoursStart: r.quiet_hours_start,
          quietHoursEnd: r.quiet_hours_end,
          maxPerDay: r.max_per_day,
          createdAt: r.created_at,
          updatedAt: r.updated_at,
        }));
        if (loaded.length > 0) {
          setRules(loaded);
        } else {
          setRules(SMART_NOTIFICATION_RULES);
        }
      });
    }
  }, [db]);

  useEffect(() => {
    if (db) {
      db.getAllAsync<Record<string, any>>(
        'SELECT * FROM notification_logs ORDER BY created_at DESC LIMIT 100'
      ).then((rows) => {
        const loaded: NotificationLog[] = rows.map((r) => ({
          id: r.id,
          notificationId: r.notification_id,
          kind: r.kind as SmartNotificationKind,
          title: r.title,
          body: r.body,
          scheduledFor: r.scheduled_for,
          deliveredEstimate: r.delivered_estimate,
          relatedEventId: r.related_event_id,
          relatedSuggestionId: r.related_suggestion_id,
          createdAt: r.created_at,
        }));
        setLogs(loaded);
      });
    }
  }, [db]);

  const handleToggleRule = useCallback(async (rule: SmartNotificationRule) => {
    const updated = { ...rule, isEnabled: !rule.isEnabled, updatedAt: new Date().toISOString() };
    updateRule(updated);
    if (db) {
      await db.runAsync(
        'UPDATE smart_notification_rules SET is_enabled=?, updated_at=? WHERE id=?',
        [updated.isEnabled ? 1 : 0, updated.updatedAt, updated.id]
      );
    }
  }, [db, updateRule]);

  const handleSaveGlobalSettings = useCallback(async () => {
    if (!db || !settings) return;
    const qStart = parseInt(quietHoursStart, 10) || 22;
    const qEnd = parseInt(quietHoursEnd, 10) || 8;
    const threshold = freeDayThreshold;
    const checkH = parseInt(freeDayCheckHour, 10) || 9;
    const checkM = parseInt(freeDayCheckMinute, 10) || 0;
    const rain = rainThreshold / 100;
    const heat = parseInt(heatThreshold, 10) || 35;
    const cold = parseInt(coldThreshold, 10) || 0;
    const max = maxPerDay;

    await db.runAsync(
      `UPDATE user_settings SET
        quiet_hours_start=?, quiet_hours_end=?,
        free_day_threshold_hours=?, free_day_check_hour=?, free_day_check_minute=?,
        rain_threshold=?, heat_threshold_celsius=?, cold_threshold_celsius=?,
        max_smart_notifications_per_day=?,
        daily_weather_summary_enabled=?, weather_alerts_enabled=?,
        next_day_free_preview_enabled=?, updated_at=?
       WHERE id='default'`,
      [qStart, qEnd, threshold, checkH, checkM, rain, heat, cold, max,
        dailyWeatherEnabled ? 1 : 0, weatherAlertsEnabled ? 1 : 0,
        nextDayPreview ? 1 : 0, new Date().toISOString()]
    );

    updateSetting({
      quietHoursStart: qStart,
      quietHoursEnd: qEnd,
      freeDayThresholdHours: threshold,
      freeDayCheckHour: checkH,
      freeDayCheckMinute: checkM,
      rainThreshold: rain,
      heatThresholdCelsius: heat,
      coldThresholdCelsius: cold,
      maxSmartNotificationsPerDay: max,
      dailyWeatherSummaryEnabled: dailyWeatherEnabled,
      weatherAlertsEnabled: weatherAlertsEnabled,
      nextDayFreePreviewEnabled: nextDayPreview,
    });

    Alert.alert('Saved', 'Notification settings saved.');
  }, [db, settings, quietHoursStart, quietHoursEnd, freeDayThreshold,
    freeDayCheckHour, freeDayCheckMinute, rainThreshold, heatThreshold,
    coldThreshold, maxPerDay, dailyWeatherEnabled, weatherAlertsEnabled,
    nextDayPreview, updateSetting]);

  const handleResetDefaults = useCallback(() => {
    Alert.alert('Reset to Defaults', 'Restore all notification settings to their default values?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Reset', style: 'destructive', onPress: async () => {
          setQuietHoursStart(String(DEFAULT_USER_SETTINGS.quietHoursStart));
          setQuietHoursEnd(String(DEFAULT_USER_SETTINGS.quietHoursEnd));
          setFreeDayThreshold(DEFAULT_USER_SETTINGS.freeDayThresholdHours);
          setFreeDayCheckHour(String(DEFAULT_USER_SETTINGS.freeDayCheckHour));
          setFreeDayCheckMinute(String(DEFAULT_USER_SETTINGS.freeDayCheckMinute));
          setRainThreshold(Math.round(DEFAULT_USER_SETTINGS.rainThreshold * 100));
          setHeatThreshold(String(DEFAULT_USER_SETTINGS.heatThresholdCelsius));
          setColdThreshold(String(DEFAULT_USER_SETTINGS.coldThresholdCelsius));
          setMaxPerDay(DEFAULT_USER_SETTINGS.maxSmartNotificationsPerDay);
          setDailyWeatherEnabled(DEFAULT_USER_SETTINGS.dailyWeatherSummaryEnabled);
          setWeatherAlertsEnabled(DEFAULT_USER_SETTINGS.weatherAlertsEnabled);
          setNextDayPreview(DEFAULT_USER_SETTINGS.nextDayFreePreviewEnabled);

          setRules(SMART_NOTIFICATION_RULES);
          if (db) {
            for (const rule of SMART_NOTIFICATION_RULES) {
              await db.runAsync(
                'INSERT OR REPLACE INTO smart_notification_rules (id, kind, is_enabled, preferred_hour, preferred_minute, quiet_hours_start, quiet_hours_end, max_per_day, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [rule.id, rule.kind, rule.isEnabled ? 1 : 0, rule.preferredHour, rule.preferredMinute, rule.quietHoursStart, rule.quietHoursEnd, rule.maxPerDay, rule.createdAt, rule.updatedAt]
              );
            }
          }
          await handleSaveGlobalSettings();
        },
      },
    ]);
  }, [db, handleSaveGlobalSettings]);

  const handleScheduleNow = useCallback(async () => {
    if (!db || !settings) {
      Alert.alert('Error', 'Database not ready.');
      return;
    }
    setScheduling(true);
    try {
      const service = new SmartNotificationService();
      const eventsSql = db.getAllAsync<Record<string, any>>('SELECT * FROM calendar_events WHERE date(start_date) = date("now")');
      const weatherSql = db.getFirstAsync<Record<string, any>>('SELECT * FROM weather_snapshots ORDER BY fetched_at DESC LIMIT 1');

      const [eventsRows, weatherRow] = await Promise.all([eventsSql, weatherSql]);

      const events = eventsRows.map((r) => ({
        id: r.id, title: r.title,
        startDate: r.start_date, endDate: r.end_date,
        isAllDay: r.is_all_day === 1,
        location: r.location, notes: r.notes,
        category: r.category, isOutdoor: r.is_outdoor === 1,
        recurrenceRule: r.recurrence_rule,
        notificationEnabled: r.notification_enabled === 1,
        reminderMinutesBefore: r.reminder_minutes_before,
        createdAt: r.created_at, updatedAt: r.updated_at,
      }));

      const weather = weatherRow ? {
        id: weatherRow.id, latitude: weatherRow.latitude, longitude: weatherRow.longitude,
        fetchedAt: weatherRow.fetched_at, forecastDate: weatherRow.forecast_date,
        condition: weatherRow.condition, temperatureCelsius: weatherRow.temperature_celsius,
        precipitationChance: weatherRow.precipitation_chance,
        windSpeedKph: weatherRow.wind_speed_kph, summary: weatherRow.summary,
      } : undefined;

      const logs = await service.runDailyPipeline(new Date(), db, events, settings, rules, weather);
      if (logs.length > 0) {
        await service.saveLogs(logs, db);
      }

      const freshLogs = await db.getAllAsync<Record<string, any>>(
        'SELECT * FROM notification_logs ORDER BY created_at DESC LIMIT 100'
      );
      const loaded: NotificationLog[] = freshLogs.map((r) => ({
        id: r.id, notificationId: r.notification_id,
        kind: r.kind as SmartNotificationKind,
        title: r.title, body: r.body,
        scheduledFor: r.scheduled_for, deliveredEstimate: r.delivered_estimate,
        relatedEventId: r.related_event_id, relatedSuggestionId: r.related_suggestion_id,
        createdAt: r.created_at,
      }));
      setLogs(loaded);

      Alert.alert('Done', `Scheduled ${logs.length} notification(s).`);
    } catch (err: any) {
      Alert.alert('Error', err?.message ?? 'Failed to schedule notifications.');
    } finally {
      setScheduling(false);
    }
  }, [db, settings, rules, setScheduling, setLogs]);

  const getRuleByKind = (kind: SmartNotificationKind): SmartNotificationRule | undefined => {
    return rules.find((r) => r.kind === kind);
  };

  const renderLogItem = ({ item }: { item: NotificationLog }) => (
    <View style={styles.logRow}>
      <View style={styles.logLeft}>
        <Text style={styles.logKind}>{item.kind}</Text>
        <Text style={styles.logTitle}>{item.title}</Text>
      </View>
      <Text style={styles.logDate}>
        {new Date(item.scheduledFor).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
      </Text>
    </View>
  );

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
        <Text style={styles.sectionHeader}>Notification Types</Text>

        {Object.values(SmartNotificationKind).map((kind) => {
          const rule = getRuleByKind(kind);
          const label = RULE_LABELS[kind];
          return (
            <View key={kind} style={styles.toggleRow}>
              <View style={styles.toggleLeft}>
                <Text style={styles.toggleIcon}>{label.icon}</Text>
                <View style={{ flex: 1 }}>
                  <Text style={styles.toggleTitle}>{label.title}</Text>
                  <Text style={styles.toggleSubtitle}>{label.subtitle}</Text>
                </View>
              </View>
              <Switch
                value={rule?.isEnabled ?? true}
                onValueChange={() => rule && handleToggleRule(rule)}
                trackColor={{ false: Colors.border, true: Colors.primaryLight }}
                thumbColor={rule?.isEnabled ? Colors.primary : '#f4f3f4'}
              />
            </View>
          );
        })}

        <Text style={[styles.sectionHeader, { marginTop: Spacing.xxl }]}>Quiet Hours</Text>
        <View style={styles.row}>
          <View style={{ flex: 1 }}>
            <Text style={styles.label}>Start</Text>
            <TextInput
              style={styles.input}
              value={quietHoursStart}
              onChangeText={setQuietHoursStart}
              onBlur={handleSaveGlobalSettings}
              keyboardType="number-pad"
              placeholder="22"
              placeholderTextColor={Colors.textTertiary}
            />
          </View>
          <View style={{ width: Spacing.md }} />
          <View style={{ flex: 1 }}>
            <Text style={styles.label}>End</Text>
            <TextInput
              style={styles.input}
              value={quietHoursEnd}
              onChangeText={setQuietHoursEnd}
              onBlur={handleSaveGlobalSettings}
              keyboardType="number-pad"
              placeholder="08"
              placeholderTextColor={Colors.textTertiary}
            />
          </View>
        </View>

        <Text style={[styles.sectionHeader, { marginTop: Spacing.xxl }]}>Free Day</Text>
        <Text style={styles.label}>
          Threshold hours: {freeDayThreshold}h
        </Text>
        <View style={styles.sliderTrack}>
          {[1, 2, 3, 4, 5, 6, 7, 8].map((h) => (
            <TouchableOpacity
              key={h}
              style={[
                styles.sliderStep,
                h <= freeDayThreshold && styles.sliderStepActive,
                h === 1 && styles.sliderStepFirst,
                h === 8 && styles.sliderStepLast,
              ]}
              onPress={() => { setFreeDayThreshold(h); setTimeout(handleSaveGlobalSettings, 100); }}
            />
          ))}
        </View>

        <View style={styles.row}>
          <View style={{ flex: 1 }}>
            <Text style={styles.label}>Check Hour</Text>
            <TextInput
              style={styles.input}
              value={freeDayCheckHour}
              onChangeText={setFreeDayCheckHour}
              onBlur={handleSaveGlobalSettings}
              keyboardType="number-pad"
              placeholder="09"
              placeholderTextColor={Colors.textTertiary}
            />
          </View>
          <View style={{ width: Spacing.md }} />
          <View style={{ flex: 1 }}>
            <Text style={styles.label}>Check Minute</Text>
            <TextInput
              style={styles.input}
              value={freeDayCheckMinute}
              onChangeText={setFreeDayCheckMinute}
              onBlur={handleSaveGlobalSettings}
              keyboardType="number-pad"
              placeholder="00"
              placeholderTextColor={Colors.textTertiary}
            />
          </View>
        </View>

        <Text style={[styles.sectionHeader, { marginTop: Spacing.xxl }]}>Weather Alerts</Text>
        <Text style={styles.label}>
          Rain threshold: {rainThreshold}%
        </Text>
        <View style={styles.sliderTrack}>
          {[0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100].map((p) => (
            <TouchableOpacity
              key={p}
              style={[
                styles.sliderStepSmall,
                p <= rainThreshold && styles.sliderStepActive,
                p === 0 && styles.sliderStepFirst,
                p === 100 && styles.sliderStepLast,
              ]}
              onPress={() => { setRainThreshold(p); setTimeout(handleSaveGlobalSettings, 100); }}
            />
          ))}
        </View>

        <View style={styles.row}>
          <View style={{ flex: 1 }}>
            <Text style={styles.label}>Heat Threshold (°C)</Text>
            <TextInput
              style={styles.input}
              value={heatThreshold}
              onChangeText={setHeatThreshold}
              onBlur={handleSaveGlobalSettings}
              keyboardType="number-pad"
              placeholder="35"
              placeholderTextColor={Colors.textTertiary}
            />
          </View>
          <View style={{ width: Spacing.md }} />
          <View style={{ flex: 1 }}>
            <Text style={styles.label}>Cold Threshold (°C)</Text>
            <TextInput
              style={styles.input}
              value={coldThreshold}
              onChangeText={setColdThreshold}
              onBlur={handleSaveGlobalSettings}
              keyboardType="number-pad"
              placeholder="0"
              placeholderTextColor={Colors.textTertiary}
            />
          </View>
        </View>

        <Text style={[styles.sectionHeader, { marginTop: Spacing.xxl }]}>General</Text>
        <Text style={styles.label}>
          Max notifications per day: {maxPerDay}
        </Text>
        <View style={styles.sliderTrack}>
          {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((n) => (
            <TouchableOpacity
              key={n}
              style={[
                styles.sliderStepSmall,
                n <= maxPerDay && styles.sliderStepActive,
                n === 1 && styles.sliderStepFirst,
                n === 10 && styles.sliderStepLast,
              ]}
              onPress={() => { setMaxPerDay(n); setTimeout(handleSaveGlobalSettings, 100); }}
            />
          ))}
        </View>

        <View style={styles.toggleRow}>
          <View style={styles.toggleLeft}>
            <View style={{ flex: 1 }}>
              <Text style={styles.toggleTitle}>Daily weather summary</Text>
              <Text style={styles.toggleSubtitle}>Morning weather notification</Text>
            </View>
          </View>
          <Switch
            value={dailyWeatherEnabled}
            onValueChange={(v) => { setDailyWeatherEnabled(v); setTimeout(handleSaveGlobalSettings, 100); }}
            trackColor={{ false: Colors.border, true: Colors.primaryLight }}
            thumbColor={dailyWeatherEnabled ? Colors.primary : '#f4f3f4'}
          />
        </View>

        <View style={styles.toggleRow}>
          <View style={styles.toggleLeft}>
            <View style={{ flex: 1 }}>
              <Text style={styles.toggleTitle}>Weather alerts</Text>
              <Text style={styles.toggleSubtitle}>Rain, heat, cold alerts</Text>
            </View>
          </View>
          <Switch
            value={weatherAlertsEnabled}
            onValueChange={(v) => { setWeatherAlertsEnabled(v); setTimeout(handleSaveGlobalSettings, 100); }}
            trackColor={{ false: Colors.border, true: Colors.primaryLight }}
            thumbColor={weatherAlertsEnabled ? Colors.primary : '#f4f3f4'}
          />
        </View>

        <View style={styles.toggleRow}>
          <View style={styles.toggleLeft}>
            <View style={{ flex: 1 }}>
              <Text style={styles.toggleTitle}>Next-day free preview</Text>
              <Text style={styles.toggleSubtitle}>Notify about free day tomorrow</Text>
            </View>
          </View>
          <Switch
            value={nextDayPreview}
            onValueChange={(v) => { setNextDayPreview(v); setTimeout(handleSaveGlobalSettings, 100); }}
            trackColor={{ false: Colors.border, true: Colors.primaryLight }}
            thumbColor={nextDayPreview ? Colors.primary : '#f4f3f4'}
          />
        </View>

        <SaveButton label="Save All Settings" onPress={handleSaveGlobalSettings} />

        <View style={styles.actionRow}>
          <TouchableOpacity style={styles.actionBtn} onPress={handleResetDefaults}>
            <Text style={styles.actionBtnText}>Reset to Defaults</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.actionBtn, styles.actionBtnPrimary, scheduling && styles.actionBtnDisabled]}
            onPress={handleScheduleNow}
            disabled={scheduling}
          >
            <Text style={styles.actionBtnPrimaryText}>
              {scheduling ? 'Scheduling...' : 'Schedule Now'}
            </Text>
          </TouchableOpacity>
        </View>

        <TouchableOpacity style={styles.viewLogBtn} onPress={() => setLogModalVisible(true)}>
          <Text style={styles.viewLogBtnText}>View Log ({logs.length})</Text>
        </TouchableOpacity>

        <View style={{ height: 60 }} />
      </ScrollView>

      <Modal visible={logModalVisible} transparent animationType="slide" onRequestClose={() => setLogModalVisible(false)}>
        <View style={styles.modalOverlay}>
          <View style={styles.logSheet}>
            <View style={styles.logSheetHeader}>
              <Text style={styles.logSheetTitle}>Notification Log</Text>
              <TouchableOpacity onPress={() => setLogModalVisible(false)}>
                <Text style={styles.logCloseBtn}>Close</Text>
              </TouchableOpacity>
            </View>
            {logs.length === 0 ? (
              <Text style={styles.logEmpty}>No log entries yet.</Text>
            ) : (
              <FlatList
                data={logs}
                keyExtractor={(item) => item.id}
                renderItem={renderLogItem}
                ItemSeparatorComponent={() => <View style={styles.logSeparator} />}
              />
            )}
          </View>
        </View>
      </Modal>
    </View>
  );
}

function SaveButton({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <TouchableOpacity style={styles.saveBtnWrapper} onPress={onPress}>
      <Text style={styles.saveBtnText}>{label}</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  scroll: {
    flex: 1,
  },
  content: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.xxxl,
  },
  sectionHeader: {
    fontSize: FontSize.sm,
    fontWeight: '600',
    color: Colors.textTertiary,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: Spacing.md,
    marginTop: Spacing.xl,
  },
  toggleRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: Colors.card,
    borderRadius: BorderRadius.md,
    padding: Spacing.lg,
    marginBottom: Spacing.sm,
    ...Shadow.sm,
  },
  toggleLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  toggleIcon: {
    fontSize: 24,
    marginRight: Spacing.md,
  },
  toggleTitle: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.text,
  },
  toggleSubtitle: {
    fontSize: FontSize.xs,
    color: Colors.textSecondary,
    marginTop: 2,
  },
  label: {
    fontSize: FontSize.sm,
    fontWeight: '600',
    color: Colors.textSecondary,
    marginTop: Spacing.md,
    marginBottom: Spacing.sm,
  },
  input: {
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.md,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    fontSize: FontSize.md,
    color: Colors.text,
    borderWidth: 1,
    borderColor: Colors.border,
    textAlign: 'center',
  },
  row: {
    flexDirection: 'row',
  },
  sliderTrack: {
    flexDirection: 'row',
    height: 32,
    borderRadius: BorderRadius.full,
    overflow: 'hidden',
    backgroundColor: Colors.surface,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  sliderStep: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  sliderStepSmall: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  sliderStepActive: {
    backgroundColor: Colors.primary,
  },
  sliderStepFirst: {
    borderTopLeftRadius: BorderRadius.full,
    borderBottomLeftRadius: BorderRadius.full,
  },
  sliderStepLast: {
    borderTopRightRadius: BorderRadius.full,
    borderBottomRightRadius: BorderRadius.full,
  },
  actionRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: Spacing.xl,
    gap: Spacing.md,
  },
  actionBtn: {
    flex: 1,
    paddingVertical: Spacing.lg,
    borderRadius: BorderRadius.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: Colors.border,
  },
  actionBtnPrimary: {
    backgroundColor: Colors.primary,
    borderColor: Colors.primary,
  },
  actionBtnDisabled: {
    opacity: 0.5,
  },
  actionBtnText: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.text,
  },
  actionBtnPrimaryText: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  saveBtnWrapper: {
    marginTop: Spacing.xl,
    paddingVertical: Spacing.lg,
    borderRadius: BorderRadius.md,
    backgroundColor: Colors.primary,
    alignItems: 'center',
  },
  saveBtnText: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  viewLogBtn: {
    marginTop: Spacing.xl,
    alignSelf: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    borderRadius: BorderRadius.md,
    borderWidth: 1,
    borderColor: Colors.info,
  },
  viewLogBtnText: {
    fontSize: FontSize.md,
    color: Colors.info,
    fontWeight: '500',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'flex-end',
  },
  logSheet: {
    backgroundColor: Colors.card,
    borderTopLeftRadius: BorderRadius.xl,
    borderTopRightRadius: BorderRadius.xl,
    maxHeight: '70%',
    paddingHorizontal: Spacing.xl,
    paddingBottom: Spacing.xxxl,
    ...Shadow.lg,
  },
  logSheetHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.lg,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
    marginBottom: Spacing.md,
  },
  logSheetTitle: {
    fontSize: FontSize.xl,
    fontWeight: '700',
    color: Colors.text,
  },
  logCloseBtn: {
    fontSize: FontSize.md,
    color: Colors.primary,
    fontWeight: '600',
  },
  logEmpty: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
    textAlign: 'center',
    paddingVertical: Spacing.xxxl,
  },
  logRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.md,
  },
  logLeft: {
    flex: 1,
    marginRight: Spacing.md,
  },
  logKind: {
    fontSize: FontSize.xs,
    color: Colors.textTertiary,
    marginBottom: 2,
  },
  logTitle: {
    fontSize: FontSize.md,
    color: Colors.text,
    fontWeight: '500',
  },
  logDate: {
    fontSize: FontSize.sm,
    color: Colors.textSecondary,
  },
  logSeparator: {
    height: 1,
    backgroundColor: Colors.border,
  },
});
