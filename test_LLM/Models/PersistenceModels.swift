import Foundation
import SwiftData

// API密钥持久化模型
@Model
final class ApiKeyConfig {
    var key: String
    
    init(key: String) {
        self.key = key
    }
}

// 聊天消息持久化模型
@Model
final class PersistentChatMessage {
    var id: UUID
    var role: String
    var content: String
    var timestamp: Date
    
    init(from chatMessage: ChatMessage) {
        self.id = chatMessage.id
        self.role = chatMessage.role.rawValue
        self.content = chatMessage.content
        self.timestamp = chatMessage.timestamp
    }
    
    // 转换为应用中使用的ChatMessage模型
    func toChatMessage() -> ChatMessage {
        let messageRole = MessageRole(rawValue: role) ?? .user
        var message = ChatMessage(role: messageRole, content: content)
        message.id = id
        message.timestamp = timestamp
        return message
    }
}

// 聊天会话持久化模型（包含多条消息）
@Model
final class ChatSession {
    var id: UUID
    var name: String
    var messages: [PersistentChatMessage]
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), name: String = "默认会话", messages: [PersistentChatMessage] = []) {
        self.id = id
        self.name = name
        self.messages = messages
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // 更新最后修改时间
    func updateTimestamp() {
        self.updatedAt = Date()
    }
}