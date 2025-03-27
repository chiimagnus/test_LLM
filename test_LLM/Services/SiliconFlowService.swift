import Foundation

class SiliconFlowService {
    private let apiUrl = "https://api.siliconflow.cn/v1/chat/completions"
    private var apiKey: String = ""
    
    // 初始化方法，设置API密钥
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // 发送普通聊天请求并获取完整响应
    func sendMessage(messages: [ChatMessage], completion: @escaping (Result<ChatMessage, Error>) -> Void) {
        // 创建请求参数
        let request = SiliconFlowRequest.createDefault(messages: messages, stream: false)
        
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
            
            // 发送请求
            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                // 处理错误
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                // 处理响应
                guard let data = data else {
                    completion(.failure(NSError(domain: "SiliconFlowService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    // 解析响应数据
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(SiliconFlowResponse.self, from: data)
                    
                    // 提取助手回复
                    if let assistantMessage = response.choices.first?.message {
                        let chatMessage = ChatMessage(
                            role: .assistant,
                            content: assistantMessage.content
                        )
                        completion(.success(chatMessage))
                    } else {
                        completion(.failure(NSError(domain: "SiliconFlowService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No message in response"])))
                    }
                } catch {
                    // 解析错误
                    completion(.failure(error))
                }
            }
            
            // 启动任务
            task.resume()
            
        } catch {
            // 序列化错误
            completion(.failure(error))
        }
    }
    
    // 发送流式聊天请求并逐步处理响应
    func sendStreamMessage(
        messages: [ChatMessage],
        onReceive: @escaping (String) -> Void,
        onComplete: @escaping (Result<Void, Error>) -> Void
    ) {
        // 创建流式请求参数
        let request = SiliconFlowRequest.createDefault(messages: messages, stream: true)
        
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
            
            // 创建URLSession数据任务
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
                    // 处理SSE格式的响应
                    let events = self.parseSSEEvents(dataString)
                    
                    for event in events {
                        do {
                            let decoder = JSONDecoder()
                            // 解析每个事件
                            if event == "[DONE]" {
                                // 流结束
                                onComplete(.success(()))
                                return
                            } else if let eventData = event.data(using: .utf8) {
                                let streamResponse = try decoder.decode(SiliconFlowStreamResponse.self, from: eventData)
                                // 如果是完成消息，则完成
                                if streamResponse.isDone {
                                    onComplete(.success(()))
                                    return
                                }
                                
                                // 提取内容片段
                                if let content = streamResponse.choices?.first?.delta.content {
                                    onReceive(content)
                                }
                            }
                        } catch {
                            // 忽略解析错误，继续处理下一个事件
                            print("Error parsing SSE event: \(error)")
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
    
    // 解析SSE格式的事件
    private func parseSSEEvents(_ sseText: String) -> [String] {
        var events: [String] = []
        let lines = sseText.components(separatedBy: "\n")
        var currentEvent = ""
        
        for line in lines {
            if line.hasPrefix("data: ") {
                let data = line.dropFirst(6) // 去掉 "data: "
                currentEvent = String(data)
                
                // 如果不是空事件，添加到事件列表
                if !currentEvent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    events.append(currentEvent)
                }
            }
        }
        
        return events
    }
} 