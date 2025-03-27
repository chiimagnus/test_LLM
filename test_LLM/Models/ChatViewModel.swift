import Foundation
import SwiftUI
import Combine
import SwiftData

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
    
    // SwiftData 模型上下文
    private var modelContext: ModelContext?
    // 当前会话
    private var currentSession: ChatSession?
    
    init(apiKey: String = "", modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        self.siliconFlowService = SiliconFlowService(apiKey: apiKey)
        
        // 添加初始系统消息
        messages.append(ChatMessage(role: .system, content: "你是一个友好的AI助手，能够用中文回答用户的问题。"))
        
        if modelContext != nil {
            // 加载API密钥
            loadApiKey()
            // 加载或创建聊天会话
            loadOrCreateChatSession()
        }
    }
    
    // 新增：设置模型上下文和API密钥
    func setupWithContext(modelContext: ModelContext, apiKey: String = "") {
        self.modelContext = modelContext
        
        // 如果提供了API密钥，更新服务
        if !apiKey.isEmpty {
            self.siliconFlowService = SiliconFlowService(apiKey: apiKey)
        }
        
        // 加载API密钥
        loadApiKey()
        // 加载或创建聊天会话
        loadOrCreateChatSession()
    }
    
    // 加载存储的API密钥
    private func loadApiKey() {
        guard let modelContext = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<ApiKeyConfig>()
            let apiConfigs = try modelContext.fetch(descriptor)
            
            if let apiConfig = apiConfigs.first {
                self.siliconFlowService = SiliconFlowService(apiKey: apiConfig.key)
            }
        } catch {
            print("加载API密钥失败: \(error)")
        }
    }
    
    // 加载或创建聊天会话
    private func loadOrCreateChatSession() {
        guard let modelContext = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<ChatSession>()
            let sessions = try modelContext.fetch(descriptor)
            
            if let session = sessions.first {
                // 使用现有会话
                self.currentSession = session
                // 加载消息
                self.messages = []
                // 保留系统消息
                self.messages.append(ChatMessage(role: .system, content: "你是一个友好的AI助手，能够用中文回答用户的问题。"))
                // 加载历史消息
                for message in session.messages {
                    if message.role != "system" {
                        self.messages.append(message.toChatMessage())
                    }
                }
            } else {
                // 创建新会话
                let newSession = ChatSession()
                modelContext.insert(newSession)
                self.currentSession = newSession
                try modelContext.save()
            }
        } catch {
            print("加载聊天会话失败: \(error)")
        }
    }
    
    // 更新API密钥并持久化
    func updateApiKey(_ key: String) {
        guard let modelContext = modelContext else {
            // 如果没有模型上下文，只更新服务
            self.siliconFlowService = SiliconFlowService(apiKey: key)
            return
        }
        
        // 更新服务
        self.siliconFlowService = SiliconFlowService(apiKey: key)
        
        do {
            // 查询现有密钥
            let descriptor = FetchDescriptor<ApiKeyConfig>()
            let apiConfigs = try modelContext.fetch(descriptor)
            
            if let apiConfig = apiConfigs.first {
                // 更新现有密钥
                apiConfig.key = key
            } else {
                // 创建新密钥
                let apiConfig = ApiKeyConfig(key: key)
                modelContext.insert(apiConfig)
            }
            
            // 保存更改
            try modelContext.save()
        } catch {
            print("保存API密钥失败: \(error)")
        }
    }
    
    // 发送消息并持久化
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(role: .user, content: inputText)
        messages.append(userMessage)
        
        // 持久化用户消息
        saveMessage(userMessage)
        
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
                            // 持久化助手回复
                            self.saveMessage(finalMessage)
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
    
    // 保存消息到持久化存储
    private func saveMessage(_ message: ChatMessage) {
        guard let modelContext = modelContext, let currentSession = currentSession else { return }
        
        do {
            // 创建持久化消息
            let persistentMessage = PersistentChatMessage(from: message)
            
            // 将消息添加到当前会话
            currentSession.messages.append(persistentMessage)
            currentSession.updateTimestamp()
            
            // 保存更改
            try modelContext.save()
        } catch {
            print("保存消息失败: \(error)")
        }
    }
    
    // 清空聊天记录（保留系统消息）
    func clearChat() {
        messages.removeAll { $0.role != .system }
        streamingMessage = nil
        streamingContent = ""
        
        // 清除持久化的聊天记录
        clearPersistedMessages()
    }
    
    // 清除持久化的聊天记录
    private func clearPersistedMessages() {
        guard let modelContext = modelContext, let currentSession = currentSession else { return }
        
        // 移除所有消息
        currentSession.messages.removeAll()
        currentSession.updateTimestamp()
        
        do {
            // 保存更改
            try modelContext.save()
        } catch {
            print("清除聊天记录失败: \(error)")
        }
    }
} 