//
//  LLMService.swift
//  test_LLM
//
//  Created by Trae AI on 2025/3/27.
//

import Foundation

// 用于同时存储内容和思考内容的结构
struct LLMResponse {
    let content: String
    let reasoningContent: String?
    
    init(content: String, reasoningContent: String? = nil) {
        self.content = content
        self.reasoningContent = reasoningContent
    }
}

class LLMService {
    private let apiURL = "https://api.siliconflow.cn/v1/chat/completions"
    private var apiKey: String = "" // 需要用户提供API密钥
    private var isThinkingEnabled: Bool = false // 默认不启用思考模式
    
    func setAPIKey(_ key: String) {
        self.apiKey = key
    }
    
    // 开启或关闭思考模式
    func setThinkingEnabled(_ enabled: Bool) {
        self.isThinkingEnabled = enabled
        print("思考模式已\(enabled ? "开启" : "关闭")")
    }
    
    // 原有方法保留向后兼容性，现在强制使用流式输出
    func sendMessage(messages: [[String: Any]], completion: @escaping (Result<String, Error>) -> Void) {
        sendMessageWithThinking(messages: messages) { result in
            switch result {
            case .success(let response):
                completion(.success(response.content))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 新方法支持思考模式，现在强制使用流式输出
    func sendMessageWithThinking(
        messages: [[String: Any]], 
        completion: @escaping (Result<LLMResponse, Error>) -> Void
    ) {
        guard !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "LLMService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API密钥未设置"])))            
            return
        }
        
        guard let url = URL(string: apiURL) else {
            completion(.failure(NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))            
            return
        }
        
        // 根据硅基流动API文档构建请求体
        let requestBody: [String: Any] = [
            "model": "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B",
            "messages": messages,
            "temperature": 0.7,
            "stream": true, // 强制使用流式输出
            "max_tokens": 512
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无法序列化请求数据"])))            
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        // 处理流式响应
        handleStreamResponse(request: request, completion: completion)
    }
    
    // 处理流式响应
    private func handleStreamResponse(request: URLRequest, completion: @escaping (Result<LLMResponse, Error>) -> Void) {
        var contentBuilder = ""
        var reasoningContentBuilder = ""
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "没有返回数据"])))
                return
            }
            
            // 处理SSE格式的数据
            if let dataString = String(data: data, encoding: .utf8) {
                // 按行分割
                let lines = dataString.components(separatedBy: "\n")
                
                for line in lines {
                    if line.hasPrefix("data: ") {
                        let jsonText = line.dropFirst(6) // 移除 "data: " 前缀
                        
                        // 检查是否是完成标志
                        if jsonText == "[DONE]" {
                            // 流式传输完成，返回完整内容
                            DispatchQueue.main.async {
                                let finalResponse = LLMResponse(
                                    content: contentBuilder,
                                    reasoningContent: self.isThinkingEnabled ? reasoningContentBuilder : nil
                                )
                                completion(.success(finalResponse))
                            }
                            return
                        }
                        
                        // 尝试解析为JSON
                        if let jsonData = jsonText.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let firstChoice = choices.first,
                           let delta = firstChoice["delta"] as? [String: Any] {
                            
                            // 添加内容增量
                            if let contentDelta = delta["content"] as? String {
                                contentBuilder += contentDelta
                            }
                            
                            // 如果启用了思考模式，才收集思考内容
                            if self.isThinkingEnabled, let reasoningDelta = delta["reasoning_content"] as? String {
                                reasoningContentBuilder += reasoningDelta
                            }
                        }
                    }
                }
            }
        }
        
        task.resume()
    }
    
    func summarizeActivities(activities: [Item], completion: @escaping (Result<String, Error>) -> Void) {
        // 格式化活动记录，确保日期格式一致
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        let activitiesText = activities.map { 
            "\($0.activityDescription) at \(dateFormatter.string(from: $0.timestamp))"
        }.joined(separator: "\n")
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是一个助手，请根据用户的活动记录给出简短总结。"],
            ["role": "user", "content": "以下是我的活动记录，请给出简短总结：\n\(activitiesText)"]
        ]
        
        self.sendMessage(messages: messages, completion: completion)
    }
    
    // 支持思考模式的活动总结方法
    func summarizeActivitiesWithThinking(
        activities: [Item], 
        completion: @escaping (Result<LLMResponse, Error>) -> Void
    ) {
        // 格式化活动记录，确保日期格式一致
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        let activitiesText = activities.map { 
            "\($0.activityDescription) at \(dateFormatter.string(from: $0.timestamp))"
        }.joined(separator: "\n")
        
        // 确保思考模式已开启
        if !self.isThinkingEnabled {
            self.setThinkingEnabled(true)
        }
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是一个助手，请根据用户的活动记录给出简短总结。请思考每个活动的意义，然后给出有洞察力的总结。"],
            ["role": "user", "content": "以下是我的活动记录，请给出简短总结：\n\(activitiesText)"]
        ]
        
        self.sendMessageWithThinking(messages: messages, completion: completion)
    }
}
