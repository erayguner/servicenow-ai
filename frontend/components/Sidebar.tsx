'use client'

import { Conversation } from '@/lib/api'
import { formatDistanceToNow } from 'date-fns'

interface SidebarProps {
  conversations: Conversation[]
  currentConversationId: string | null
  onNewConversation: () => void
  onSelectConversation: (conversationId: string) => void
  loading: boolean
}

export default function Sidebar({
  conversations,
  currentConversationId,
  onNewConversation,
  onSelectConversation,
  loading,
}: SidebarProps) {
  return (
    <div className="w-64 bg-gray-900 text-white flex flex-col">
      <div className="p-4 border-b border-gray-700">
        <h1 className="text-xl font-bold">AI Research Assistant</h1>
      </div>

      <div className="p-4">
        <button
          onClick={onNewConversation}
          className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded transition-colors"
        >
          + New Conversation
        </button>
      </div>

      <div className="flex-1 overflow-y-auto">
        {loading ? (
          <div className="p-4 text-gray-400">Loading conversations...</div>
        ) : conversations.length === 0 ? (
          <div className="p-4 text-gray-400">No conversations yet</div>
        ) : (
          <div className="space-y-1">
            {conversations.map((conversation) => (
              <button
                key={conversation.id}
                onClick={() => onSelectConversation(conversation.id)}
                className={`w-full text-left p-3 hover:bg-gray-800 transition-colors ${
                  currentConversationId === conversation.id ? 'bg-gray-800' : ''
                }`}
              >
                <div className="font-medium truncate">{conversation.title}</div>
                <div className="text-xs text-gray-400 mt-1">
                  {formatDistanceToNow(new Date(conversation.updatedAt), {
                    addSuffix: true,
                  })}
                </div>
              </button>
            ))}
          </div>
        )}
      </div>

      <div className="p-4 border-t border-gray-700 text-xs text-gray-400">
        <div>Internal Use Only</div>
        <div className="mt-1">Protected by IAP</div>
      </div>
    </div>
  )
}
