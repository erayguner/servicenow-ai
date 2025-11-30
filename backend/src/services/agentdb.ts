import { Firestore } from '@google-cloud/firestore';
import { config } from '../config';
import { v4 as uuidv4 } from 'uuid';
import { logger } from './logger';

const firestore = new Firestore({
  projectId: config.projectId,
  databaseId: config.firestoreDatabase,
});

export interface Message {
  id: string;
  conversationId: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: Date;
  metadata?: Record<string, any>;
}

export interface Conversation {
  id: string;
  userId: string;
  title: string;
  createdAt: Date;
  updatedAt: Date;
  metadata?: Record<string, any>;
}

export interface Document {
  id: string;
  title: string;
  content: string;
  embedding?: number[];
  metadata?: Record<string, any>;
  createdAt: Date;
}

export class AgentDB {
  private conversationsCollection = firestore.collection('conversations');
  private messagesCollection = firestore.collection('messages');
  private documentsCollection = firestore.collection('documents');

  // Conversation operations
  async createConversation(userId: string, title: string): Promise<Conversation> {
    const conversation: Conversation = {
      id: uuidv4(),
      userId,
      title,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    await this.conversationsCollection.doc(conversation.id).set(conversation);
    logger.info({ conversationId: conversation.id }, 'Conversation created');

    return conversation;
  }

  async getConversation(conversationId: string): Promise<Conversation | null> {
    const doc = await this.conversationsCollection.doc(conversationId).get();

    if (!doc.exists) {
      return null;
    }

    return doc.data() as Conversation;
  }

  async getUserConversations(userId: string, limit = 50): Promise<Conversation[]> {
    const snapshot = await this.conversationsCollection
      .where('userId', '==', userId)
      .orderBy('updatedAt', 'desc')
      .limit(limit)
      .get();

    return snapshot.docs.map((doc) => doc.data() as Conversation);
  }

  async updateConversation(conversationId: string, updates: Partial<Conversation>): Promise<void> {
    await this.conversationsCollection.doc(conversationId).update({
      ...updates,
      updatedAt: new Date(),
    });

    logger.info({ conversationId }, 'Conversation updated');
  }

  // Message operations
  async addMessage(message: Omit<Message, 'id' | 'timestamp'>): Promise<Message> {
    const newMessage: Message = {
      id: uuidv4(),
      ...message,
      timestamp: new Date(),
    };

    await this.messagesCollection.doc(newMessage.id).set(newMessage);

    // Update conversation timestamp
    await this.updateConversation(message.conversationId, {});

    logger.info(
      { messageId: newMessage.id, conversationId: message.conversationId },
      'Message added'
    );

    return newMessage;
  }

  async getConversationMessages(conversationId: string, limit = 100): Promise<Message[]> {
    const snapshot = await this.messagesCollection
      .where('conversationId', '==', conversationId)
      .orderBy('timestamp', 'asc')
      .limit(limit)
      .get();

    return snapshot.docs.map((doc) => doc.data() as Message);
  }

  async getRecentMessages(conversationId: string, count: number): Promise<Message[]> {
    const snapshot = await this.messagesCollection
      .where('conversationId', '==', conversationId)
      .orderBy('timestamp', 'desc')
      .limit(count)
      .get();

    return snapshot.docs.map((doc) => doc.data() as Message).reverse();
  }

  // Document operations (for RAG)
  async storeDocument(doc: Omit<Document, 'id' | 'createdAt'>): Promise<Document> {
    const newDoc: Document = {
      id: uuidv4(),
      ...doc,
      createdAt: new Date(),
    };

    await this.documentsCollection.doc(newDoc.id).set(newDoc);
    logger.info({ documentId: newDoc.id }, 'Document stored');

    return newDoc;
  }

  async searchDocuments(query: string, limit = 10): Promise<Document[]> {
    // Basic text search - in production, use vector search with embeddings
    const snapshot = await this.documentsCollection
      .where('content', '>=', query)
      .where('content', '<=', query + '\uf8ff')
      .limit(limit)
      .get();

    return snapshot.docs.map((doc) => doc.data() as Document);
  }

  async getDocumentById(documentId: string): Promise<Document | null> {
    const doc = await this.documentsCollection.doc(documentId).get();

    if (!doc.exists) {
      return null;
    }

    return doc.data() as Document;
  }
}

export const agentdb = new AgentDB();
