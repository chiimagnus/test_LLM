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

// 用于流式输出的回调
typealias StreamCallback = (String, String?) -> Void

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
    
    // 新方法支持思考模式和流式输出，添加实时流式回调
    func sendMessageWithThinking(
        messages: [[String: Any]], 
        streamCallback: StreamCallback? = nil,
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
        var requestBody: [String: Any] = [
            "model": "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B",
            "messages": messages,
            "temperature": 0.7,
            "stream": true, // 强制使用流式输出
            "max_tokens": 512
        ]
        
        // 为思考模式添加特殊参数
        if isThinkingEnabled {
            // 使用更具针对性的系统提示，明确要求模型提供推理过程
            let thinkingSystemMessage = [
                "role": "system",
                "content": "你需要展示详细的思考过程。请先进行详尽的推理分析，将推理过程写在reasoning_content中，然后给出最终回答写在content中。即使是简单问题，也请提供思考过程。"
            ]
            
            // 清理历史消息，仅保留最近的对话以减少干扰
            // 每次保留系统消息和最近3轮对话
            var trimmedMessages = [[String: Any]]()
            var userMessageCount = 0
            
            // 如果消息过多，只保留最近的几轮对话
            if messages.count > 6 {
                // 首先查找所有系统消息
                for message in messages {
                    if let role = message["role"] as? String, role == "system" {
                        trimmedMessages.append(message)
                    }
                }
                
                // 只添加最新的3轮对话(每轮包含用户消息和助手回复)
                for i in (0..<messages.count).reversed() {
                    let message = messages[i]
                    if let role = message["role"] as? String, role == "user" {
                        userMessageCount += 1
                        trimmedMessages.append(message)
                        // 如果下一条是助手的回复，也添加
                        if i + 1 < messages.count, 
                           let nextRole = messages[i + 1]["role"] as? String, 
                           nextRole == "assistant" {
                            trimmedMessages.append(messages[i + 1])
                        }
                    }
                    
                    // 只保留最近3轮
                    if userMessageCount >= 3 {
                        break
                    }
                }
                
                // 保持消息的正确顺序
                trimmedMessages.sort { (msg1, msg2) -> Bool in
                    // 系统消息总是在最前
                    if let role1 = msg1["role"] as? String, role1 == "system" {
                        return true
                    }
                    if let role2 = msg2["role"] as? String, role2 == "system" {
                        return false
                    }
                    return false // 默认情况保持原顺序
                }
                
                // 替换为裁剪后的消息
                requestBody["messages"] = trimmedMessages
                
                // 如果没有系统消息，添加思考系统消息
                var hasSystemMessage = false
                for message in trimmedMessages {
                    if let role = message["role"] as? String, role == "system" {
                        hasSystemMessage = true
                        break
                    }
                }
                
                if !hasSystemMessage {
                    var newMessages = [[String: Any]]()
                    newMessages.append(thinkingSystemMessage)
                    newMessages.append(contentsOf: trimmedMessages)
                    requestBody["messages"] = newMessages
                }
            } else {
                // 消息不多，检查是否有系统消息，如果没有则添加
                var hasSystemMessage = false
                var updatedMessages = [[String: Any]]()
                
                for message in messages {
                    if let role = message["role"] as? String, role == "system" {
                        hasSystemMessage = true
                        // 修改现有系统消息
                        var modifiedMessage = message
                        if var content = message["content"] as? String {
                            content = "你需要展示详细的思考过程。请先进行详尽的推理分析，将推理过程写在reasoning_content中，然后给出最终回答写在content中。即使是简单问题，也请提供思考过程。" + content
                            modifiedMessage["content"] = content
                        }
                        updatedMessages.append(modifiedMessage)
                    } else {
                        updatedMessages.append(message)
                    }
                }
                
                // 如果没有系统消息，添加一个
                if !hasSystemMessage {
                    updatedMessages.insert(thinkingSystemMessage, at: 0)
                }
                
                // 更新消息
                requestBody["messages"] = updatedMessages
            }
            
            // 添加额外参数以尝试引导模型输出思考内容
            requestBody["temperature"] = 0.8 // 稍微提高温度，增加多样性
            requestBody["top_p"] = 0.9 // 提高采样范围
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无法序列化请求数据"])))            
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        // 打印请求体，用于调试
        if let requestStr = String(data: jsonData, encoding: .utf8) {
            print("发送请求: \(requestStr)")
        }
        
        // 处理流式响应
        handleStreamResponse(request: request, streamCallback: streamCallback, completion: completion)
    }
    
    // 处理流式响应
    private func handleStreamResponse(request: URLRequest, streamCallback: StreamCallback? = nil, completion: @escaping (Result<LLMResponse, Error>) -> Void) {
        var contentBuilder = ""
        var reasoningContentBuilder = ""
        var dataBuffer = Data()
        var receivedAnyContent = false
        var lastUpdateTime = Date()
        var noContentRetryCount = 0
        
        // 创建任务
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // 处理错误
            if let error = error {
                DispatchQueue.main.async {
                    print("网络错误: \(error.localizedDescription)")
                    completion(.failure(error))
                }
                return
            }
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    if let data = data, let errorText = String(data: data, encoding: .utf8) {
                        print("API错误: 状态码\(httpResponse.statusCode), 内容: \(errorText)")
                    }
                    
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: "LLMService",
                            code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "API返回错误状态码: \(httpResponse.statusCode)"]
                        )))
                    }
                    return
                }
            }
            
            // 确保有数据返回
            guard let data = data else {
                DispatchQueue.main.async {
                    print("无数据返回")
                    completion(.failure(NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "没有返回数据"])))
                }
                return
            }
            
            // 将新数据添加到缓冲区
            dataBuffer.append(data)
            
            // 将数据转换为字符串
            guard let dataString = String(data: dataBuffer, encoding: .utf8) else {
                DispatchQueue.main.async {
                    print("无法解码数据为UTF-8字符串")
                    completion(.failure(NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "无法解码响应数据"])))
                }
                return
            }
            
            // 拆分SSE行
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
                            print("接收完成，内容长度: \(contentBuilder.count), 思考内容长度: \(reasoningContentBuilder.count)")
                            
                            // 确保内容不为空
                            if contentBuilder.isEmpty {
                                if !reasoningContentBuilder.isEmpty {
                                    // 如果内容为空但有思考内容，使用思考内容作为最终内容
                                    contentBuilder = "思考结果: \(reasoningContentBuilder)"
                                } else if !receivedAnyContent {
                                    // 如果既没有内容也没有思考内容
                                    contentBuilder = "模型未生成回复，请尝试提出更具体的问题。"
                                }
                            }
                            
                            let finalResponse = LLMResponse(
                                content: contentBuilder,
                                reasoningContent: self.isThinkingEnabled ? reasoningContentBuilder : nil
                            )
                            completion(.success(finalResponse))
                        }
                        return
                    }
                    
                    do {
                        // 尝试解析JSON
                        if let jsonData = jsonText.data(using: .utf8),
                           let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                            
                            // 从json中提取choices
                            if let choices = json["choices"] as? [[String: Any]],
                               let firstChoice = choices.first {
                                
                                var contentUpdated = false
                                var reasoningUpdated = false
                                
                                // 检查是否包含delta
                                if let delta = firstChoice["delta"] as? [String: Any] {
                                    // 添加内容增量
                                    if let contentDelta = delta["content"] as? String {
                                        contentBuilder += contentDelta
                                        contentUpdated = true
                                        receivedAnyContent = true
                                        
                                        // 如果内容为空，尝试替代方案 - 手动分析思考过程
                                        if self.isThinkingEnabled && reasoningContentBuilder.isEmpty && !contentDelta.isEmpty {
                                            // 在内容中寻找表示思考过程的部分
                                            let contentSoFar = contentBuilder
                                            if contentSoFar.contains("让我思考") || 
                                               contentSoFar.contains("首先，") || 
                                               contentSoFar.contains("考虑到") ||
                                               contentSoFar.contains("分析") {
                                                // 如果内容看起来像思考过程，把它放入reasoningContent
                                                reasoningContentBuilder = contentSoFar
                                                contentBuilder = "" // 清空content，等待最终答案
                                                reasoningUpdated = true
                                            }
                                        }
                                    }
                                    
                                    // 如果启用了思考模式，收集思考内容
                                    if self.isThinkingEnabled, let reasoningDelta = delta["reasoning_content"] as? String {
                                        reasoningContentBuilder += reasoningDelta
                                        reasoningUpdated = true
                                        receivedAnyContent = true
                                    }
                                }
                                // 检查message格式（非增量模式）
                                else if let message = firstChoice["message"] as? [String: Any] {
                                    if let content = message["content"] as? String {
                                        // 只有在不为null且不为空字符串时才设置
                                        if !content.isEmpty {
                                            contentBuilder = content
                                            contentUpdated = true
                                            receivedAnyContent = true
                                        }
                                    }
                                    
                                    if self.isThinkingEnabled, let reasoning = message["reasoning_content"] as? String {
                                        if !reasoning.isEmpty {
                                            reasoningContentBuilder = reasoning
                                            reasoningUpdated = true
                                            receivedAnyContent = true
                                        }
                                    }
                                }
                                
                                // 回调实时数据
                                if (contentUpdated || reasoningUpdated) && streamCallback != nil {
                                    DispatchQueue.main.async {
                                        streamCallback?(contentBuilder, self.isThinkingEnabled ? reasoningContentBuilder : nil)
                                    }
                                    lastUpdateTime = Date()
                                } else {
                                    // 检查是否长时间没有更新
                                    let currentTime = Date()
                                    if currentTime.timeIntervalSince(lastUpdateTime) > 5.0 && !receivedAnyContent {
                                        // 如果5秒钟没有任何更新，且还没收到任何内容，增加重试计数
                                        noContentRetryCount += 1
                                        
                                        if noContentRetryCount >= 3 {
                                            // 如果已经尝试了3次仍然没有内容，提前结束并返回默认消息
                                            DispatchQueue.main.async {
                                                let fallbackContent = "模型似乎没有返回内容。请尝试不同的问题或者检查API设置。"
                                                let response = LLMResponse(content: fallbackContent, reasoningContent: nil)
                                                completion(.success(response))
                                            }
                                            return
                                        }
                                    }
                                }
                            }
                        }
                    } catch {
                        print("JSON解析错误: \(error.localizedDescription), 原始数据: \(jsonText)")
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
        streamCallback: StreamCallback? = nil,
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
            ["role": "system", "content": "你是一个助手，请详细思考并分析用户的活动记录，提供你的推理过程，然后给出有洞察力的总结。"],
            ["role": "user", "content": "以下是我的活动记录，请给出简短总结：\n\(activitiesText)"]
        ]
        
        self.sendMessageWithThinking(messages: messages, streamCallback: streamCallback, completion: completion)
    }
}
