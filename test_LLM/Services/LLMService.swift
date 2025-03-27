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
                // 尝试解析JSON
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // 根据硅基流动API文档，解析响应数据
                if let json = json {
                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        completion(.success(content))
                        return
                    }
                    // 处理API返回的错误信息
                    else if let error = json["error"] as? [String: Any],
                            let message = error["message"] as? String {
                        completion(.failure(NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "API错误: \(message)"])))
                        return
                    }
                    else {
                        completion(.failure(NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "无法从响应中提取有效内容"])))
                    }
                } else {
                    completion(.failure(NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "无法解析响应数据为JSON对象"])))
                }
            } catch {
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
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是一个助手，请根据用户的活动记录给出简短总结。"],
            ["role": "user", "content": "以下是我的活动记录，请给出简短总结：\n\(activitiesText)"]
        ]
        
        self.sendMessage(messages: messages, completion: completion)
    }
}
