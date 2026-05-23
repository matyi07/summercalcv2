import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Spacing, FontSize, BorderRadius } from '../constants/theme';

interface MonthlyProgressBarProps {
  current: number;
  goal: number;
}

export function MonthlyProgressBar({ current, goal }: MonthlyProgressBarProps) {
  const percentage = goal > 0 ? Math.min(100, Math.round((current / goal) * 100)) : 0;
  const isOverGoal = current > goal && goal > 0;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.label}>Monthly Goal</Text>
        <Text style={[styles.percentage, isOverGoal && styles.overGoalText]}>
          {percentage}%
        </Text>
      </View>
      <View style={styles.track}>
        <View
          style={[
            styles.fill,
            { width: `${Math.min(100, percentage)}%` },
            isOverGoal && styles.overGoalFill,
          ]}
        />
      </View>
      <View style={styles.footer}>
        <Text style={styles.current}>${current.toLocaleString()}</Text>
        <Text style={styles.goal}>of ${goal.toLocaleString()}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingVertical: Spacing.sm,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.sm,
  },
  label: {
    fontSize: FontSize.sm,
    fontWeight: '500',
    color: Colors.textSecondary,
  },
  percentage: {
    fontSize: FontSize.md,
    fontWeight: '700',
    color: Colors.primary,
  },
  overGoalText: {
    color: Colors.success,
  },
  track: {
    height: 10,
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.full,
    overflow: 'hidden',
    marginBottom: Spacing.xs,
  },
  fill: {
    height: '100%',
    backgroundColor: Colors.primary,
    borderRadius: BorderRadius.full,
  },
  overGoalFill: {
    backgroundColor: Colors.success,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  current: {
    fontSize: FontSize.xs,
    fontWeight: '600',
    color: Colors.text,
  },
  goal: {
    fontSize: FontSize.xs,
    color: Colors.textTertiary,
  },
});
