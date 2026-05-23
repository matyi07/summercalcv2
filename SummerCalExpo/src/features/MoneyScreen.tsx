import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Alert,
  Modal,
  TextInput,
  ScrollView,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useDatabase } from '../hooks/useDatabase';
import { useMoneyStore } from '../store/moneyStore';
import { useSettingsStore } from '../store/settingsStore';
import { MonthlyProgressBar } from '../components/MonthlyProgressBar';
import { EmptyState } from '../components/EmptyState';
import { EarningsService } from '../services/EarningsService';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';
import { IncomeEntry, WorkSession, IncomeCategory } from '../models';
import { v4 as uuidv4 } from 'uuid';
import { AddIncomeSheet } from './AddIncomeSheet';
import { AddWorkSessionSheet } from './AddWorkSessionSheet';

const CURRENCIES = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CHF', 'CNY', 'INR', 'BRL'];

const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

function formatCurrency(amount: number, code: string): string {
  try {
    const localeMap: Record<string, string> = {
      USD: 'en-US', EUR: 'de-DE', GBP: 'en-GB', JPY: 'ja-JP',
      CAD: 'en-CA', AUD: 'en-AU', CHF: 'de-CH', CNY: 'zh-CN',
      INR: 'en-IN', BRL: 'pt-BR',
    };
    const locale = localeMap[code] ?? 'en-US';
    return new Intl.NumberFormat(locale, { style: 'currency', currency: code }).format(amount);
  } catch {
    return `$${amount.toFixed(2)}`;
  }
}

function formatDate(dateStr: string): string {
  const d = new Date(dateStr);
  return `${d.getMonth() + 1}/${d.getDate()}/${String(d.getFullYear()).slice(2)}`;
}

function categoryLabel(cat: IncomeCategory): string {
  const map: Record<IncomeCategory, string> = {
    salary: 'Salary',
    freelance: 'Freelance',
    gig: 'Gig',
    other: 'Other',
  };
  return map[cat] ?? cat;
}

function categoryColor(cat: IncomeCategory): string {
  const map: Record<IncomeCategory, string> = {
    salary: '#007AFF',
    freelance: '#34C759',
    gig: '#FF9500',
    other: '#8E8E93',
  };
  return map[cat] ?? Colors.textSecondary;
}

export function MoneyScreen() {
  const insets = useSafeAreaInsets();
  const { db, ready } = useDatabase();
  const {
    incomeEntries, workSessions, currentMonth,
    setEntries, addEntry, deleteEntry,
    setSessions, addSession, deleteSession,
    setMonth,
  } = useMoneyStore();
  const { settings, updateSetting } = useSettingsStore();

  const [fabVisible, setFabVisible] = useState(false);
  const [addIncomeVisible, setAddIncomeVisible] = useState(false);
  const [addWorkVisible, setAddWorkVisible] = useState(false);
  const [settingsModalVisible, setSettingsModalVisible] = useState(false);
  const [currencyInput, setCurrencyInput] = useState('');
  const [goalInput, setGoalInput] = useState('');

  const earnings = new EarningsService();
  const code = settings?.currencyCode ?? 'USD';

  const incomeTotal = earnings.monthlyIncomeEntries(currentMonth, incomeEntries);
  const workTotal = earnings.monthlyWorkEarnings(currentMonth, workSessions);
  const total = incomeTotal + workTotal;
  const goal = settings?.monthlyIncomeGoal ?? 0;
  const dailyAvg = earnings.dailyAverage(currentMonth, total);

  const loadData = useCallback(async () => {
    if (!db) return;
    const year = currentMonth.getFullYear();
    const month = currentMonth.getMonth();
    const startDate = new Date(year, month, 1).toISOString().slice(0, 10);
    const endDate = new Date(year, month + 1, 0).toISOString().slice(0, 10);

    const rows = await db.getAllAsync<Record<string, any>>(
      'SELECT * FROM income_entries WHERE date >= ? AND date <= ? ORDER BY date DESC, created_at DESC',
      [startDate, endDate]
    );
    const entries: IncomeEntry[] = rows.map((r) => ({
      id: r.id,
      date: r.date,
      amount: r.amount,
      source: r.source,
      descriptionText: r.description_text ?? '',
      category: r.category as IncomeCategory,
      createdAt: r.created_at,
    }));

    const sessRows = await db.getAllAsync<Record<string, any>>(
      'SELECT * FROM work_sessions WHERE date >= ? AND date <= ? ORDER BY date DESC, created_at DESC',
      [startDate, endDate]
    );
    const sessions: WorkSession[] = sessRows.map((r) => ({
      id: r.id,
      date: r.date,
      startTime: r.start_time,
      endTime: r.end_time,
      hourlyRate: r.hourly_rate,
      totalEarned: r.total_earned,
      descriptionText: r.description_text ?? '',
      createdAt: r.created_at,
    }));

    setEntries(entries);
    setSessions(sessions);
  }, [db, currentMonth]);

  useEffect(() => {
    if (ready && db) loadData();
  }, [ready, db, currentMonth]);

  useEffect(() => {
    if (settings) {
      setCurrencyInput(settings.currencyCode);
      setGoalInput(settings.monthlyIncomeGoal?.toString() ?? '');
    }
  }, [settings]);

  const handlePrevMonth = () => {
    const d = new Date(currentMonth);
    d.setMonth(d.getMonth() - 1);
    setMonth(d);
  };

  const handleNextMonth = () => {
    const d = new Date(currentMonth);
    d.setMonth(d.getMonth() + 1);
    setMonth(d);
  };

  const handleDeleteEntry = (entry: IncomeEntry) => {
    Alert.alert('Delete Income Entry', `Delete ${categoryLabel(entry.category)} entry for ${formatCurrency(entry.amount, code)}?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete', style: 'destructive', onPress: async () => {
          deleteEntry(entry.id);
          if (db) await db.runAsync('DELETE FROM income_entries WHERE id = ?', [entry.id]);
        },
      },
    ]);
  };

  const handleDeleteSession = (session: WorkSession) => {
    Alert.alert('Delete Work Session', `Delete work session for ${formatDate(session.date)} earning ${formatCurrency(session.totalEarned, code)}?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete', style: 'destructive', onPress: async () => {
          deleteSession(session.id);
          if (db) await db.runAsync('DELETE FROM work_sessions WHERE id = ?', [session.id]);
        },
      },
    ]);
  };

  const handleSaveIncome = async (data: { date: string; amount: number; source: string; descriptionText: string; category: IncomeCategory }, editId?: string) => {
    if (!db) return;
    if (editId) {
      await db.runAsync(
        'UPDATE income_entries SET date=?, amount=?, source=?, description_text=?, category=? WHERE id=?',
        [data.date, data.amount, data.source, data.descriptionText, data.category, editId]
      );
      await loadData();
    } else {
      const id = uuidv4();
      const now = new Date().toISOString();
      const entry: IncomeEntry = { id, ...data, createdAt: now };
      await db.runAsync(
        'INSERT INTO income_entries (id, date, amount, source, description_text, category, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [entry.id, entry.date, entry.amount, entry.source, entry.descriptionText, entry.category, entry.createdAt]
      );
      addEntry(entry);
    }
    setAddIncomeVisible(false);
  };

  const handleSaveWorkSession = async (data: { date: string; startTime: string; endTime: string; hourlyRate: number; totalEarned: number; descriptionText: string }, editId?: string) => {
    if (!db) return;
    if (editId) {
      await db.runAsync(
        'UPDATE work_sessions SET date=?, start_time=?, end_time=?, hourly_rate=?, total_earned=?, description_text=? WHERE id=?',
        [data.date, data.startTime, data.endTime, data.hourlyRate, data.totalEarned, data.descriptionText, editId]
      );
      await loadData();
    } else {
      const id = uuidv4();
      const now = new Date().toISOString();
      const session: WorkSession = { id, ...data, createdAt: now };
      await db.runAsync(
        'INSERT INTO work_sessions (id, date, start_time, end_time, hourly_rate, total_earned, description_text, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [session.id, session.date, session.startTime, session.endTime, session.hourlyRate, session.totalEarned, session.descriptionText, session.createdAt]
      );
      addSession(session);
    }
    setAddWorkVisible(false);
  };

  const handleSaveSettings = async () => {
    if (!db) return;
    const goalNum = parseFloat(goalInput) || 0;
    await db.runAsync(
      'UPDATE user_settings SET currency_code=?, monthly_income_goal=?, updated_at=? WHERE id=?',
      [currencyInput, goalNum, new Date().toISOString(), 'default']
    );
    updateSetting({ currencyCode: currencyInput, monthlyIncomeGoal: goalNum });
    setSettingsModalVisible(false);
  };

  const renderIncomeItem = ({ item }: { item: IncomeEntry }) => (
    <TouchableOpacity
      style={styles.row}
      onLongPress={() => handleDeleteEntry(item)}
      activeOpacity={0.7}
    >
      <View style={styles.rowLeft}>
        <Text style={styles.rowDate}>{formatDate(item.date)}</Text>
        <Text style={styles.rowSource}>{item.source || item.descriptionText}</Text>
      </View>
      <View style={styles.rowRight}>
        <Text style={styles.rowAmount}>{formatCurrency(item.amount, code)}</Text>
        <View style={[styles.badge, { backgroundColor: categoryColor(item.category) + '20' }]}>
          <Text style={[styles.badgeText, { color: categoryColor(item.category) }]}>
            {categoryLabel(item.category)}
          </Text>
        </View>
      </View>
    </TouchableOpacity>
  );

  const renderSessionItem = ({ item }: { item: WorkSession }) => (
    <TouchableOpacity
      style={styles.row}
      onLongPress={() => handleDeleteSession(item)}
      activeOpacity={0.7}
    >
      <View style={styles.rowLeft}>
        <Text style={styles.rowDate}>{formatDate(item.date)}</Text>
        <Text style={styles.rowSource}>
          {item.startTime} – {item.endTime}  ·  {formatCurrency(item.hourlyRate, code)}/hr
        </Text>
      </View>
      <View style={styles.rowRight}>
        <Text style={styles.rowAmount}>{formatCurrency(item.totalEarned, code)}</Text>
      </View>
    </TouchableOpacity>
  );

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <ScrollView style={styles.scroll} contentContainerStyle={styles.scrollContent}>
        <View style={styles.header}>
          <TouchableOpacity onPress={handlePrevMonth} style={styles.navArrow}>
            <Text style={styles.navArrowText}>{'<'}</Text>
          </TouchableOpacity>
          <Text style={styles.monthTitle}>
            {MONTHS[currentMonth.getMonth()]} {currentMonth.getFullYear()}
          </Text>
          <TouchableOpacity onPress={handleNextMonth} style={styles.navArrow}>
            <Text style={styles.navArrowText}>{'>'}</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.summaryCard}>
          <Text style={styles.summaryHeader}>This Month</Text>
          <Text style={styles.totalEarnings}>{formatCurrency(total, code)}</Text>
          <View style={styles.breakdown}>
            <Text style={styles.breakdownText}>
              Income: {formatCurrency(incomeTotal, code)}
            </Text>
            <Text style={styles.breakdownSep}>|</Text>
            <Text style={styles.breakdownText}>
              Work sessions: {formatCurrency(workTotal, code)}
            </Text>
          </View>
          {goal > 0 && <MonthlyProgressBar current={total} goal={goal} />}
          <Text style={styles.dailyAvg}>
            Daily average: {formatCurrency(dailyAvg, code)}
          </Text>
        </View>

        <Text style={styles.sectionTitle}>Income Entries</Text>
        {incomeEntries.length === 0 ? (
          <EmptyState icon="📋" title="No income entries" subtitle="Tap + to add an income entry" />
        ) : (
          <FlatList
            data={incomeEntries}
            keyExtractor={(item) => item.id}
            renderItem={renderIncomeItem}
            scrollEnabled={false}
            ItemSeparatorComponent={() => <View style={styles.separator} />}
          />
        )}

        <Text style={[styles.sectionTitle, { marginTop: Spacing.xxl }]}>Work Sessions</Text>
        {workSessions.length === 0 ? (
          <EmptyState icon="⏱️" title="No work sessions" subtitle="Tap + to log a work session" />
        ) : (
          <FlatList
            data={workSessions}
            keyExtractor={(item) => item.id}
            renderItem={renderSessionItem}
            scrollEnabled={false}
            ItemSeparatorComponent={() => <View style={styles.separator} />}
          />
        )}

        <TouchableOpacity
          style={styles.settingsButton}
          onPress={() => setSettingsModalVisible(true)}
        >
          <Text style={styles.settingsButtonText}>Currency & Goal Settings</Text>
        </TouchableOpacity>

        <View style={{ height: 80 }} />
      </ScrollView>

      <TouchableOpacity
        style={[styles.fab, { bottom: insets.bottom + 20 }]}
        onPress={() => setFabVisible(true)}
        activeOpacity={0.8}
      >
        <Text style={styles.fabText}>+</Text>
      </TouchableOpacity>

      <Modal visible={fabVisible} transparent animationType="fade" onRequestClose={() => setFabVisible(false)}>
        <TouchableOpacity style={styles.modalOverlay} activeOpacity={1} onPress={() => setFabVisible(false)}>
          <View style={styles.fabSheet}>
            <TouchableOpacity
              style={styles.fabOption}
              onPress={() => { setFabVisible(false); setAddIncomeVisible(true); }}
            >
              <Text style={styles.fabOptionIcon}>💰</Text>
              <Text style={styles.fabOptionText}>Add Income</Text>
            </TouchableOpacity>
            <View style={styles.separator} />
            <TouchableOpacity
              style={styles.fabOption}
              onPress={() => { setFabVisible(false); setAddWorkVisible(true); }}
            >
              <Text style={styles.fabOptionIcon}>⏱️</Text>
              <Text style={styles.fabOptionText}>Add Work Session</Text>
            </TouchableOpacity>
          </View>
        </TouchableOpacity>
      </Modal>

      <AddIncomeSheet visible={addIncomeVisible} onClose={() => setAddIncomeVisible(false)} onSave={handleSaveIncome} />
      <AddWorkSessionSheet visible={addWorkVisible} onClose={() => setAddWorkVisible(false)} onSave={handleSaveWorkSession} currencyCode={code} />

      <Modal visible={settingsModalVisible} transparent animationType="slide" onRequestClose={() => setSettingsModalVisible(false)}>
        <View style={styles.modalOverlay}>
          <View style={[styles.settingsSheet, { paddingBottom: insets.bottom + 20 }]}>
            <Text style={styles.settingsSheetTitle}>Currency & Goal Settings</Text>

            <Text style={styles.inputLabel}>Currency</Text>
            <View style={styles.chipRow}>
              {CURRENCIES.map((c) => (
                <TouchableOpacity
                  key={c}
                  style={[styles.chip, currencyInput === c && styles.chipActive]}
                  onPress={() => setCurrencyInput(c)}
                >
                  <Text style={[styles.chipText, currencyInput === c && styles.chipTextActive]}>{c}</Text>
                </TouchableOpacity>
              ))}
            </View>

            <Text style={styles.inputLabel}>Monthly Income Goal</Text>
            <TextInput
              style={styles.textInput}
              value={goalInput}
              onChangeText={setGoalInput}
              keyboardType="decimal-pad"
              placeholder="0.00"
              placeholderTextColor={Colors.textTertiary}
            />

            <View style={styles.modalButtons}>
              <TouchableOpacity style={styles.cancelButton} onPress={() => setSettingsModalVisible(false)}>
                <Text style={styles.cancelButtonText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.saveButton} onPress={handleSaveSettings}>
                <Text style={styles.saveButtonText}>Save</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
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
  scrollContent: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.xxxl,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.lg,
  },
  navArrow: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  navArrowText: {
    fontSize: FontSize.xxl,
    fontWeight: '700',
    color: Colors.primary,
  },
  monthTitle: {
    fontSize: FontSize.xl,
    fontWeight: '700',
    color: Colors.text,
  },
  summaryCard: {
    backgroundColor: Colors.card,
    borderRadius: BorderRadius.lg,
    padding: Spacing.xl,
    marginBottom: Spacing.xxl,
    alignItems: 'center',
    ...Shadow.md,
  },
  summaryHeader: {
    fontSize: FontSize.sm,
    fontWeight: '500',
    color: Colors.textSecondary,
    marginBottom: Spacing.xs,
  },
  totalEarnings: {
    fontSize: FontSize.title,
    fontWeight: '800',
    color: Colors.text,
    marginBottom: Spacing.sm,
  },
  breakdown: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: Spacing.md,
  },
  breakdownText: {
    fontSize: FontSize.sm,
    color: Colors.textSecondary,
  },
  breakdownSep: {
    fontSize: FontSize.sm,
    color: Colors.textTertiary,
    marginHorizontal: Spacing.sm,
  },
  dailyAvg: {
    fontSize: FontSize.sm,
    color: Colors.textTertiary,
    marginTop: Spacing.xs,
  },
  sectionTitle: {
    fontSize: FontSize.lg,
    fontWeight: '700',
    color: Colors.text,
    marginBottom: Spacing.md,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
    backgroundColor: Colors.card,
    borderRadius: BorderRadius.md,
  },
  rowLeft: {
    flex: 1,
  },
  rowDate: {
    fontSize: FontSize.xs,
    color: Colors.textTertiary,
    marginBottom: 2,
  },
  rowSource: {
    fontSize: FontSize.md,
    color: Colors.text,
    fontWeight: '500',
  },
  rowRight: {
    alignItems: 'flex-end',
  },
  rowAmount: {
    fontSize: FontSize.lg,
    fontWeight: '600',
    color: Colors.text,
    marginBottom: 4,
  },
  badge: {
    paddingHorizontal: Spacing.sm,
    paddingVertical: 2,
    borderRadius: BorderRadius.full,
  },
  badgeText: {
    fontSize: FontSize.xs,
    fontWeight: '600',
  },
  separator: {
    height: Spacing.sm,
  },
  fab: {
    position: 'absolute',
    right: 20,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: Colors.primary,
    justifyContent: 'center',
    alignItems: 'center',
    ...Shadow.lg,
  },
  fabText: {
    fontSize: 28,
    color: '#FFFFFF',
    fontWeight: '400',
    lineHeight: 30,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'flex-end',
  },
  fabSheet: {
    backgroundColor: Colors.card,
    borderTopLeftRadius: BorderRadius.xl,
    borderTopRightRadius: BorderRadius.xl,
    paddingVertical: Spacing.xl,
    paddingHorizontal: Spacing.lg,
    marginBottom: 100,
    marginHorizontal: Spacing.lg,
    ...Shadow.lg,
  },
  fabOption: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Spacing.lg,
  },
  fabOptionIcon: {
    fontSize: 24,
    marginRight: Spacing.md,
  },
  fabOptionText: {
    fontSize: FontSize.lg,
    fontWeight: '600',
    color: Colors.text,
  },
  settingsButton: {
    marginTop: Spacing.xxl,
    alignSelf: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    borderRadius: BorderRadius.md,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  settingsButtonText: {
    fontSize: FontSize.md,
    color: Colors.primary,
    fontWeight: '500',
  },
  settingsSheet: {
    backgroundColor: Colors.card,
    borderTopLeftRadius: BorderRadius.xl,
    borderTopRightRadius: BorderRadius.xl,
    padding: Spacing.xl,
  },
  settingsSheetTitle: {
    fontSize: FontSize.xl,
    fontWeight: '700',
    color: Colors.text,
    marginBottom: Spacing.xl,
    textAlign: 'center',
  },
  inputLabel: {
    fontSize: FontSize.sm,
    fontWeight: '600',
    color: Colors.textSecondary,
    marginBottom: Spacing.sm,
    marginTop: Spacing.lg,
  },
  chipRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.sm,
  },
  chip: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.full,
    backgroundColor: Colors.surface,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  chipActive: {
    backgroundColor: Colors.primary,
    borderColor: Colors.primary,
  },
  chipText: {
    fontSize: FontSize.sm,
    color: Colors.text,
    fontWeight: '500',
  },
  chipTextActive: {
    color: '#FFFFFF',
  },
  textInput: {
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.md,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    fontSize: FontSize.md,
    color: Colors.text,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  modalButtons: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: Spacing.md,
    marginTop: Spacing.xxl,
  },
  cancelButton: {
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    borderRadius: BorderRadius.md,
  },
  cancelButtonText: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
    fontWeight: '500',
  },
  saveButton: {
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    borderRadius: BorderRadius.md,
    backgroundColor: Colors.primary,
  },
  saveButtonText: {
    fontSize: FontSize.md,
    color: '#FFFFFF',
    fontWeight: '600',
  },
});
