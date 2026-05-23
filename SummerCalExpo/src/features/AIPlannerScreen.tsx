import React, { useState, useRef, useCallback, useEffect } from 'react';
import {
  View,
  Text,
  TextInput,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  ActivityIndicator,
} from 'react-native';
import * as SecureStore from 'expo-secure-store';
import { ChatBubble, ChatMessage } from '../components/ChatBubble';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';
import { useSettingsStore } from '../store/settingsStore';
import { AIProviderRouter, AIProviderClient } from '../services/AIProviderRouter';
import { AIMessage, AIRequestConfig, AIProviderKind } from '../models';

const STORAGE_KEY_PREFIX = 'ai_api_key_';

function getStorageKey(provider: string): string {
  return `${STORAGE_KEY_PREFIX}${provider}`;
}

function mapProviderKind(kind: string): AIProviderKind {
  switch (kind) {
    case 'openAI': return AIProviderKind.openAI;
    case 'claude': return AIProviderKind.claude;
    case 'deepSeek': return AIProviderKind.deepSeek;
    case 'openAICompatible': return AIProviderKind.openAICompatible;
    default: return AIProviderKind.openAI;
  }
}

const SHORTCUTS = [
  { label: 'Plan my free day', prompt: 'I have an entirely free day. Suggest a full schedule of activities for me.' },
  { label: 'Find something nearby', prompt: 'What are some interesting things to do near my current location?' },
  { label: 'Event prep help', prompt: 'Help me prepare for my upcoming event. What should I bring and do ahead of time?' },
  { label: 'Summarize my day', prompt: 'Summarize my scheduled events for today in a brief overview.' },
];

export function AIPlannerScreen() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputText, setInputText] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const flatListRef = useRef<FlatList>(null);
  const settings = useSettingsStore((s) => s.settings);

  function addMessage(role: 'user' | 'assistant', content: string) {
    const msg: ChatMessage = {
      id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
      role,
      content,
      timestamp: Date.now(),
    };
    setMessages((prev) => [...prev, msg]);
    return msg;
  }

  const scrollToBottom = useCallback(() => {
    setTimeout(() => {
      flatListRef.current?.scrollToEnd({ animated: true });
    }, 100);
  }, []);

  useEffect(() => {
    if (messages.length > 0) scrollToBottom();
  }, [messages.length, scrollToBottom]);

  function clearChat() {
    setMessages([]);
    setError(null);
  }

  async function sendMessage(text: string) {
    if (!text.trim() || loading) return;

    const cleanText = text.trim();
    setInputText('');
    setError(null);
    addMessage('user', cleanText);
    setLoading(true);

    try {
      if (!settings) {
        throw new Error('AI settings not configured. Check your settings.');
      }

      const providerKind = mapProviderKind(settings.aiProviderKind);
      const storageKey = getStorageKey(settings.aiProviderKind);
      const apiKey = await SecureStore.getItemAsync(storageKey);

      if (!apiKey) {
        throw new Error(`No API key found for ${settings.aiProviderKind}. Add it in Settings.`);
      }

      const router = new AIProviderRouter((provider: string) => {
        return provider === settings.aiProviderKind ? apiKey : null;
      });

      const client = router.getClient(providerKind, settings.aiBaseURL);
      if (!client) {
        throw new Error(`Could not create AI client for ${settings.aiProviderKind}.`);
      }

      const aiMessages: AIMessage[] = [
        { role: 'system', content: 'You are a helpful day planner assistant for the SummerCal app. Keep responses concise, practical, and actionable. Use emojis sparingly.' },
        ...messages.slice(-10).concat({ id: '', role: 'user' as const, content: cleanText, timestamp: Date.now() }).map((m) => ({
          role: m.role as 'user' | 'assistant',
          content: m.content,
        })),
      ];

      const config: AIRequestConfig = {
        model: settings.aiModelName,
        maxTokens: settings.aiMaxTokens,
        temperature: 0.7,
        baseURL: settings.aiBaseURL,
      };

      const response = await client.sendChat(aiMessages, config);
      const responseContent = response.content || 'Sorry, I received an empty response.';
      addMessage('assistant', responseContent);
    } catch (err: any) {
      const errorMsg = err?.message || 'An unexpected error occurred';
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  }

  function handleShortcut(prompt: string) {
    sendMessage(prompt);
  }

  const providerLabel = settings
    ? (() => {
        switch (settings.aiProviderKind) {
          case 'openAI': return 'OpenAI';
          case 'claude': return 'Claude';
          case 'deepSeek': return 'DeepSeek';
          case 'openAICompatible': return 'OpenAI Compatible';
          default: return settings.aiProviderKind;
        }
      })()
    : null;

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={90}
    >
      <View style={styles.header}>
        <Text style={styles.headerTitle}>AI Planner</Text>
        <View style={styles.headerRight}>
          {providerLabel && (
            <View style={styles.providerBadge}>
              <Text style={styles.providerText}>{providerLabel}</Text>
            </View>
          )}
          <TouchableOpacity onPress={clearChat} style={styles.clearButton} activeOpacity={0.7}>
            <Text style={styles.clearText}>Clear</Text>
          </TouchableOpacity>
        </View>
      </View>

      {error && (
        <View style={styles.errorBar}>
          <Text style={styles.errorText}>{error}</Text>
        </View>
      )}

      {messages.length === 0 ? (
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyIcon}>💬</Text>
          <Text style={styles.emptyTitle}>Ask me to plan your day</Text>
          <Text style={styles.emptySubtitle}>I can suggest activities, prep for events, or summarize your schedule</Text>
          <View style={styles.shortcutsContainer}>
            {SHORTCUTS.map((s) => (
              <TouchableOpacity
                key={s.label}
                style={styles.shortcutButton}
                onPress={() => handleShortcut(s.prompt)}
                activeOpacity={0.7}
              >
                <Text style={styles.shortcutText}>{s.label}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>
      ) : (
        <FlatList
          ref={flatListRef}
          data={messages}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => <ChatBubble message={item} />}
          contentContainerStyle={styles.chatList}
          showsVerticalScrollIndicator={false}
        />
      )}

      {loading && (
        <View style={styles.loadingContainer}>
          <ActivityIndicator color={Colors.primary} size="small" />
          <Text style={styles.loadingText}>AI is thinking...</Text>
        </View>
      )}

      <View style={styles.inputBar}>
        <TextInput
          style={styles.textInput}
          value={inputText}
          onChangeText={setInputText}
          placeholder="Ask anything..."
          placeholderTextColor={Colors.textTertiary}
          multiline
          maxLength={2000}
          returnKeyType="send"
          onSubmitEditing={() => sendMessage(inputText)}
          editable={!loading}
        />
        <TouchableOpacity
          style={[styles.sendButton, (!inputText.trim() || loading) && styles.sendButtonDisabled]}
          onPress={() => sendMessage(inputText)}
          disabled={!inputText.trim() || loading}
          activeOpacity={0.7}
        >
          <Text style={styles.sendText}>Send</Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.xxl,
    paddingBottom: Spacing.md,
    backgroundColor: Colors.card,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
    ...Shadow.sm,
  },
  headerTitle: {
    fontSize: FontSize.xxl,
    fontWeight: '700',
    color: Colors.text,
  },
  headerRight: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  providerBadge: {
    backgroundColor: Colors.primaryLight,
    paddingHorizontal: Spacing.sm,
    paddingVertical: Spacing.xs,
    borderRadius: BorderRadius.sm,
  },
  providerText: {
    fontSize: FontSize.xs,
    fontWeight: '600',
    color: Colors.primaryDark,
  },
  clearButton: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  clearText: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.error,
  },
  errorBar: {
    backgroundColor: '#FFEBEE',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: '#FFCDD2',
  },
  errorText: {
    fontSize: FontSize.sm,
    color: Colors.error,
    fontWeight: '500',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: Spacing.xxxl,
  },
  emptyIcon: {
    fontSize: 56,
    marginBottom: Spacing.lg,
  },
  emptyTitle: {
    fontSize: FontSize.xl,
    fontWeight: '700',
    color: Colors.text,
    textAlign: 'center',
    marginBottom: Spacing.sm,
  },
  emptySubtitle: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
    textAlign: 'center',
    marginBottom: Spacing.xxl,
    lineHeight: 22,
  },
  shortcutsContainer: {
    flexDirection: 'column',
    gap: Spacing.md,
    width: '100%',
  },
  shortcutButton: {
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.md,
    paddingVertical: Spacing.lg,
    paddingHorizontal: Spacing.xl,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: Colors.border,
  },
  shortcutText: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.primary,
  },
  chatList: {
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    flexGrow: 1,
  },
  loadingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: Spacing.sm,
    gap: Spacing.sm,
  },
  loadingText: {
    fontSize: FontSize.sm,
    color: Colors.textTertiary,
  },
  inputBar: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    backgroundColor: Colors.card,
    borderTopWidth: 1,
    borderTopColor: Colors.border,
    gap: Spacing.sm,
  },
  textInput: {
    flex: 1,
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.xl,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    fontSize: FontSize.md,
    color: Colors.text,
    maxHeight: 120,
  },
  sendButton: {
    backgroundColor: Colors.primary,
    borderRadius: BorderRadius.full,
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    justifyContent: 'center',
    alignItems: 'center',
  },
  sendButtonDisabled: {
    opacity: 0.4,
  },
  sendText: {
    fontSize: FontSize.md,
    fontWeight: '700',
    color: '#FFFFFF',
  },
});
