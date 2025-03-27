import Foundation

struct SiliconFlowResponse: Decodable {
    let id: String
    let choices: [Choice]
    let usage: Usage
    let created: Int
    let model: String
    let object: String
}

struct Choice: Decodable {
    let message: AssistantMessage
    let finishReason: String
    
    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

struct AssistantMessage: Decodable {
    let role: String
    let content: String
    let reasoningContent: String?
    let toolCalls: [ToolCall]?
    
    enum CodingKeys: String, CodingKey {
        case role
        case content
        case reasoningContent = "reasoning_content"
        case toolCalls = "tool_calls"
    }
}

struct ToolCall: Decodable {
    let id: String
    let type: String
    let function: FunctionCall
}

struct FunctionCall: Decodable {
    let name: String
    let arguments: String
}

struct Usage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
} 