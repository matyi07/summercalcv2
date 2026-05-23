import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';

export interface PlaceCandidate {
  id: string;
  name: string;
  category: string;
  address: string;
  isOpen: boolean;
  rating: number;
  distance: number;
}

function getCategoryIcon(category: string): string {
  const lower = category.toLowerCase();
  if (lower.includes('restaurant') || lower.includes('cafe') || lower.includes('food')) return '🍽️';
  if (lower.includes('park') || lower.includes('garden')) return '🌳';
  if (lower.includes('museum') || lower.includes('gallery')) return '🏛️';
  if (lower.includes('beach') || lower.includes('lake')) return '🏖️';
  if (lower.includes('gym') || lower.includes('sports')) return '🏋️';
  if (lower.includes('bar') || lower.includes('pub')) return '🍺';
  if (lower.includes('shopping') || lower.includes('mall')) return '🛍️';
  if (lower.includes('hotel') || lower.includes('lodging')) return '🏨';
  if (lower.includes('theatre') || lower.includes('cinema')) return '🎬';
  return '📍';
}

function renderStars(rating: number): string {
  const full = Math.floor(rating);
  const half = rating - full >= 0.5 ? 1 : 0;
  return '★'.repeat(full) + (half ? '½' : '') + '☆'.repeat(5 - full - half);
}

function formatDistance(meters: number): string {
  if (meters >= 1000) {
    return `${(meters / 1000).toFixed(1)} km`;
  }
  return `${Math.round(meters)} m`;
}

interface PlaceCardProps {
  place: PlaceCandidate;
  onPress: () => void;
}

export function PlaceCard({ place, onPress }: PlaceCardProps) {
  return (
    <TouchableOpacity
      style={[styles.container, Shadow.sm]}
      onPress={onPress}
      activeOpacity={0.7}
    >
      <View style={styles.iconContainer}>
        <Text style={styles.icon}>{getCategoryIcon(place.category)}</Text>
      </View>
      <View style={styles.info}>
        <View style={styles.nameRow}>
          <Text style={styles.name} numberOfLines={1}>
            {place.name}
          </Text>
          <View
            style={[
              styles.openBadge,
              { backgroundColor: place.isOpen ? '#E8F5E9' : '#FFEBEE' },
            ]}
          >
            <Text
              style={[
                styles.openText,
                { color: place.isOpen ? '#2E7D32' : '#C62828' },
              ]}
            >
              {place.isOpen ? 'Open' : 'Closed'}
            </Text>
          </View>
        </View>
        <Text style={styles.address} numberOfLines={1}>
          {place.address}
        </Text>
        <View style={styles.meta}>
          <Text style={styles.stars}>
            {renderStars(place.rating)}
            <Text style={styles.ratingNum}> {place.rating.toFixed(1)}</Text>
          </Text>
          <Text style={styles.distance}>{formatDistance(place.distance)}</Text>
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
    width: 44,
    height: 44,
    borderRadius: BorderRadius.md,
    backgroundColor: Colors.surface,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: Spacing.md,
  },
  icon: {
    fontSize: FontSize.xl,
  },
  info: {
    flex: 1,
  },
  nameRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 2,
  },
  name: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.text,
    flex: 1,
    marginRight: Spacing.sm,
  },
  openBadge: {
    paddingHorizontal: Spacing.sm,
    paddingVertical: 2,
    borderRadius: BorderRadius.sm,
  },
  openText: {
    fontSize: FontSize.xs,
    fontWeight: '600',
  },
  address: {
    fontSize: FontSize.sm,
    color: Colors.textSecondary,
    marginBottom: Spacing.xs,
  },
  meta: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  stars: {
    fontSize: FontSize.sm,
    color: Colors.warning,
  },
  ratingNum: {
    fontSize: FontSize.xs,
    color: Colors.textSecondary,
    fontWeight: '500',
  },
  distance: {
    fontSize: FontSize.xs,
    color: Colors.textTertiary,
    fontWeight: '500',
  },
});
