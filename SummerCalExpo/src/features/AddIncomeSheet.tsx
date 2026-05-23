import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  Modal,
  ScrollView,
} from 'react-native';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';
import { IncomeCategory } from '../models';

interface AddIncomeSheetProps {
  visible: boolean;
  onClose: () => void;
  editId?: string;
  initialData?: { date: string; amount: number; source: string; descriptionText: string; category: IncomeCategory };
  onSave: (data: { date: string; amount: number; source: string; descriptionText: string; category: IncomeCategory }, editId?: string) => void;
}

const SOURCES = [
  { key: 'freelance', label: 'Freelance' },
  { key: 'salary', label: 'Salary' },
  { key: 'gig', label: 'Gig' },
  { key: 'other', label: 'Other' },
] as const;

const CATEGORIES: { key: IncomeCategory; label: string; color: string }[] = [
  { key: IncomeCategory.salary, label: 'Salary', color: '#007AFF' },
  { key: IncomeCategory.freelance, label: 'Freelance', color: '#34C759' },
  { key: IncomeCategory.gig, label: 'Gig', color: '#FF9500' },
  { key: IncomeCategory.other, label: 'Other', color: '#8E8E93' },
];

export function AddIncomeSheet({ visible, onClose, editId, initialData, onSave }: AddIncomeSheetProps) {
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const [amount, setAmount] = useState('');
  const [source, setSource] = useState('freelance');
  const [category, setCategory] = useState<IncomeCategory>(IncomeCategory.freelance);
  const [descriptionText, setDescriptionText] = useState('');

  useEffect(() => {
    if (visible) {
      if (initialData) {
        setDate(initialData.date);
        setAmount(initialData.amount.toString());
        setSource(initialData.source);
        setDescriptionText(initialData.descriptionText);
        setCategory(initialData.category);
      } else {
        setDate(new Date().toISOString().slice(0, 10));
        setAmount('');
        setSource('freelance');
        setDescriptionText('');
        setCategory(IncomeCategory.freelance);
      }
    }
  }, [visible, editId]);

  const handleSave = () => {
    const parsedAmount = parseFloat(amount);
    if (isNaN(parsedAmount) || parsedAmount <= 0) return;
    if (!date.trim()) return;
    onSave({ date: date.trim(), amount: parsedAmount, source, descriptionText: descriptionText.trim(), category }, editId);
  };

  const isValid = date.trim().length > 0 && parseFloat(amount) > 0;

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.overlay}>
        <View style={styles.sheet}>
          <View style={styles.handle} />
          <Text style={styles.title}>{editId ? 'Edit Income Entry' : 'Add Income Entry'}</Text>

          <Text style={styles.label}>Date</Text>
          <TextInput
            style={styles.input}
            value={date}
            onChangeText={setDate}
            placeholder="YYYY-MM-DD"
            placeholderTextColor={Colors.textTertiary}
          />

          <Text style={styles.label}>Amount</Text>
          <TextInput
            style={styles.input}
            value={amount}
            onChangeText={setAmount}
            keyboardType="decimal-pad"
            placeholder="0.00"
            placeholderTextColor={Colors.textTertiary}
          />

          <Text style={styles.label}>Source</Text>
          <View style={styles.chipRow}>
            {SOURCES.map((s) => (
              <TouchableOpacity
                key={s.key}
                style={[styles.chip, source === s.key && styles.chipActive]}
                onPress={() => setSource(s.key)}
              >
                <Text style={[styles.chipText, source === s.key && styles.chipTextActive]}>
                  {s.label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          <Text style={styles.label}>Category</Text>
          <View style={styles.chipRow}>
            {CATEGORIES.map((cat) => (
              <TouchableOpacity
                key={cat.key}
                style={[
                  styles.chip,
                  category === cat.key && { backgroundColor: cat.color, borderColor: cat.color },
                ]}
                onPress={() => setCategory(cat.key)}
              >
                <Text
                  style={[
                    styles.chipText,
                    category === cat.key && styles.chipTextActive,
                  ]}
                >
                  {cat.label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          <Text style={styles.label}>Description</Text>
          <TextInput
            style={[styles.input, styles.inputMultiline]}
            value={descriptionText}
            onChangeText={setDescriptionText}
            placeholder="What was this for?"
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
  chipRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.sm,
  },
  chip: {
    paddingHorizontal: Spacing.lg,
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
