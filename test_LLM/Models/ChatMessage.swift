import Foundation

enum MessageRole: String, Codable, Equatable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var role: MessageRole
    var content: String
    var timestamp: Date = Date()
    
    init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.role == rhs.role &&
               lhs.content == rhs.content &&
               lhs.timestamp == rhs.timestamp
    }
}

struct APIMessage: Codable {
    var role: String
    var content: String
    
    init(from chatMessage: ChatMessage) {
        self.role = chatMessage.role.rawValue
        self.content = chatMessage.content
    }
} 