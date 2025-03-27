//
//  LLMService.swift
//  test_LLM
//
//  Created by Trae AI on 2025/3/27.
//

import Foundation
import SwiftData

// 简化的响应结构
struct LLMResponse {
    let content: String
    let reasoningContent: String?
}

// 流式输出回调类型
typealias StreamCallback = (String, String?) -> Void

class LLMService {
    // API配置
    private let apiURL = "https://api.siliconflow.cn/v1/chat/completions"
    private var apiKey: String = ""
    private var isThinkingEnabled: Bool = false
    private var defaultModel = "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B"
    
    // 设置API密钥
    func setAPIKey(_ key: String) {
        self.apiKey = key
    }
    
    // 设置默认模型
    func setDefaultModel(_ model: String) {
        self.defaultModel = model
        print("默认模型已设置为: \(model)")
    }
    
    // 设置思考模式
    func setThinkingEnabled(_ enabled: Bool) {
        self.isThinkingEnabled = enabled
        print("思考模式已\(enabled ? "开启" : "关闭")")
    }
    
    // 发送消息 - 普通模式
    func sendMessage(messages: [[String: Any]], completion: @escaping (Result<String, Error>) -> Void) {
        sendRequest(messages: messages, stream: false) { result in
            switch result {
            case .success(let response):
                completion(.success(response.content))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 发送消息 - 支持思考模式和流式输出
    func sendMessageWithThinking(
        messages: [[String: Any]],
        streamCallback: StreamCallback? = nil,
        completion: @escaping (Result<LLMResponse, Error>) -> Void
    ) {
        sendRequest(messages: messages, stream: true, streamCallback: streamCallback, completion: completion)
    }
    
    // 核心请求方法
    private func sendRequest(
        messages: [[String: Any]],
        stream: Bool,
        streamCallback: StreamCallback? = nil,
        completion: @escaping (Result<LLMResponse, Error>) -> Void
    ) {
        // 基本验证
        guard !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "LLMService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API密钥未设置"])))
            return
        }
        
        guard let url = URL(string: apiURL) else {
            completion(.failure(NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }
        
        // 构建请求体
        var requestBody: [String: Any] = [
            "model": defaultModel,
            "messages": messages,
            "temperature": isThinkingEnabled ? 0.8 : 0.7,
            "top_p": isThinkingEnabled ? 0.9 : 0.7,
            "stream": stream,
            "max_tokens": 512,
            "top_k": 50,
            "frequency_penalty": 0.5,
            "n": 1,
            "response_format": ["type": "text"]
        ]
        
        // 添加唯一用户标识防止缓存问题
        requestBody["user"] = UUID().uuidString + "-\(Date().timeIntervalSince1970)"
        
        // 如果需要可以添加stop参数
        // requestBody["stop"] = nil
        
        // 如果需要添加函数调用工具，可以取消注释以下代码
        /*
        requestBody["tools"] = [
            [
                "type": "function",
                "function": [
                    "description": "",
                    "name": "",
                    "parameters": [:],
                    "strict": false
                ]
            ]
        ]
        */
        
        // 如果启用思考模式，添加系统消息
        if isThinkingEnabled {
            // 检查是否已有系统消息
            var hasSystemMessage = false
            var systemMessageIndex = -1
            
            for (index, message) in messages.enumerated() {
                if let role = message["role"] as? String, role == "system" {
                    hasSystemMessage = true
                    systemMessageIndex = index
                    break
                }
            }
            
            let thinkingSystemMessage: [String: Any] = [
                "role": "system",
                "content": "你需要展示详细的思考过程。请先进行详尽的推理分析，然后给出最终回答。即使是简单问题，也请提供思考过程。"
            ]
            
            // 创建新的消息数组
            var updatedMessages = messages
            
            if hasSystemMessage {
                // 替换已有的系统消息
                updatedMessages[systemMessageIndex] = thinkingSystemMessage
            } else {
                // 在开头添加系统消息
                updatedMessages.insert(thinkingSystemMessage, at: 0)
            }
            
            requestBody["messages"] = updatedMessages
        }
        
        // 构建请求
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无法序列化请求数据"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        // 打印调试信息
        #if DEBUG
        if let requestStr = String(data: jsonData, encoding: .utf8) {
            print("发送请求: \(requestStr)")
        }
        #endif
        
        // 处理请求
        if stream {
            handleStreamResponse(request: request, streamCallback: streamCallback, completion: completion)
        } else {
            handleSingleResponse(request: request, completion: completion)
        }
    }
    
    // 处理单次响应
    private func handleSingleResponse(
        request: URLRequest,
        completion: @escaping (Result<LLMResponse, Error>) -> Void
    ) {
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // 处理错误
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                DispatchQueue.main.async {
                    let errorMessage = data != nil ? String(data: data!, encoding: .utf8) : "未知错误"
                    completion(.failure(NSError(
                        domain: "LLMService",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "API错误: \(errorMessage ?? "")"]
                    )))
                }
                return
            }
            
            // 确保有数据返回
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "没有返回数据"])))
                }
                return
            }
            
            // 解析响应
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    let reasoningContent = message["reasoning_content"] as? String
                    
                    DispatchQueue.main.async {
                        let response = LLMResponse(content: content, reasoningContent: reasoningContent)
                        completion(.success(response))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "无法解析响应数据"])))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    // 处理流式响应
    private func handleStreamResponse(
        request: URLRequest,
        streamCallback: StreamCallback? = nil,
        completion: @escaping (Result<LLMResponse, Error>) -> Void
    ) {
        var contentBuilder = ""
        var reasoningContentBuilder = ""
        var dataBuffer = Data()
        var receivedAnyContent = false
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // 处理错误
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                DispatchQueue.main.async {
                    let errorMessage = data != nil ? String(data: data!, encoding: .utf8) : "未知错误"
                    completion(.failure(NSError(
                        domain: "LLMService",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "API错误: \(errorMessage ?? "")"]
                    )))
                }
                return
            }
            
            // 确保有数据返回
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "没有返回数据"])))
                }
                return
            }
            
            // 将新数据添加到缓冲区
            dataBuffer.append(data)
            
            // 将数据转换为字符串
            guard let dataString = String(data: dataBuffer, encoding: .utf8) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "无法解码响应数据"])))
                }
                return
            }
            
            // 处理SSE格式数据
            let lines = dataString.components(separatedBy: "\n")
            var processedDataLength = 0
            
            for line in lines {
                if line.hasPrefix("data: ") {
                    let jsonText = line.dropFirst(6) // 移除 "data: " 前缀
                    processedDataLength += line.utf8.count + 1 // +1 for newline
                    
                    // 检查是否是完成标志
                    if jsonText == "[DONE]" {
                        // 流式传输完成，返回完整内容
                        DispatchQueue.main.async {
                            // 确保内容不为空
                            if contentBuilder.isEmpty && receivedAnyContent {
                                if !reasoningContentBuilder.isEmpty {
                                    contentBuilder = "思考结果: \(reasoningContentBuilder)"
                                } else {
                                    contentBuilder = "模型已响应但未生成有效回复，请尝试提出更具体的问题。"
                                }
                            } else if !receivedAnyContent {
                                contentBuilder = "模型未生成回复，请尝试再次提问或调整问题。"
                            }
                            
                            let finalResponse = LLMResponse(
                                content: contentBuilder,
                                reasoningContent: self.isThinkingEnabled ? reasoningContentBuilder : nil
                            )
                            completion(.success(finalResponse))
                        }
                        return
                    }
                    
                    // 解析JSON
                    do {
                        if let jsonData = jsonText.data(using: .utf8),
                           let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let firstChoice = choices.first {
                            
                            var contentUpdated = false
                            var reasoningUpdated = false
                            
                            // 处理增量更新模式 (delta)
                            if let delta = firstChoice["delta"] as? [String: Any] {
                                // 内容更新
                                if let contentDelta = delta["content"] as? String {
                                    contentBuilder += contentDelta
                                    contentUpdated = true
                                    receivedAnyContent = true
                                    
                                    // 如果启用了思考模式且内容看起来像思考过程
                                    if self.isThinkingEnabled && reasoningContentBuilder.isEmpty {
                                        let contentSoFar = contentBuilder
                                        if contentSoFar.contains("让我思考") || 
                                           contentSoFar.contains("首先，") || 
                                           contentSoFar.contains("考虑到") ||
                                           contentSoFar.contains("分析") ||
                                           contentSoFar.contains("思考") ||
                                           contentSoFar.contains("推理") {
                                            reasoningContentBuilder = contentSoFar
                                            contentBuilder = ""
                                            reasoningUpdated = true
                                        }
                                    }
                                }
                                
                                // 思考内容更新
                                if self.isThinkingEnabled, let reasoningDelta = delta["reasoning_content"] as? String {
                                    reasoningContentBuilder += reasoningDelta
                                    reasoningUpdated = true
                                    receivedAnyContent = true
                                }
                            }
                            // 处理完整消息模式 (message)
                            else if let message = firstChoice["message"] as? [String: Any] {
                                if let content = message["content"] as? String, !content.isEmpty {
                                    contentBuilder = content
                                    contentUpdated = true
                                    receivedAnyContent = true
                                }
                                
                                if self.isThinkingEnabled, let reasoning = message["reasoning_content"] as? String, !reasoning.isEmpty {
                                    reasoningContentBuilder = reasoning
                                    reasoningUpdated = true
                                    receivedAnyContent = true
                                }
                            }
                            
                            // 回调实时数据
                            if (contentUpdated || reasoningUpdated) && streamCallback != nil {
                                DispatchQueue.main.async {
                                    streamCallback?(contentBuilder, self.isThinkingEnabled ? reasoningContentBuilder : nil)
                                }
                            }
                        }
                    } catch {
                        print("JSON解析错误: \(error.localizedDescription)")
                    }
                }
            }
            
            // 移除已处理的数据
            if processedDataLength > 0 && processedDataLength <= dataBuffer.count {
                dataBuffer.removeSubrange(0..<processedDataLength)
            }
        }
        
        task.resume()
    }
    
    // MARK: - 活动总结功能
    
    /// 生成活动总结
    /// - Parameters:
    ///   - activities: 要总结的活动数组
    ///   - completion: 完成回调，返回总结文本或错误
    func summarizeActivities<T>(activities: [T], completion: @escaping (Result<String, Error>) -> Void) where T: HasActivityDescription {
        // 格式化活动记录
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        let activitiesText = activities.map { 
            "\($0.activityDescription) at \(dateFormatter.string(from: $0.timestamp))"
        }.joined(separator: "\n")
        
        // 构建消息
        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是一个助手，请根据用户的活动记录给出简短总结。"],
            ["role": "user", "content": "以下是我的活动记录，请给出简短总结：\n\(activitiesText)"]
        ]
        
        // 使用普通模式发送消息
        self.sendMessage(messages: messages, completion: completion)
    }
    
    /// 生成活动总结（带思考模式）
    /// - Parameters:
    ///   - activities: 要总结的活动数组
    ///   - streamCallback: 流式回调，用于实时显示生成过程
    ///   - completion: 完成回调，返回总结结果或错误
    func summarizeActivitiesWithThinking<T>(
        activities: [T], 
        streamCallback: StreamCallback? = nil,
        completion: @escaping (Result<LLMResponse, Error>) -> Void
    ) where T: HasActivityDescription {
        // 格式化活动记录
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        let activitiesText = activities.map { 
            "\($0.activityDescription) at \(dateFormatter.string(from: $0.timestamp))"
        }.joined(separator: "\n")
        
        // 确保思考模式已开启
        let previousThinkingMode = self.isThinkingEnabled
        self.isThinkingEnabled = true
        
        // 构建消息
        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是一个助手，请详细思考并分析用户的活动记录，提供你的推理过程，然后给出有洞察力的总结。"],
            ["role": "user", "content": "以下是我的活动记录，请给出简短总结：\n\(activitiesText)"]
        ]
        
        // 使用思考模式发送消息
        self.sendMessageWithThinking(
            messages: messages, 
            streamCallback: streamCallback,
            completion: { [weak self] result in
                // 恢复之前的思考模式设置
                self?.isThinkingEnabled = previousThinkingMode
                completion(result)
            }
        )
    }
}

// 定义活动项目的协议
protocol HasActivityDescription {
    var activityDescription: String { get }
    var timestamp: Date { get }
}

// 扩展Item实现协议
extension Item: HasActivityDescription {}
