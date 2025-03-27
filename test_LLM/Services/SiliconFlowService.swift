import Foundation

class SiliconFlowService: NSObject {
    private let apiUrl = "https://api.siliconflow.cn/v1/chat/completions"
    private var apiKey: String = ""
    
    // 用于流式请求的回调
    private var onReceiveContent: ((String) -> Void)?
    private var onRequestComplete: ((Result<Void, Error>) -> Void)?
    
    // 用于构建流式响应
    private var receivedData = Data()
    private var buffer = ""
    
    // 初始化方法，设置API密钥
    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }
    
    // 发送流式聊天请求并逐步处理响应
    func sendStreamMessage(
        messages: [ChatMessage],
        onReceive: @escaping (String) -> Void,
        onComplete: @escaping (Result<Void, Error>) -> Void
    ) {
        // 保存回调
        self.onReceiveContent = onReceive
        self.onRequestComplete = onComplete
        
        // 重置数据缓冲区
        self.receivedData = Data()
        self.buffer = ""
        
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
            
            print("发送流式请求...")
            
            // 创建自定义的URLSession，使用delegate处理流式数据
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
            let task = session.dataTask(with: urlRequest)
            task.resume()
            
        } catch {
            // 序列化错误
            onComplete(.failure(error))
        }
    }
    
    // 处理SSE格式的行
    private func processSSELine(_ line: String) {
        if line.hasPrefix("data: ") {
            let dataContent = line.dropFirst(6) // 移除 "data: " 前缀
            let content = String(dataContent)
            
            // 检查是否是结束标记
            if content.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                print("收到[DONE]标记，流式请求完成")
                onRequestComplete?(.success(()))
                return
            }
            
            // 解析JSON数据
            do {
                if let data = content.data(using: .utf8) {
                    let response = try JSONDecoder().decode(SiliconFlowStreamResponse.self, from: data)
                    
                    // 提取delta内容
                    if let deltaContent = response.choices?.first?.delta.content, !deltaContent.isEmpty {
                        print("收到片段: '\(deltaContent)'")
                        onReceiveContent?(deltaContent)
                    }
                }
            } catch {
                print("解析流式数据失败: \(error), 数据: \(content)")
                // 继续处理，不中断流
            }
        }
    }
}

// MARK: - URLSessionDataDelegate
extension SiliconFlowService: URLSessionDataDelegate {
    // 接收部分数据时调用
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // 累积接收到的数据
        receivedData.append(data)
        
        // 尝试将新数据转换为字符串
        if let newString = String(data: data, encoding: .utf8) {
            // 添加到缓冲区
            buffer.append(newString)
            
            // 按行分割缓冲区内容
            let lines = buffer.components(separatedBy: "\n")
            
            // 处理除最后一行外的所有行（最后一行可能不完整）
            if lines.count > 1 {
                for i in 0..<lines.count-1 {
                    let line = lines[i]
                    if !line.isEmpty {
                        processSSELine(line)
                    }
                }
                
                // 保留可能不完整的最后一行
                buffer = lines.last ?? ""
            }
        }
    }
    
    // 当数据任务完成时调用
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("流式请求出错: \(error)")
            onRequestComplete?(.failure(error))
            return
        }
        
        // 处理缓冲区中剩余的内容
        if !buffer.isEmpty {
            processSSELine(buffer)
        }
        
        print("流式请求正常结束")
        onRequestComplete?(.success(()))
    }
} 