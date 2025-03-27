import Foundation

class SiliconFlowService {
    private let apiUrl = "https://api.siliconflow.cn/v1/chat/completions"
    private var apiKey: String = ""
    
    // 初始化方法，设置API密钥
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // 发送流式聊天请求并逐步处理响应
    func sendStreamMessage(
        messages: [ChatMessage],
        onReceive: @escaping (String) -> Void,
        onComplete: @escaping (Result<Void, Error>) -> Void
    ) {
        // 创建流式请求参数
        let request = SiliconFlowRequest.createDefault(messages: messages)
        
        // 创建URLRequest
        var urlRequest = URLRequest(url: URL(string: apiUrl)!)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            // 序列化请求体
            let encoder = JSONEncoder()
            let requestData = try encoder.encode(request)
            urlRequest.httpBody = requestData
            
            print("请求内容: \(String(data: requestData, encoding: .utf8) ?? "")")
            
            // 创建URLSession任务
            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                // 处理错误
                if let error = error {
                    onComplete(.failure(error))
                    return
                }
                
                // 处理响应
                guard let data = data else {
                    onComplete(.failure(NSError(domain: "SiliconFlowService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                // 将数据转换为字符串
                if let dataString = String(data: data, encoding: .utf8) {
                    print("原始响应: \(dataString)")
                    
                    // 处理SSE格式的响应
                    let events = self.parseSSEEvents(dataString)
                    
                    if events.isEmpty {
                        // 如果事件为空，可能是API格式问题，尝试作为普通响应处理
                        onComplete(.failure(NSError(domain: "SiliconFlowService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No valid SSE events found"])))
                        return
                    }
                    
                    for event in events {
                        do {
                            // 检查是否是完成消息
                            if event == "[DONE]" {
                                onComplete(.success(()))
                                return
                            }
                            
                            // 解析JSON响应
                            if let eventData = event.data(using: .utf8) {
                                let streamResponse = try JSONDecoder().decode(SiliconFlowStreamResponse.self, from: eventData)
                                
                                // 检查是否是完成消息
                                if streamResponse.isDone {
                                    onComplete(.success(()))
                                    return
                                }
                                
                                // 提取内容片段并发送
                                if let content = streamResponse.choices?.first?.delta.content, !content.isEmpty {
                                    onReceive(content)
                                }
                            }
                        } catch {
                            print("解析事件错误: \(error), 事件: \(event)")
                            // 继续处理下一个事件，不中断流
                        }
                    }
                    
                    // 所有事件处理完成
                    onComplete(.success(()))
                } else {
                    onComplete(.failure(NSError(domain: "SiliconFlowService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response data"])))
                }
            }
            
            // 启动任务
            task.resume()
            
        } catch {
            // 序列化错误
            onComplete(.failure(error))
        }
    }
    
    // 改进的SSE事件解析
    private func parseSSEEvents(_ sseText: String) -> [String] {
        var events: [String] = []
        let lines = sseText.components(separatedBy: "\n")
        var currentEvent = ""
        
        for line in lines {
            if line.hasPrefix("data: ") {
                let data = line.dropFirst(6) // 去掉 "data: "
                let dataString = String(data)
                
                // 特殊处理 [DONE] 消息
                if dataString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                    events.append("[DONE]")
                } else if !dataString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // 如果不是空事件，添加到事件列表
                    events.append(dataString)
                }
            }
        }
        
        return events
    }
} 