import axios from 'axios';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

const api = axios.create({
  baseURL: `${API_URL}/api`,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true,
});

export interface Message {
  id: string;
  conversationId: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: Date;
}

export interface Conversation {
  id: string;
  userId: string;
  title: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface ChatResponse {
  conversationId: string;
  message: string;
  model: string;
  usage: {
    input_tokens: number;
    output_tokens: number;
  };
}

export async function fetchConversations(): Promise<Conversation[]> {
  const response = await api.get('/session/conversations');
  return response.data.conversations;
}

export async function fetchConversation(conversationId: string): Promise<{
  conversation: Conversation;
  messages: Message[];
}> {
  const response = await api.get(`/session/conversations/${conversationId}`);
  return response.data;
}

export async function sendMessage(
  message: string,
  conversationId?: string,
  model?: string
): Promise<ChatResponse> {
  const response = await api.post('/chat', {
    message,
    conversationId,
    model,
    stream: false,
  });
  return response.data;
}

export async function createConversation(title: string): Promise<Conversation> {
  const response = await api.post('/session/conversations', { title });
  return response.data.conversation;
}

export async function updateConversation(
  conversationId: string,
  updates: { title?: string }
): Promise<void> {
  await api.patch(`/session/conversations/${conversationId}`, updates);
}

export async function getCurrentUser(): Promise<{
  id: string;
  email: string;
  groups?: string[];
}> {
  const response = await api.get('/session/user');
  return response.data.user;
}

export async function startResearch(
  query: string,
  conversationId?: string,
  depth: 'quick' | 'standard' | 'deep' = 'standard'
): Promise<{
  conversationId: string;
  result: string;
  sources: any[];
}> {
  const response = await api.post('/chat/research', {
    query,
    conversationId,
    depth,
  });
  return response.data;
}
