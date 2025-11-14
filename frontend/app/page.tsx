'use client'

import { useState, useEffect } from 'react'
import ChatInterface from '@/components/ChatInterface'
import Sidebar from '@/components/Sidebar'
import { fetchConversations, Conversation } from '@/lib/api'

export default function Home() {
  const [conversations, setConversations] = useState<Conversation[]>([])
  const [currentConversationId, setCurrentConversationId] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadConversations()
  }, [])

  const loadConversations = async () => {
    try {
      const data = await fetchConversations()
      setConversations(data)
    } catch (error) {
      console.error('Failed to load conversations:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleNewConversation = () => {
    setCurrentConversationId(null)
  }

  const handleSelectConversation = (conversationId: string) => {
    setCurrentConversationId(conversationId)
  }

  const handleConversationCreated = (conversationId: string) => {
    setCurrentConversationId(conversationId)
    loadConversations()
  }

  return (
    <div className="flex h-screen bg-gray-100">
      <Sidebar
        conversations={conversations}
        currentConversationId={currentConversationId}
        onNewConversation={handleNewConversation}
        onSelectConversation={handleSelectConversation}
        loading={loading}
      />
      <ChatInterface
        conversationId={currentConversationId}
        onConversationCreated={handleConversationCreated}
      />
    </div>
  )
}
