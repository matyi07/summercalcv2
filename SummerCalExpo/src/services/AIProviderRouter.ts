import { AIMessage, AIRequestConfig, AIResponse, AIProviderKind } from '../models';

export interface AIProviderClient {
  readonly providerName: string;
  sendChat(messages: AIMessage[], config: AIRequestConfig): Promise<AIResponse>;
}

class OpenAIClient implements AIProviderClient {
  readonly providerName = 'OpenAI';
  constructor(private apiKey: string) {}
  async sendChat(messages: AIMessage[], config: AIRequestConfig): Promise<AIResponse> {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this.apiKey}` },
      body: JSON.stringify({ model: config.model, messages, max_tokens: config.maxTokens, temperature: config.temperature }),
    });
    const json = await response.json();
    if (json.error) throw new Error(`OpenAI: ${json.error.message}`);
    return {
      content: json.choices?.[0]?.message?.content ?? '',
      finishReason: json.choices?.[0]?.finish_reason,
      tokenUsage: json.usage?.total_tokens,
    };
  }
}

class ClaudeClient implements AIProviderClient {
  readonly providerName = 'Claude';
  constructor(private apiKey: string) {}
  async sendChat(messages: AIMessage[], config: AIRequestConfig): Promise<AIResponse> {
    const systemMessages = messages.filter(m => m.role === 'system').map(m => m.content);
    const chatMessages = messages.filter(m => m.role !== 'system').map(m => ({ role: m.role, content: m.content }));
    const body: any = { model: config.model, max_tokens: config.maxTokens, messages: chatMessages };
    if (systemMessages.length) body.system = systemMessages.join('\n');

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-api-key': this.apiKey, 'anthropic-version': '2023-06-01' },
      body: JSON.stringify(body),
    });
    const json = await response.json();
    if (json.error) throw new Error(`Claude: ${json.error.message}`);
    const textBlocks = (json.content ?? []).filter((b: any) => b.type === 'text').map((b: any) => b.text);
    return { content: textBlocks.join('\n'), finishReason: json.stop_reason, tokenUsage: json.usage?.input_tokens };
  }
}

class DeepSeekClient implements AIProviderClient {
  readonly providerName = 'DeepSeek';
  constructor(private apiKey: string) {}
  async sendChat(messages: AIMessage[], config: AIRequestConfig): Promise<AIResponse> {
    const response = await fetch('https://api.deepseek.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this.apiKey}` },
      body: JSON.stringify({ model: config.model, messages, max_tokens: config.maxTokens, temperature: config.temperature }),
    });
    const json = await response.json();
    if (json.error) throw new Error(`DeepSeek: ${json.error.message}`);
    return {
      content: json.choices?.[0]?.message?.content ?? '',
      finishReason: json.choices?.[0]?.finish_reason,
      tokenUsage: json.usage?.total_tokens,
    };
  }
}

class OpenAICompatibleClient implements AIProviderClient {
  get providerName(): string { return `OpenAI Compatible (${this.baseUrl})`; }
  constructor(private apiKey: string, private baseUrl: string) {}
  async sendChat(messages: AIMessage[], config: AIRequestConfig): Promise<AIResponse> {
    const url = `${this.baseUrl.replace(/\/$/, '')}/v1/chat/completions`;
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this.apiKey}` },
      body: JSON.stringify({ model: config.model, messages, max_tokens: config.maxTokens, temperature: config.temperature }),
    });
    const json = await response.json();
    return {
      content: json.choices?.[0]?.message?.content ?? '',
      finishReason: json.choices?.[0]?.finish_reason,
      tokenUsage: json.usage?.total_tokens,
    };
  }
}

export class AIProviderRouter {
  constructor(private getApiKey: (provider: string) => string | null) {}

  getClient(provider: AIProviderKind, baseURL?: string | null): AIProviderClient | null {
    const key = this.getApiKey(provider);
    if (!key) return null;
    switch (provider) {
      case AIProviderKind.openAI: return new OpenAIClient(key);
      case AIProviderKind.claude: return new ClaudeClient(key);
      case AIProviderKind.deepSeek: return new DeepSeekClient(key);
      case AIProviderKind.openAICompatible: return new OpenAICompatibleClient(key, baseURL ?? 'https://api.openai.com');
    }
  }
}
