import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Spacing, FontSize, BorderRadius } from '../constants/theme';

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
}

interface ChatBubbleProps {
  message: ChatMessage;
}

export function ChatBubble({ message }: ChatBubbleProps) {
  const isUser = message.role === 'user';

  return (
    <View style={[styles.wrapper, isUser ? styles.wrapperRight : styles.wrapperLeft]}>
      <View
        style={[
          styles.bubble,
          isUser ? styles.bubbleUser : styles.bubbleAssistant,
        ]}
      >
        <Text
          style={[
            styles.text,
            isUser ? styles.textUser : styles.textAssistant,
          ]}
        >
          {message.content}
        </Text>
      </View>
      <Text style={[styles.timestamp, isUser ? styles.timestampRight : styles.timestampLeft]}>
        {formatTimestamp(message.timestamp)}
      </Text>
    </View>
  );
}

function formatTimestamp(ts: number): string {
  const date = new Date(ts);
  const hours = date.getHours().toString().padStart(2, '0');
  const minutes = date.getMinutes().toString().padStart(2, '0');
  return `${hours}:${minutes}`;
}

const styles = StyleSheet.create({
  wrapper: {
    marginVertical: Spacing.xs,
    maxWidth: '80%',
  },
  wrapperLeft: {
    alignSelf: 'flex-start',
  },
  wrapperRight: {
    alignSelf: 'flex-end',
  },
  bubble: {
    borderRadius: BorderRadius.lg,
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
  },
  bubbleUser: {
    backgroundColor: Colors.info,
    borderBottomRightRadius: BorderRadius.sm,
  },
  bubbleAssistant: {
    backgroundColor: Colors.surface,
    borderBottomLeftRadius: BorderRadius.sm,
  },
  text: {
    fontSize: FontSize.md,
    lineHeight: 20,
  },
  textUser: {
    color: '#FFFFFF',
  },
  textAssistant: {
    color: Colors.text,
  },
  timestamp: {
    fontSize: FontSize.xs,
    color: Colors.textTertiary,
    marginTop: 2,
  },
  timestampLeft: {
    textAlign: 'left',
    paddingLeft: Spacing.sm,
  },
  timestampRight: {
    textAlign: 'right',
    paddingRight: Spacing.sm,
  },
});
