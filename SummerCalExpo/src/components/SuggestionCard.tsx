import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';

export interface ActivitySuggestion {
  id: string;
  title: string;
  summary: string;
  category: 'outdoor' | 'indoor' | 'food' | 'culture' | 'sports' | 'relax' | 'social';
  duration: string;
  cost: number;
}

const categoryIcons: Record<ActivitySuggestion['category'], string> = {
  outdoor: '🏔️',
  indoor: '🏠',
  food: '🍽️',
  culture: '🎭',
  sports: '⚽',
  relax: '🧘',
  social: '🎉',
};

interface SuggestionCardProps {
  suggestion: ActivitySuggestion;
  onPress: () => void;
}

export function SuggestionCard({ suggestion, onPress }: SuggestionCardProps) {
  const icon = categoryIcons[suggestion.category];
  const costDisplay = '$'.repeat(Math.max(1, Math.min(3, suggestion.cost)));

  return (
    <TouchableOpacity
      style={[styles.container, Shadow.sm]}
      onPress={onPress}
      activeOpacity={0.7}
    >
      <View style={styles.iconContainer}>
        <Text style={styles.icon}>{icon}</Text>
      </View>
      <View style={styles.info}>
        <Text style={styles.title} numberOfLines={1}>
          {suggestion.title}
        </Text>
        <Text style={styles.summary} numberOfLines={2}>
          {suggestion.summary}
        </Text>
        <View style={styles.meta}>
          <View style={styles.durationBadge}>
            <Text style={styles.durationText}>{suggestion.duration}</Text>
          </View>
          <Text style={styles.cost}>{costDisplay}</Text>
        </View>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    backgroundColor: Colors.card,
    borderRadius: BorderRadius.lg,
    padding: Spacing.lg,
    marginVertical: Spacing.xs,
    alignItems: 'center',
  },
  iconContainer: {
    width: 48,
    height: 48,
    borderRadius: BorderRadius.md,
    backgroundColor: Colors.surface,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: Spacing.md,
  },
  icon: {
    fontSize: FontSize.xxl,
  },
  info: {
    flex: 1,
  },
  title: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.text,
    marginBottom: 2,
  },
  summary: {
    fontSize: FontSize.sm,
    color: Colors.textSecondary,
    marginBottom: Spacing.sm,
    lineHeight: 18,
  },
  meta: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  durationBadge: {
    backgroundColor: Colors.surface,
    paddingHorizontal: Spacing.sm,
    paddingVertical: 2,
    borderRadius: BorderRadius.sm,
  },
  durationText: {
    fontSize: FontSize.xs,
    color: Colors.textSecondary,
    fontWeight: '500',
  },
  cost: {
    fontSize: FontSize.sm,
    color: Colors.primary,
    fontWeight: '600',
    letterSpacing: 1,
  },
});
