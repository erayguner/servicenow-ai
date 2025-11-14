'use client'

import { useState, useEffect, useRef } from 'react'
import { fetchConversation, sendMessage, Message } from '@/lib/api'
import ReactMarkdown from 'react-markdown'

interface ChatInterfaceProps {
  conversationId: string | null
  onConversationCreated: (conversationId: string) => void
}

export default function ChatInterface({
  conversationId,
  onConversationCreated,
}: ChatInterfaceProps) {
  const [messages, setMessages] = useState<Message[]>([])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const messagesEndRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (conversationId) {
      loadConversation()
    } else {
      setMessages([])
    }
  }, [conversationId])

  useEffect(() => {
    scrollToBottom()
  }, [messages])

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  const loadConversation = async () => {
    if (!conversationId) return

    try {
      setLoading(true)
      const data = await fetchConversation(conversationId)
      setMessages(data.messages)
      setError(null)
    } catch (err) {
      setError('Failed to load conversation')
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!input.trim() || loading) return

    const userMessage = input.trim()
    setInput('')
    setError(null)

    // Optimistically add user message
    const tempUserMessage: Message = {
      id: Date.now().toString(),
      conversationId: conversationId || '',
      role: 'user',
      content: userMessage,
      timestamp: new Date(),
    }
    setMessages((prev) => [...prev, tempUserMessage])

    try {
      setLoading(true)
      const response = await sendMessage(userMessage, conversationId || undefined)

      // If this is a new conversation, notify parent
      if (!conversationId) {
        onConversationCreated(response.conversationId)
      }

      // Replace temp message and add assistant response
      setMessages((prev) => [
        ...prev.slice(0, -1),
        { ...tempUserMessage, id: Date.now().toString() },
        {
          id: Date.now().toString(),
          conversationId: response.conversationId,
          role: 'assistant',
          content: response.message,
          timestamp: new Date(),
        },
      ])
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to send message')
      console.error(err)
      // Remove optimistic message on error
      setMessages((prev) => prev.slice(0, -1))
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex-1 flex flex-col">
      {/* Header */}
      <div className="bg-white border-b border-gray-200 p-4">
        <h2 className="text-xl font-semibold text-gray-800">
          {conversationId ? 'Conversation' : 'New Conversation'}
        </h2>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.length === 0 && !loading && (
          <div className="text-center text-gray-400 mt-8">
            <p className="text-lg">Start a conversation</p>
            <p className="text-sm mt-2">
              Ask me anything or request in-depth research
            </p>
          </div>
        )}

        {messages.map((message) => (
          <div
            key={message.id}
            className={`message flex ${
              message.role === 'user' ? 'justify-end' : 'justify-start'
            }`}
          >
            <div
              className={`max-w-3xl rounded-lg p-4 ${
                message.role === 'user'
                  ? 'bg-blue-600 text-white'
                  : 'bg-white border border-gray-200 text-gray-800'
              }`}
            >
              {message.role === 'assistant' ? (
                <div className="prose prose-sm max-w-none">
                  <ReactMarkdown>{message.content}</ReactMarkdown>
                </div>
              ) : (
                <div className="whitespace-pre-wrap">{message.content}</div>
              )}
            </div>
          </div>
        ))}

        {loading && messages.length > 0 && (
          <div className="flex justify-start">
            <div className="bg-white border border-gray-200 rounded-lg p-4">
              <div className="flex space-x-2">
                <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
                <div
                  className="w-2 h-2 bg-gray-400 rounded-full animate-bounce"
                  style={{ animationDelay: '0.1s' }}
                ></div>
                <div
                  className="w-2 h-2 bg-gray-400 rounded-full animate-bounce"
                  style={{ animationDelay: '0.2s' }}
                ></div>
              </div>
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* Error message */}
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 mx-4 rounded">
          {error}
        </div>
      )}

      {/* Input */}
      <div className="bg-white border-t border-gray-200 p-4">
        <form onSubmit={handleSubmit} className="flex space-x-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Type your message..."
            disabled={loading}
            className="flex-1 border border-gray-300 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-100 text-gray-800"
          />
          <button
            type="submit"
            disabled={loading || !input.trim()}
            className="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white font-semibold px-6 py-2 rounded-lg transition-colors"
          >
            {loading ? 'Sending...' : 'Send'}
          </button>
        </form>
      </div>
    </div>
  )
}
