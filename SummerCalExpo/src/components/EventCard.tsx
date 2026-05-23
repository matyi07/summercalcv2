import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';

export interface CalendarEvent {
  id: string;
  title: string;
  timeRange: string;
  location: string;
  category: 'work' | 'personal' | 'social' | 'health' | 'travel' | 'other';
  isOutdoor: boolean;
  hasNotification: boolean;
}

const categoryColors: Record<CalendarEvent['category'], string> = {
  work: '#007AFF',
  personal: '#FF9500',
  social: '#AF52DE',
  health: '#34C759',
  travel: '#5AC8FA',
  other: '#8E8E93',
};

interface EventCardProps {
  event: CalendarEvent;
  onPress: () => void;
}

export function EventCard({ event, onPress }: EventCardProps) {
  const borderColor = categoryColors[event.category];

  return (
    <TouchableOpacity
      style={[styles.container, { borderLeftColor: borderColor }]}
      onPress={onPress}
      activeOpacity={0.7}
    >
      <View style={styles.timeRow}>
        <Text style={styles.time}>{event.timeRange}</Text>
        <View style={styles.badges}>
          {event.isOutdoor && (
            <View style={styles.outdoorBadge}>
              <Text style={styles.outdoorText}>🌿 Outdoor</Text>
            </View>
          )}
          {event.hasNotification && (
            <View style={styles.notifyDot} />
          )}
        </View>
      </View>
      <Text style={styles.title} numberOfLines={1}>
        {event.title}
      </Text>
      <Text style={styles.location} numberOfLines={1}>
        📍 {event.location}
      </Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: Colors.card,
    borderRadius: BorderRadius.md,
    padding: Spacing.lg,
    borderLeftWidth: 4,
    marginVertical: Spacing.xs,
    ...Shadow.sm,
  },
  timeRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.xs,
  },
  time: {
    fontSize: FontSize.sm,
    fontWeight: '600',
    color: Colors.textSecondary,
  },
  badges: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  outdoorBadge: {
    backgroundColor: '#E8F5E9',
    paddingHorizontal: Spacing.sm,
    paddingVertical: 2,
    borderRadius: BorderRadius.sm,
  },
  outdoorText: {
    fontSize: FontSize.xs,
    color: '#2E7D32',
    fontWeight: '500',
  },
  notifyDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: Colors.error,
  },
  title: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.text,
    marginBottom: 4,
  },
  location: {
    fontSize: FontSize.sm,
    color: Colors.textSecondary,
  },
});
