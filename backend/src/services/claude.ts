import Anthropic from '@anthropic-ai/sdk';
import { getAnthropicApiKey } from './secretManager';
import { logger } from './logger';
import { config } from '../config';

let anthropic: Anthropic | null = null;

async function getAnthropicClient(): Promise<Anthropic> {
  if (!anthropic) {
    const apiKey = await getAnthropicApiKey();
    anthropic = new Anthropic({ apiKey });
  }
  return anthropic;
}

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

export interface ChatResponse {
  content: string;
  model: string;
  usage: {
    input_tokens: number;
    output_tokens: number;
  };
}

export async function chat(
  messages: ChatMessage[],
  model: string = config.defaultModel,
  systemPrompt?: string,
  stream: boolean = false
): Promise<ChatResponse> {
  try {
    const client = await getAnthropicClient();

    const messageParams: Anthropic.MessageCreateParams = {
      model,
      max_tokens: 4096,
      messages: messages.map(msg => ({
        role: msg.role,
        content: msg.content,
      })),
    };

    if (systemPrompt) {
      messageParams.system = systemPrompt;
    }

    const response = await client.messages.create(messageParams);

    logger.info(
      {
        model,
        inputTokens: response.usage.input_tokens,
        outputTokens: response.usage.output_tokens,
      },
      'Claude API call completed'
    );

    const contentBlock = response.content[0];
    const content = contentBlock.type === 'text' ? contentBlock.text : '';

    return {
      content,
      model: response.model,
      usage: {
        input_tokens: response.usage.input_tokens,
        output_tokens: response.usage.output_tokens,
      },
    };
  } catch (error) {
    logger.error({ error, model }, 'Claude API call failed');
    throw error;
  }
}

export async function* chatStream(
  messages: ChatMessage[],
  model: string = config.defaultModel,
  systemPrompt?: string
): AsyncGenerator<string, void, unknown> {
  try {
    const client = await getAnthropicClient();

    const messageParams: Anthropic.MessageCreateParams = {
      model,
      max_tokens: 4096,
      messages: messages.map(msg => ({
        role: msg.role,
        content: msg.content,
      })),
      stream: true,
    };

    if (systemPrompt) {
      messageParams.system = systemPrompt;
    }

    const stream = await client.messages.create(messageParams);

    for await (const chunk of stream) {
      if (chunk.type === 'content_block_delta' && chunk.delta.type === 'text_delta') {
        yield chunk.delta.text;
      }
    }

    logger.info({ model }, 'Claude streaming completed');
  } catch (error) {
    logger.error({ error, model }, 'Claude streaming failed');
    throw error;
  }
}
