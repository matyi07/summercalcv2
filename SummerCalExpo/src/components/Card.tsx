import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ViewStyle,
  TextStyle,
} from 'react-native';
import { Colors, Spacing, BorderRadius, Shadow, FontSize } from '../constants/theme';

interface CardProps {
  title?: string;
  subtitle?: string;
  icon?: string;
  onPress?: () => void;
  style?: ViewStyle;
  titleStyle?: TextStyle;
  subtitleStyle?: TextStyle;
  children?: React.ReactNode;
}

export function Card({
  title,
  subtitle,
  icon,
  onPress,
  style,
  titleStyle,
  subtitleStyle,
  children,
}: CardProps) {
  const content = (
    <>
      {(title || icon) && (
        <View style={styles.header}>
          {icon && <Text style={styles.icon}>{icon}</Text>}
          <View style={styles.headerText}>
            {title && (
              <Text style={[styles.title, titleStyle]}>{title}</Text>
            )}
            {subtitle && (
              <Text style={[styles.subtitle, subtitleStyle]}>{subtitle}</Text>
            )}
          </View>
        </View>
      )}
      {children && <View style={styles.content}>{children}</View>}
    </>
  );

  if (onPress) {
    return (
      <TouchableOpacity
        style={[styles.container, style]}
        onPress={onPress}
        activeOpacity={0.7}
      >
        {content}
      </TouchableOpacity>
    );
  }

  return <View style={[styles.container, style]}>{content}</View>;
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: Colors.card,
    borderRadius: BorderRadius.lg,
    padding: Spacing.lg,
    ...Shadow.md,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: Spacing.sm,
  },
  icon: {
    fontSize: FontSize.xxl,
    marginRight: Spacing.md,
  },
  headerText: {
    flex: 1,
  },
  title: {
    fontSize: FontSize.lg,
    fontWeight: '600',
    color: Colors.text,
  },
  subtitle: {
    fontSize: FontSize.sm,
    color: Colors.textSecondary,
    marginTop: 2,
  },
  content: {
    marginTop: Spacing.sm,
  },
});
