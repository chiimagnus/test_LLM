import Foundation
import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // 用于流式输出的临时消息
    @Published var streamingMessage: ChatMessage?
    // 添加一个单独的属性来跟踪流式内容，便于UI响应变化
    @Published var streamingContent: String = ""
    
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
        
        // 重置流式内容
        streamingContent = ""
        
        // 创建一个空的流式消息
        let initialStreamingMessage = ChatMessage(role: .assistant, content: "")
        streamingMessage = initialStreamingMessage
        
        // 发送流式请求
        siliconFlowService.sendStreamMessage(
            messages: messages,
            onReceive: { [weak self] contentDelta in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    print("收到内容片段: '\(contentDelta)'")
                    
                    // 更新流式内容
                    self.streamingContent += contentDelta
                    
                    // 创建新的消息对象并替换，确保触发UI更新
                    let updatedMessage = ChatMessage(role: .assistant, content: self.streamingContent)
                    self.streamingMessage = updatedMessage
                }
            },
            onComplete: { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    switch result {
                    case .success:
                        // 将流式消息添加到消息列表
                        if let finalMessage = self.streamingMessage, !finalMessage.content.isEmpty {
                            self.messages.append(finalMessage)
                        }
                        self.streamingMessage = nil
                        self.streamingContent = ""
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        self.streamingMessage = nil
                        self.streamingContent = ""
                        print("Error: \(error.localizedDescription)")
                    }
                }
            }
        )
    }
    
    // 清空聊天记录
    func clearChat() {
        messages.removeAll { $0.role != .system }
        streamingMessage = nil
        streamingContent = ""
    }
} 