import Foundation
import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var useStreamingMode: Bool = true  // 是否使用流式模式
    
    // 用于流式输出的临时消息
    @Published var streamingMessage: ChatMessage?
    
    private var siliconFlowService: SiliconFlowService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiKey: String = "") {
        self.siliconFlowService = SiliconFlowService(apiKey: apiKey)
        
        // 添加初始系统消息
        messages.append(ChatMessage(role: .system, content: "你是一个友好的AI助手，能够用中文回答用户的问题。"))
    }
    
    // 更新API密钥
    func updateApiKey(_ key: String) {
        self.siliconFlowService = SiliconFlowService(apiKey: key)
    }
    
    // 发送消息
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(role: .user, content: inputText)
        messages.append(userMessage)
        
        inputText = ""
        isLoading = true
        errorMessage = nil
        
        if useStreamingMode {
            // 创建一个空的流式消息
            let initialStreamingMessage = ChatMessage(role: .assistant, content: "")
            streamingMessage = initialStreamingMessage
            
            // 发送流式请求
            siliconFlowService.sendStreamMessage(
                messages: messages,
                onReceive: { [weak self] contentDelta in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        
                        // 更新流式消息内容
                        if var currentMessage = self.streamingMessage {
                            currentMessage.content += contentDelta
                            self.streamingMessage = currentMessage
                        }
                    }
                },
                onComplete: { [weak self] result in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        
                        self.isLoading = false
                        
                        switch result {
                        case .success:
                            // 将流式消息添加到消息列表
                            if let finalMessage = self.streamingMessage {
                                self.messages.append(finalMessage)
                            }
                            self.streamingMessage = nil
                        case .failure(let error):
                            self.errorMessage = error.localizedDescription
                            self.streamingMessage = nil
                            print("Error: \(error.localizedDescription)")
                        }
                    }
                }
            )
        } else {
            // 使用非流式模式
            siliconFlowService.sendMessage(messages: messages) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    switch result {
                    case .success(let response):
                        self.messages.append(response)
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        print("Error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // 切换流式模式
    func toggleStreamingMode() {
        useStreamingMode.toggle()
    }
    
    // 清空聊天记录
    func clearChat() {
        messages.removeAll { $0.role != .system }
        streamingMessage = nil
    }
} 