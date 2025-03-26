//
//  LLMService.swift
//  test_LLM
//
//  Created by Trae AI on 2025/3/27.
//

import Foundation

class LLMService {
    private let apiURL = "https://cloud.siliconflow.cn/api/v1/chat/completions"
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
        
        let requestBody: [String: Any] = [
            "model": "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B",
            "messages": messages,
            "temperature": 0.7
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
                
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // 检查JSON结构
                if let json = json {
                    // 打印JSON结构以便调试
                    print("JSON结构: \(json)")
                    
                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        completion(.success(content))
                        return
                    } else if let error = json["error"] as? [String: Any],
                              let message = error["message"] as? String {
                        // 处理API返回的错误信息
                        completion(.failure(NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "API错误: \(message)"])))                        
                        return
                    } else {
                        // 如果choices字段不符合预期
                        print("无法从JSON中解析choices字段")
                        if let choicesObj = json["choices"] {
                            print("Choices对象类型: \(type(of: choicesObj))")
                            print("Choices内容: \(choicesObj)")
                        } else {
                            print("JSON中没有choices字段")
                        }
                        completion(.failure(NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "无法解析choices字段"])))
                    }
                } else {
                    // 如果无法解析为JSON
                    print("无法将响应数据解析为JSON对象")
                    completion(.failure(NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "无法解析响应数据为JSON对象"])))
                }
            } catch {
                print("JSON解析错误: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()

    
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
                if let nsError = error as NSError {
                    print("错误域: \(nsError.domain), 错误码: \(nsError.code), 用户信息: \(nsError.userInfo)")
                }
            }
            
            // 传递结果给原始回调
            completion(result)
        }
    }
}

