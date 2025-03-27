import Foundation

// 流式响应的数据结构
struct SiliconFlowStreamResponse: Decodable {
    let id: String?
    let choices: [StreamChoice]?
    let created: Int?
    let model: String?
    let object: String?
    
    // 用于判断是否是结束信息 [DONE]
    var isDone: Bool {
        return object == "[DONE]"
    }
}

struct StreamChoice: Decodable {
    let delta: StreamDelta
    let index: Int
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case delta
        case index
        case finishReason = "finish_reason"
    }
}

struct StreamDelta: Decodable {
    let role: String?
    let content: String?
    let reasoningContent: String?
    
    enum CodingKeys: String, CodingKey {
        case role
        case content
        case reasoningContent = "reasoning_content"
    }
} 