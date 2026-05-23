import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Switch,
  Alert,
  TextInput,
} from 'react-native';
import { router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useDatabase } from '../hooks/useDatabase';
import { useSettingsStore } from '../store/settingsStore';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';
import * as SecureStore from 'expo-secure-store';

const CURRENCIES = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CHF', 'CNY', 'INR', 'BRL'];

const ACTIVITY_PREFS = [
  { key: 'indoor', label: 'Indoor', icon: '🏠' },
  { key: 'outdoor', label: 'Outdoor', icon: '🌳' },
  { key: 'low_cost', label: 'Low-Cost', icon: '💰' },
  { key: 'productive', label: 'Productive', icon: '💼' },
  { key: 'social', label: 'Social', icon: '👥' },
  { key: 'relaxing', label: 'Relaxing', icon: '😌' },
  { key: 'fitness', label: 'Fitness', icon: '💪' },
  { key: 'errands', label: 'Errands', icon: '📋' },
] as const;

const ENERGY_LABELS = ['', 'Low Energy', 'Low-Med', 'Medium', 'Med-High', 'Full of Energy'];

export function SettingsScreen() {
  const insets = useSafeAreaInsets();
  const { db } = useDatabase();
  const { settings, updateSetting } = useSettingsStore();

  const [locationEnabled, setLocationEnabled] = useState(false);
  const [activityPrefs, setActivityPrefs] = useState<string[]>([]);
  const [energyLevel, setEnergyLevel] = useState(3);
  const [budgetLevel, setBudgetLevel] = useState<'Low' | 'Medium' | 'High'>('Medium');
  const [currencyCode, setCurrencyCode] = useState('USD');
  const [goalInput, setGoalInput] = useState('');

  useEffect(() => {
    if (settings) {
      setCurrencyCode(settings.currencyCode);
      setGoalInput(settings.monthlyIncomeGoal?.toString() ?? '');
    }
  }, [settings]);

  const toggleActivityPref = (key: string) => {
    setActivityPrefs((prev) =>
      prev.includes(key) ? prev.filter((k) => k !== key) : [...prev, key]
    );
  };

  const handleResetData = () => {
    Alert.alert(
      'Reset All Data',
      'This will permanently delete all events, income entries, work sessions, notifications, and settings. This cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Reset All', style: 'destructive', onPress: async () => {
            if (!db) return;
            const tables = [
              'calendar_events', 'event_notes', 'event_reminders',
              'smart_notification_rules', 'notification_logs',
              'activity_suggestions', 'weather_snapshots',
              'place_candidates', 'income_entries', 'work_sessions',
            ];
            for (const table of tables) {
              await db.runAsync(`DELETE FROM ${table}`);
            }
            await db.runAsync("DELETE FROM user_settings WHERE id = 'default'");
            await SecureStore.deleteItemAsync('ai_api_key_openAI');
            await SecureStore.deleteItemAsync('ai_api_key_claude');
            await SecureStore.deleteItemAsync('ai_api_key_deepSeek');
            await SecureStore.deleteItemAsync('ai_api_key_openAICompatible');
            Alert.alert('Done', 'All data has been reset. Restart the app for changes to take effect.');
          },
        },
      ]
    );
  };

  const saveCurrencyAndGoal = useCallback(async () => {
    if (!db || !settings) return;
    const goalNum = parseFloat(goalInput) || 0;
    await db.runAsync(
      'UPDATE user_settings SET currency_code=?, monthly_income_goal=?, updated_at=? WHERE id=?',
      [currencyCode, goalNum, new Date().toISOString(), 'default']
    );
    updateSetting({ currencyCode, monthlyIncomeGoal: goalNum });
  }, [db, settings, currencyCode, goalInput, updateSetting]);

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
        <Text style={styles.sectionHeader}>AI Configuration</Text>
        <TouchableOpacity
          style={styles.navRow}
          onPress={() => router.push('/ai-settings')}
        >
          <View style={styles.navRowLeft}>
            <Text style={styles.navRowIcon}>🤖</Text>
            <View>
              <Text style={styles.navRowTitle}>AI Settings</Text>
              <Text style={styles.navRowSubtitle}>Configure AI provider, model, and API key</Text>
            </View>
          </View>
          <Text style={styles.chevron}>›</Text>
        </TouchableOpacity>

        <Text style={[styles.sectionHeader, { marginTop: Spacing.xxl }]}>Notifications</Text>
        <TouchableOpacity
          style={styles.navRow}
          onPress={() => router.push('/notification-settings')}
        >
          <View style={styles.navRowLeft}>
            <Text style={styles.navRowIcon}>🔔</Text>
            <View>
              <Text style={styles.navRowTitle}>Smart Notifications</Text>
              <Text style={styles.navRowSubtitle}>Manage notification types and rules</Text>
            </View>
          </View>
          <Text style={styles.chevron}>›</Text>
        </TouchableOpacity>

        <Text style={[styles.sectionHeader, { marginTop: Spacing.xxl }]}>Location</Text>
        <View style={styles.toggleRow}>
          <View style={styles.toggleLeft}>
            <Text style={styles.toggleIcon}>📍</Text>
            <View>
              <Text style={styles.toggleTitle}>Location Access</Text>
              <Text style={styles.toggleSubtitle}>
                {locationEnabled ? 'Enabled' : 'Disabled'}
              </Text>
            </View>
          </View>
          <Switch
            value={locationEnabled}
            onValueChange={setLocationEnabled}
            trackColor={{ false: Colors.border, true: Colors.primaryLight }}
            thumbColor={locationEnabled ? Colors.primary : '#f4f3f4'}
          />
        </View>

        <Text style={[styles.sectionHeader, { marginTop: Spacing.xxl }]}>Preferences</Text>
        <Text style={styles.labelSub}>Activity Preferences</Text>
        <View style={styles.chipGrid}>
          {ACTIVITY_PREFS.map((pref) => {
            const active = activityPrefs.includes(pref.key);
            return (
              <TouchableOpacity
                key={pref.key}
                style={[styles.prefChip, active && styles.prefChipActive]}
                onPress={() => toggleActivityPref(pref.key)}
              >
                <Text style={styles.prefChipIcon}>{pref.icon}</Text>
                <Text style={[styles.prefChipText, active && styles.prefChipTextActive]}>
                  {pref.label}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>

        <Text style={styles.label}>Energy Level</Text>
        <Text style={styles.sliderLabel}>
          {ENERGY_LABELS[energyLevel]}
        </Text>
        <View style={styles.sliderTrack}>
          {[1, 2, 3, 4, 5].map((level) => (
            <TouchableOpacity
              key={level}
              style={[
                styles.sliderStep,
                level <= energyLevel && styles.sliderStepActive,
                level === 1 && { borderTopLeftRadius: BorderRadius.full, borderBottomLeftRadius: BorderRadius.full },
                level === 5 && { borderTopRightRadius: BorderRadius.full, borderBottomRightRadius: BorderRadius.full },
              ]}
              onPress={() => setEnergyLevel(level)}
            />
          ))}
        </View>

        <Text style={styles.label}>Budget Preference</Text>
        <View style={styles.chipRow}>
          {(['Low', 'Medium', 'High'] as const).map((b) => (
            <TouchableOpacity
              key={b}
              style={[styles.budgetChip, budgetLevel === b && styles.budgetChipActive]}
              onPress={() => setBudgetLevel(b)}
            >
              <Text style={[styles.budgetChipText, budgetLevel === b && styles.budgetChipTextActive]}>
                {b}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        <Text style={[styles.sectionHeader, { marginTop: Spacing.xxl }]}>Currency</Text>
        <Text style={styles.labelSub}>Select Currency</Text>
        <View style={styles.chipRow}>
          {CURRENCIES.map((c) => (
            <TouchableOpacity
              key={c}
              style={[styles.currChip, currencyCode === c && styles.currChipActive]}
              onPress={async () => { setCurrencyCode(c); await saveCurrencyAndGoal(); }}
            >
              <Text style={[styles.currChipText, currencyCode === c && styles.currChipTextActive]}>
                {c}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        <Text style={styles.label}>Monthly Income Goal</Text>
        <TextInput
          style={styles.input}
          value={goalInput}
          onChangeText={setGoalInput}
          onBlur={saveCurrencyAndGoal}
          keyboardType="decimal-pad"
          placeholder="0.00"
          placeholderTextColor={Colors.textTertiary}
        />

        <Text style={[styles.sectionHeader, { marginTop: Spacing.xxl }]}>About</Text>
        <View style={styles.aboutRow}>
          <Text style={styles.aboutLabel}>Version</Text>
          <Text style={styles.aboutValue}>SummerCal v2.0</Text>
        </View>
        <TouchableOpacity style={styles.aboutRow}>
          <Text style={styles.aboutLabel}>Privacy</Text>
          <Text style={styles.chevron}>›</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.resetButton} onPress={handleResetData}>
          <Text style={styles.resetButtonText}>Reset All Data</Text>
        </TouchableOpacity>

        <View style={{ height: 60 }} />
      </ScrollView>
    </View>
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
  },
  navRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: Colors.card,
    borderRadius: BorderRadius.md,
    padding: Spacing.lg,
    marginBottom: Spacing.sm,
    ...Shadow.sm,
  },
  navRowLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  navRowIcon: {
    fontSize: 24,
    marginRight: Spacing.md,
  },
  navRowTitle: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.text,
  },
  navRowSubtitle: {
    fontSize: FontSize.xs,
    color: Colors.textSecondary,
    marginTop: 2,
  },
  chevron: {
    fontSize: FontSize.xxl,
    color: Colors.textTertiary,
    fontWeight: '300',
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
    marginTop: Spacing.lg,
    marginBottom: Spacing.sm,
  },
  labelSub: {
    fontSize: FontSize.sm,
    fontWeight: '500',
    color: Colors.textSecondary,
    marginBottom: Spacing.sm,
  },
  chipGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.sm,
  },
  prefChip: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.full,
    backgroundColor: Colors.surface,
    borderWidth: 1,
    borderColor: Colors.border,
    gap: Spacing.xs,
  },
  prefChipActive: {
    backgroundColor: Colors.primary + '15',
    borderColor: Colors.primary,
  },
  prefChipIcon: {
    fontSize: 14,
  },
  prefChipText: {
    fontSize: FontSize.sm,
    color: Colors.text,
    fontWeight: '500',
  },
  prefChipTextActive: {
    color: Colors.primary,
  },
  sliderLabel: {
    fontSize: FontSize.sm,
    color: Colors.primary,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: Spacing.sm,
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
  sliderStepActive: {
    backgroundColor: Colors.primary,
  },
  chipRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.sm,
  },
  budgetChip: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: Spacing.md,
    borderRadius: BorderRadius.md,
    backgroundColor: Colors.surface,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  budgetChipActive: {
    backgroundColor: Colors.primary,
    borderColor: Colors.primary,
  },
  budgetChipText: {
    fontSize: FontSize.md,
    color: Colors.text,
    fontWeight: '600',
  },
  budgetChipTextActive: {
    color: '#FFFFFF',
  },
  currChip: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.full,
    backgroundColor: Colors.surface,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  currChipActive: {
    backgroundColor: Colors.primary,
    borderColor: Colors.primary,
  },
  currChipText: {
    fontSize: FontSize.sm,
    color: Colors.text,
    fontWeight: '500',
  },
  currChipTextActive: {
    color: '#FFFFFF',
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
  },
  aboutRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
    backgroundColor: Colors.card,
    borderRadius: BorderRadius.md,
    marginBottom: Spacing.sm,
    ...Shadow.sm,
  },
  aboutLabel: {
    fontSize: FontSize.md,
    color: Colors.text,
  },
  aboutValue: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
  },
  resetButton: {
    marginTop: Spacing.xxxl,
    alignSelf: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xxl,
    borderRadius: BorderRadius.md,
    borderWidth: 1.5,
    borderColor: Colors.error,
  },
  resetButtonText: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.error,
  },
});
