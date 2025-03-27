import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    var role: MessageRole
    var content: String
    var timestamp: Date = Date()
    
    init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
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