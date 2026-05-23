import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TextInput,
  TouchableOpacity,
  Alert,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useDatabase } from '../hooks/useDatabase';
import { useSettingsStore } from '../store/settingsStore';
import { AIProviderKind, AIMessage } from '../models';
import { AIProviderRouter } from '../services/AIProviderRouter';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';
import * as SecureStore from 'expo-secure-store';

const PROVIDERS: { key: AIProviderKind; label: string }[] = [
  { key: AIProviderKind.openAI, label: 'OpenAI' },
  { key: AIProviderKind.claude, label: 'Claude' },
  { key: AIProviderKind.deepSeek, label: 'DeepSeek' },
  { key: AIProviderKind.openAICompatible, label: 'Compatible' },
];

const MODELS: Record<AIProviderKind, string[]> = {
  [AIProviderKind.openAI]: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'],
  [AIProviderKind.claude]: ['claude-3-5-sonnet-20241022', 'claude-3-haiku-20240307', 'claude-3-opus-20240229'],
  [AIProviderKind.deepSeek]: ['deepseek-chat', 'deepseek-reasoner'],
  [AIProviderKind.openAICompatible]: [],
};

async function getApiKey(provider: string): Promise<string | null> {
  const key = await SecureStore.getItemAsync(`ai_api_key_${provider}`);
  return key;
}

async function setApiKey(provider: string, key: string): Promise<void> {
  await SecureStore.setItemAsync(`ai_api_key_${provider}`, key);
}

export function AISettingsScreen() {
  const insets = useSafeAreaInsets();
  const { db } = useDatabase();
  const { settings, updateSetting } = useSettingsStore();

  const [provider, setProvider] = useState<AIProviderKind>(AIProviderKind.openAI);
  const [modelName, setModelName] = useState('gpt-4o');
  const [baseURL, setBaseURL] = useState('');
  const [apiKey, setApiKey] = useState('');
  const [maxTokens, setMaxTokens] = useState('1024');
  const [testing, setTesting] = useState(false);

  useEffect(() => {
    if (settings) {
      setProvider(settings.aiProviderKind as AIProviderKind);
      setModelName(settings.aiModelName);
      setBaseURL(settings.aiBaseURL ?? '');
      setMaxTokens(settings.aiMaxTokens?.toString() ?? '1024');
    }
  }, [settings]);

  useEffect(() => {
    (async () => {
      const key = await getApiKey(provider);
      setApiKey(key ?? '');
    })();
  }, [provider]);

  const handleSave = useCallback(async () => {
    if (!db) return;
    const tokens = parseInt(maxTokens, 10) || 1024;
    await db.runAsync(
      `UPDATE user_settings SET ai_provider_kind=?, ai_model_name=?, ai_base_url=?, ai_max_tokens=?, updated_at=? WHERE id='default'`,
      [provider, modelName, baseURL || null, tokens, new Date().toISOString()]
    );
    updateSetting({
      aiProviderKind: provider,
      aiModelName: modelName,
      aiBaseURL: baseURL || undefined,
      aiMaxTokens: tokens,
    });
    if (apiKey) {
      await setApiKey(provider, apiKey);
    }
    Alert.alert('Saved', 'AI settings saved successfully.');
  }, [db, provider, modelName, baseURL, apiKey, maxTokens, updateSetting]);

  const handleTestConnection = useCallback(async () => {
    setTesting(true);
    try {
      const router = new AIProviderRouter(async (p) => {
        const key = await SecureStore.getItemAsync(`ai_api_key_${p}`);
        return key;
      });

      const client = router.getClient(provider, baseURL || null);
      if (!client) {
        Alert.alert('Error', 'No API key configured for this provider.');
        setTesting(false);
        return;
      }

      const testMessages: AIMessage[] = [
        { role: 'user', content: 'Reply with just "OK" if you receive this.' },
      ];
      const response = await client.sendChat(testMessages, {
        model: modelName,
        maxTokens: parseInt(maxTokens, 10) || 1024,
        temperature: 0,
        baseURL: baseURL || undefined,
      });

      if (response.content) {
        Alert.alert('Success', `Connection successful! Response: "${response.content.trim()}"`);
      } else {
        Alert.alert('Warning', 'Received empty response from provider.');
      }
    } catch (err: any) {
      Alert.alert('Connection Failed', err?.message ?? 'Unknown error occurred.');
    } finally {
      setTesting(false);
    }
  }, [provider, modelName, baseURL, maxTokens]);

  const availableModels = MODELS[provider];

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
        <Text style={styles.sectionHeader}>AI Provider</Text>

        <View style={styles.segmentRow}>
          {PROVIDERS.map((p) => (
            <TouchableOpacity
              key={p.key}
              style={[
                styles.segment,
                provider === p.key && styles.segmentActive,
                p.key === PROVIDERS[0].key && styles.segmentFirst,
                p.key === PROVIDERS[PROVIDERS.length - 1].key && styles.segmentLast,
              ]}
              onPress={() => setProvider(p.key)}
            >
              <Text style={[styles.segmentText, provider === p.key && styles.segmentTextActive]}>
                {p.label}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        <Text style={styles.label}>Model</Text>
        {availableModels.length > 0 ? (
          <View style={styles.chipRow}>
            {availableModels.map((m) => (
              <TouchableOpacity
                key={m}
                style={[styles.chip, modelName === m && styles.chipActive]}
                onPress={() => setModelName(m)}
              >
                <Text style={[styles.chipText, modelName === m && styles.chipTextActive]} numberOfLines={1}>
                  {m}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        ) : null}
        <TextInput
          style={styles.input}
          value={modelName}
          onChangeText={setModelName}
          placeholder="Model name (e.g. gpt-4o)"
          placeholderTextColor={Colors.textTertiary}
        />

        {provider === AIProviderKind.openAICompatible && (
          <>
            <Text style={styles.label}>Base URL</Text>
            <TextInput
              style={styles.input}
              value={baseURL}
              onChangeText={setBaseURL}
              placeholder="https://api.example.com"
              placeholderTextColor={Colors.textTertiary}
              autoCapitalize="none"
              autoCorrect={false}
              keyboardType="url"
            />
          </>
        )}

        <Text style={styles.label}>API Key</Text>
        <TextInput
          style={styles.input}
          value={apiKey}
          onChangeText={setApiKey}
          placeholder="sk-..."
          placeholderTextColor={Colors.textTertiary}
          secureTextEntry
          autoCapitalize="none"
          autoCorrect={false}
        />

        <Text style={styles.label}>Max Tokens</Text>
        <TextInput
          style={styles.input}
          value={maxTokens}
          onChangeText={setMaxTokens}
          keyboardType="number-pad"
          placeholder="1024"
          placeholderTextColor={Colors.textTertiary}
        />

        <View style={styles.buttonRow}>
          <TouchableOpacity
            style={[styles.testBtn, testing && styles.testBtnDisabled]}
            onPress={handleTestConnection}
            disabled={testing}
          >
            <Text style={styles.testBtnText}>{testing ? 'Testing...' : 'Test Connection'}</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.saveBtn} onPress={handleSave}>
            <Text style={styles.saveBtnText}>Save</Text>
          </TouchableOpacity>
        </View>

        <View style={{ height: 60 }} />
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  scroll: {
    flex: 1,
  },
  content: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.xxxl,
  },
  sectionHeader: {
    fontSize: FontSize.sm,
    fontWeight: '600',
    color: Colors.textTertiary,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: Spacing.md,
    marginTop: Spacing.xl,
  },
  segmentRow: {
    flexDirection: 'row',
    borderRadius: BorderRadius.md,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: Colors.border,
  },
  segment: {
    flex: 1,
    paddingVertical: Spacing.md,
    alignItems: 'center',
    backgroundColor: Colors.surface,
    borderRightWidth: 1,
    borderRightColor: Colors.border,
  },
  segmentActive: {
    backgroundColor: Colors.primary,
  },
  segmentFirst: {
    borderTopLeftRadius: BorderRadius.md - 1,
    borderBottomLeftRadius: BorderRadius.md - 1,
  },
  segmentLast: {
    borderTopRightRadius: BorderRadius.md - 1,
    borderBottomRightRadius: BorderRadius.md - 1,
    borderRightWidth: 0,
  },
  segmentText: {
    fontSize: FontSize.xs,
    fontWeight: '600',
    color: Colors.text,
  },
  segmentTextActive: {
    color: '#FFFFFF',
  },
  label: {
    fontSize: FontSize.sm,
    fontWeight: '600',
    color: Colors.textSecondary,
    marginTop: Spacing.lg,
    marginBottom: Spacing.sm,
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
  chipRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.sm,
    marginBottom: Spacing.sm,
  },
  chip: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.full,
    backgroundColor: Colors.surface,
    borderWidth: 1,
    borderColor: Colors.border,
    maxWidth: 180,
  },
  chipActive: {
    backgroundColor: Colors.primary,
    borderColor: Colors.primary,
  },
  chipText: {
    fontSize: FontSize.xs,
    color: Colors.text,
    fontWeight: '500',
  },
  chipTextActive: {
    color: '#FFFFFF',
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: Spacing.xxl,
    gap: Spacing.md,
  },
  testBtn: {
    flex: 1,
    paddingVertical: Spacing.lg,
    borderRadius: BorderRadius.md,
    backgroundColor: Colors.surface,
    borderWidth: 1,
    borderColor: Colors.primary,
    alignItems: 'center',
  },
  testBtnDisabled: {
    opacity: 0.5,
  },
  testBtnText: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.primary,
  },
  saveBtn: {
    flex: 1,
    paddingVertical: Spacing.lg,
    borderRadius: BorderRadius.md,
    backgroundColor: Colors.primary,
    alignItems: 'center',
  },
  saveBtnText: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: '#FFFFFF',
  },
});
