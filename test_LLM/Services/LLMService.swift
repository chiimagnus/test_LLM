//
//  LLMService.swift
//  test_LLM
//
//  Created by Trae AI on 2025/3/27.
//

import Foundation

class LLMService {
    private let apiURL = "https://api.siliconflow.cn/v1/chat/completions"
    private var apiKey: String = "" // 需要用户提供API密钥
    
    func setAPIKey(_ key: String) {
        self.apiKey = key
    }
    
    func sendMessage(messages: [[String: Any]], completion: @escaping (Result<String, Error>) -> Void) {
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
            "stream": false
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
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "没有返回数据"])))                
                return
            }
            
            do {
                // 打印原始JSON数据以便调试
                let jsonString = String(data: data, encoding: .utf8)
                print("API响应数据: \(jsonString ?? "无法转换为字符串")")
                
                // 尝试解析JSON
                if let jsonString = jsonString, !jsonString.isEmpty {
                    // 检查是否为纯文本响应（非JSON格式）
                    if !jsonString.starts(with: "{") && !jsonString.starts(with: "[") {
                        print("API返回了纯文本响应而非JSON")
                        completion(.success(jsonString))
                        return
                    }
                }
                
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // 检查JSON结构
                if let json = json {
                    // 打印JSON结构以便调试
                    print("JSON结构: \(json)")
                    
                    // 尝试多种可能的JSON结构
                    // 结构1: {"choices": [{"message": {"content": "..."}}]}
                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        completion(.success(content))
                        return
                    }
                    // 结构2: {"choices": [{"text": "..."}]}
                    else if let choices = json["choices"] as? [[String: Any]],
                            let firstChoice = choices.first,
                            let text = firstChoice["text"] as? String {
                        completion(.success(text))
                        return
                    }
                    // 结构3: {"choices": [{"content": "..."}]}
                    else if let choices = json["choices"] as? [[String: Any]],
                            let firstChoice = choices.first,
                            let content = firstChoice["content"] as? String {
                        completion(.success(content))
                        return
                    }
                    // 结构4: {"response": "..."}
                    else if let response = json["response"] as? String {
                        completion(.success(response))
                        return
                    }
                    // 结构5: {"content": "..."}
                    else if let content = json["content"] as? String {
                        completion(.success(content))
                        return
                    }
                    // 处理API返回的错误信息
                    else if let error = json["error"] as? [String: Any],
                            let message = error["message"] as? String {
                        completion(.failure(NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "API错误: \(message)"])))
                        return
                    }
                    // 如果所有预期结构都不匹配
                    else {
                        print("无法从JSON中解析出有效的响应内容")
                        print("完整JSON结构: \(json)")
                        
                        // 尝试直接返回整个JSON字符串作为响应
                        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
                           let jsonStr = String(data: jsonData, encoding: .utf8) {
                            print("将整个JSON作为响应返回")
                            completion(.success("API返回了未识别的格式: \(jsonStr)"))
                            return
                        }
                        
                        completion(.failure(NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "无法从响应中提取有效内容"])))
                    }
                } else {
                    // 如果无法解析为JSON
                    print("无法将响应数据解析为JSON对象")
                    if let dataStr = String(data: data, encoding: .utf8) {
                        print("原始响应数据: \(dataStr)")
                        // 如果是纯文本响应，直接返回
                        if !dataStr.isEmpty && !dataStr.starts(with: "{") && !dataStr.starts(with: "[") {
                            completion(.success(dataStr))
                            return
                        }
                    }
                    completion(.failure(NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "无法解析响应数据为JSON对象"])))
                }
            } catch {
                print("JSON解析错误: \(error.localizedDescription)")
                // 尝试作为纯文本处理
                if let dataStr = String(data: data, encoding: .utf8), !dataStr.isEmpty {
                    if !dataStr.starts(with: "{") && !dataStr.starts(with: "[") {
                        print("将非JSON响应作为纯文本返回")
                        completion(.success(dataStr))
                        return
                    }
                }
                completion(.failure(error))
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
        
        print("活动记录文本: \(activitiesText)")
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是一个助手，请根据用户的活动记录给出简短总结。"],
            ["role": "user", "content": "以下是我的活动记录，请给出简短总结：\n\(activitiesText)"]
        ]
        
        // 打印请求消息以便调试
        print("发送给API的消息: \(messages)")
        
        self.sendMessage(messages: messages) { result in
            // 添加额外的日志记录
            switch result {
            case .success(let content):
                print("成功获取总结: \(content)")
            case .failure(let error):
                print("总结生成失败: \(error.localizedDescription)")
                let nsError = error as NSError
                print("错误域: \(nsError.domain), 错误码: \(nsError.code), 用户信息: \(nsError.userInfo)")
            }
            
            // 传递结果给原始回调
            completion(result)
        }
    }
}
