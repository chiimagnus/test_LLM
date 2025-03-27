import Foundation

struct SiliconFlowRequest: Encodable {
    let model: String
    let messages: [APIMessage]
    let stream: Bool
    let maxTokens: Int
    let stop: String?
    let temperature: Double
    let topP: Double
    let topK: Int
    let frequencyPenalty: Double
    let n: Int
    let responseFormat: ResponseFormat
    let tools: [Tool]?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case maxTokens = "max_tokens"
        case stop
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case frequencyPenalty = "frequency_penalty"
        case n
        case responseFormat = "response_format"
        case tools
    }
    
    static func createDefault(messages: [ChatMessage], model: String = "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B") -> SiliconFlowRequest {
        return SiliconFlowRequest(
            model: model,
            messages: messages.map { APIMessage(from: $0) },
            stream: false,
            maxTokens: 512,
            stop: nil,
            temperature: 0.7,
            topP: 0.7,
            topK: 50,
            frequencyPenalty: 0.5,
            n: 1,
            responseFormat: ResponseFormat(type: "text"),
            tools: nil
        )
    }
}

struct ResponseFormat: Encodable {
    let type: String
}

struct Tool: Encodable {
    let type: String
    let function: SimpleFunctionTool
}

struct SimpleFunctionTool: Encodable {
    let description: String
    let name: String
    let parameters: [String: String]
    let strict: Bool
} 