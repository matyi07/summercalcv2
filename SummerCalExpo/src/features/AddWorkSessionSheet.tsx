import React, { useEffect, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  Modal,
} from 'react-native';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';

interface AddWorkSessionSheetProps {
  visible: boolean;
  onClose: () => void;
  editId?: string;
  initialData?: { date: string; startTime: string; endTime: string; hourlyRate: number; totalEarned: number; descriptionText: string };
  onSave: (data: { date: string; startTime: string; endTime: string; hourlyRate: number; totalEarned: number; descriptionText: string }, editId?: string) => void;
  currencyCode?: string;
}

function parseTimeToMinutes(timeStr: string): number | null {
  const match = timeStr.match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return null;
  const hours = parseInt(match[1], 10);
  const minutes = parseInt(match[2], 10);
  if (hours > 23 || minutes > 59) return null;
  return hours * 60 + minutes;
}

function formatCurrencyShort(amount: number, code: string): string {
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

export function AddWorkSessionSheet({ visible, onClose, editId, initialData, onSave, currencyCode = 'USD' }: AddWorkSessionSheetProps) {
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const [startTime, setStartTime] = useState('09:00');
  const [endTime, setEndTime] = useState('17:00');
  const [hourlyRate, setHourlyRate] = useState('');
  const [descriptionText, setDescriptionText] = useState('');

  useEffect(() => {
    if (visible) {
      if (initialData) {
        setDate(initialData.date);
        setStartTime(initialData.startTime);
        setEndTime(initialData.endTime);
        setHourlyRate(initialData.hourlyRate.toString());
        setDescriptionText(initialData.descriptionText);
      } else {
        setDate(new Date().toISOString().slice(0, 10));
        setStartTime('09:00');
        setEndTime('17:00');
        setHourlyRate('');
        setDescriptionText('');
      }
    }
  }, [visible, editId]);

  const computed = useMemo(() => {
    const startMin = parseTimeToMinutes(startTime);
    const endMin = parseTimeToMinutes(endTime);
    const rate = parseFloat(hourlyRate);

    if (startMin === null || endMin === null) {
      return { durationHours: 0, durationMinutes: 0, earnings: 0, valid: false };
    }

    let diff = endMin - startMin;
    if (diff <= 0) diff += 24 * 60;

    const hours = Math.floor(diff / 60);
    const minutes = diff % 60;
    const earnings = !isNaN(rate) && rate > 0 ? (diff / 60) * rate : 0;

    return { durationHours: hours, durationMinutes: minutes, earnings, valid: diff > 0 };
  }, [startTime, endTime, hourlyRate]);

  const handleSave = () => {
    if (!computed.valid || computed.earnings <= 0) return;
    if (!date.trim()) return;
    const rate = parseFloat(hourlyRate);
    if (isNaN(rate) || rate <= 0) return;

    onSave(
      {
        date: date.trim(),
        startTime: startTime.trim(),
        endTime: endTime.trim(),
        hourlyRate: rate,
        totalEarned: Math.round(computed.earnings * 100) / 100,
        descriptionText: descriptionText.trim(),
      },
      editId
    );
  };

  const isValid = computed.valid && date.trim().length > 0 && parseFloat(hourlyRate) > 0;

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.overlay}>
        <View style={styles.sheet}>
          <View style={styles.handle} />
          <Text style={styles.title}>{editId ? 'Edit Work Session' : 'Add Work Session'}</Text>

          <Text style={styles.label}>Date</Text>
          <TextInput
            style={styles.input}
            value={date}
            onChangeText={setDate}
            placeholder="YYYY-MM-DD"
            placeholderTextColor={Colors.textTertiary}
          />

          <View style={styles.row}>
            <View style={{ flex: 1 }}>
              <Text style={styles.label}>Start Time</Text>
              <TextInput
                style={styles.input}
                value={startTime}
                onChangeText={setStartTime}
                placeholder="HH:MM"
                placeholderTextColor={Colors.textTertiary}
                keyboardType="numbers-and-punctuation"
              />
            </View>
            <View style={{ width: Spacing.md }} />
            <View style={{ flex: 1 }}>
              <Text style={styles.label}>End Time</Text>
              <TextInput
                style={styles.input}
                value={endTime}
                onChangeText={setEndTime}
                placeholder="HH:MM"
                placeholderTextColor={Colors.textTertiary}
                keyboardType="numbers-and-punctuation"
              />
            </View>
          </View>

          <Text style={styles.label}>Hourly Rate</Text>
          <TextInput
            style={styles.input}
            value={hourlyRate}
            onChangeText={setHourlyRate}
            keyboardType="decimal-pad"
            placeholder="0.00"
            placeholderTextColor={Colors.textTertiary}
          />

          {computed.valid && (
            <View style={styles.calcBox}>
              <Text style={styles.calcText}>
                Duration: {computed.durationHours > 0 ? `${computed.durationHours}h ` : ''}{computed.durationMinutes}m
              </Text>
              {computed.earnings > 0 && (
                <Text style={styles.calcText}>
                  Estimated earnings: {formatCurrencyShort(computed.earnings, currencyCode)}
                </Text>
              )}
            </View>
          )}

          <Text style={styles.label}>Description</Text>
          <TextInput
            style={[styles.input, styles.inputMultiline]}
            value={descriptionText}
            onChangeText={setDescriptionText}
            placeholder="What work was done?"
            placeholderTextColor={Colors.textTertiary}
            multiline
            numberOfLines={2}
          />

          <View style={styles.buttons}>
            <TouchableOpacity style={styles.cancelBtn} onPress={onClose}>
              <Text style={styles.cancelBtnText}>Cancel</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.saveBtn, !isValid && styles.saveBtnDisabled]}
              onPress={handleSave}
              disabled={!isValid}
            >
              <Text style={styles.saveBtnText}>Save</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'flex-end',
  },
  sheet: {
    backgroundColor: Colors.card,
    borderTopLeftRadius: BorderRadius.xl,
    borderTopRightRadius: BorderRadius.xl,
    paddingHorizontal: Spacing.xl,
    paddingBottom: Spacing.xxxl,
    ...Shadow.lg,
  },
  handle: {
    width: 36,
    height: 4,
    backgroundColor: Colors.textTertiary,
    borderRadius: 2,
    alignSelf: 'center',
    marginTop: Spacing.md,
    marginBottom: Spacing.lg,
  },
  title: {
    fontSize: FontSize.xl,
    fontWeight: '700',
    color: Colors.text,
    marginBottom: Spacing.xl,
    textAlign: 'center',
  },
  label: {
    fontSize: FontSize.sm,
    fontWeight: '600',
    color: Colors.textSecondary,
    marginBottom: Spacing.sm,
    marginTop: Spacing.md,
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
  inputMultiline: {
    minHeight: 60,
    textAlignVertical: 'top',
  },
  row: {
    flexDirection: 'row',
  },
  calcBox: {
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.md,
    padding: Spacing.md,
    marginTop: Spacing.md,
  },
  calcText: {
    fontSize: FontSize.md,
    color: Colors.text,
    fontWeight: '500',
    marginBottom: 2,
  },
  buttons: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: Spacing.md,
    marginTop: Spacing.xxl,
  },
  cancelBtn: {
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    borderRadius: BorderRadius.md,
  },
  cancelBtnText: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
    fontWeight: '500',
  },
  saveBtn: {
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    borderRadius: BorderRadius.md,
    backgroundColor: Colors.primary,
  },
  saveBtnDisabled: {
    opacity: 0.4,
  },
  saveBtnText: {
    fontSize: FontSize.md,
    color: '#FFFFFF',
    fontWeight: '600',
  },
});
