import Foundation

class SiliconFlowService {
    private let apiUrl = "https://api.siliconflow.cn/v1/chat/completions"
    private var apiKey: String = ""
    
    // 初始化方法，设置API密钥
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // 发送聊天请求并获取响应
    func sendMessage(messages: [ChatMessage], completion: @escaping (Result<ChatMessage, Error>) -> Void) {
        // 创建请求参数
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
} 