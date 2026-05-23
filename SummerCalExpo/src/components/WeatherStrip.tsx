import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Spacing, FontSize } from '../constants/theme';

function getWeatherEmoji(condition: string): string {
  const lower = condition.toLowerCase();
  if (lower.includes('sun') || lower.includes('clear')) return '☀️';
  if (lower.includes('cloud')) return '⛅';
  if (lower.includes('rain') || lower.includes('drizzle')) return '🌧️';
  if (lower.includes('snow')) return '🌨️';
  if (lower.includes('storm') || lower.includes('thunder')) return '⛈️';
  if (lower.includes('fog') || lower.includes('mist')) return '🌫️';
  if (lower.includes('wind')) return '💨';
  return '🌡️';
}

interface WeatherStripProps {
  condition: string;
  temperature: number;
  city: string;
}

export function WeatherStrip({ condition, temperature, city }: WeatherStripProps) {
  return (
    <View style={styles.container}>
      <Text style={styles.emoji}>{getWeatherEmoji(condition)}</Text>
      <Text style={styles.temp}>{temperature}°</Text>
      <Text style={styles.divider}>|</Text>
      <Text style={styles.city} numberOfLines={1}>
        {city}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Spacing.xs,
    paddingHorizontal: Spacing.lg,
  },
  emoji: {
    fontSize: FontSize.xl,
    marginRight: Spacing.sm,
  },
  temp: {
    fontSize: FontSize.lg,
    fontWeight: '600',
    color: Colors.text,
    marginRight: Spacing.sm,
  },
  divider: {
    fontSize: FontSize.lg,
    color: Colors.textTertiary,
    marginHorizontal: Spacing.sm,
  },
  city: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
    flex: 1,
  },
});
