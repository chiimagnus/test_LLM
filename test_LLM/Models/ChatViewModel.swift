import Foundation
import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
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
        
        // 发送请求到硅基流动API
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
    
    // 清空聊天记录
    func clearChat() {
        messages.removeAll { $0.role != .system }
    }
} 