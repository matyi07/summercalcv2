import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { Colors, Spacing, FontSize, BorderRadius } from '../constants/theme';

interface FreeDayBannerProps {
  message: string;
  onGetSuggestions: () => void;
}

export function FreeDayBanner({ message, onGetSuggestions }: FreeDayBannerProps) {
  return (
    <View style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.emoji}>☀️</Text>
        <Text style={styles.message}>{message}</Text>
      </View>
      <TouchableOpacity style={styles.button} onPress={onGetSuggestions} activeOpacity={0.7}>
        <Text style={styles.buttonText}>Get Suggestions</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: Colors.primaryLight,
    borderRadius: BorderRadius.lg,
    padding: Spacing.xl,
    alignItems: 'center',
    marginVertical: Spacing.sm,
    borderWidth: 1,
    borderColor: Colors.primary,
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: Spacing.md,
  },
  emoji: {
    fontSize: FontSize.xxl,
    marginRight: Spacing.sm,
  },
  message: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.text,
    flex: 1,
    flexWrap: 'wrap',
  },
  button: {
    backgroundColor: Colors.primary,
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xxxl,
    borderRadius: BorderRadius.full,
  },
  buttonText: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: '#FFFFFF',
  },
});
