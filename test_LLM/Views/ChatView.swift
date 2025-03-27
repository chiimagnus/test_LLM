//
//  ChatView.swift
//  test_LLM
//
//  Created by Trae AI on 2025/3/27.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Message.timestamp, order: .forward) private var messages: [Message]
    @State private var newMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var showingClearConfirmation: Bool = false
    @State private var isThinkingModeEnabled: Bool = false
    @State private var currentResponse: String = ""
    @State private var currentReasoning: String = ""
    
    private let llmService = LLMService()
    @AppStorage("apiKey") private var apiKey: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty && !isLoading {
                ContentUnavailableView {
                    Label("没有消息", systemImage: "message")
                } description: {
                    Text("开始与AI助手对话吧")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack {
                            ForEach(messages) { message in
                                MessageRow(message: message, showReasoning: isThinkingModeEnabled)
                                    .id(message.id)
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                            }
                            
                            // 显示当前正在流式生成的回复
                            if isLoading {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .font(.title)
                                    VStack(alignment: .leading, spacing: 8) {
                                        if isThinkingModeEnabled && !currentReasoning.isEmpty {
                                            Text("思考过程:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(currentReasoning)
                                                .padding()
                                                .background(Color.yellow.opacity(0.2))
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                        
                                        if !currentResponse.isEmpty {
                                            Text(currentResponse)
                                                .padding()
                                                .background(Color.gray.opacity(0.2))
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        } else {
                                            ProgressView()
                                                .padding()
                                        }
                                    }
                                    Spacer()
                                }
                                .id("loading")
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: currentResponse) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: currentReasoning) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            
            Divider()
            
            VStack(spacing: 8) {
                // 思考模式开关
                Toggle("思考模式", isOn: $isThinkingModeEnabled)
                    .onChange(of: isThinkingModeEnabled) { _, newValue in
                        llmService.setThinkingEnabled(newValue)
                    }
                    .padding(.horizontal)
                
                HStack {
                    TextField("输入消息...", text: $newMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isLoading)
                    
                    Button(action: sendMessage) {
                        Image(systemName: isLoading ? "hourglass" : "paperplane.fill")
                    }
                    .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .padding(.horizontal)
                
                if apiKey.isEmpty {
                    HStack {
                        Text("请设置API密钥:")
                        SecureField("API密钥", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("AI聊天")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: showClearConfirmation) {
                    Label("清空聊天", systemImage: "trash")
                }
                .disabled(messages.isEmpty)
            }
            #else
            ToolbarItem {
                Button(action: showClearConfirmation) {
                    Label("清空聊天", systemImage: "trash")
                }
                .disabled(messages.isEmpty)
            }
            #endif
        }
        .onAppear {
            llmService.setAPIKey(apiKey)
            llmService.setThinkingEnabled(isThinkingModeEnabled)
        }
        .onChange(of: apiKey) { _, newValue in
            llmService.setAPIKey(newValue)
        }
        .alert("确认清空聊天记录", isPresented: $showingClearConfirmation) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                clearAllMessages()
            }
        } message: {
            Text("此操作将删除所有聊天记录且无法恢复，是否继续？")
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if isLoading {
            withAnimation {
                proxy.scrollTo("loading", anchor: .bottom)
            }
        } else if let lastMessage = messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func sendMessage() {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = Message(content: newMessage, isUserMessage: true)
        modelContext.insert(userMessage)
        newMessage = ""
        isLoading = true
        currentResponse = ""
        currentReasoning = ""
        
        // 准备消息历史
        // 添加系统消息作为第一条消息
        var messageHistory: [[String: Any]] = [
            ["role": "system", "content": "你是一个助手，请回答用户的问题。"]
        ]
        
        // 添加用户和助手的对话历史
        let userAssistantMessages = messages.map { message in
            ["role": message.isUserMessage ? "user" : "assistant", "content": message.content]
        }
        
        // 合并所有消息
        messageHistory.append(contentsOf: userAssistantMessages)
        
        // 使用支持思考模式和流式输出的方法，并添加流式更新回调
        llmService.sendMessageWithThinking(
            messages: messageHistory,
            streamCallback: { content, reasoning in
                // 更新UI显示的实时内容
                self.currentResponse = content
                if let reasoning = reasoning {
                    self.currentReasoning = reasoning
                }
            },
            completion: { result in
                switch result {
                case .success(let response):
                    DispatchQueue.main.async {
                        // 保存完整响应
                        let assistantMessage = Message(
                            content: response.content,
                            isUserMessage: false,
                            reasoningContent: response.reasoningContent
                        )
                        self.modelContext.insert(assistantMessage)
                        self.isLoading = false
                        self.currentResponse = ""
                        self.currentReasoning = ""
                    }
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        let errorMessage = Message(
                            content: "错误: \(error.localizedDescription)",
                            isUserMessage: false
                        )
                        self.modelContext.insert(errorMessage)
                        self.isLoading = false
                        self.currentResponse = ""
                        self.currentReasoning = ""
                    }
                }
            }
        )
    }
    
    private func showClearConfirmation() {
        showingClearConfirmation = true
    }
    
    private func clearAllMessages() {
        withAnimation {
            for message in messages {
                modelContext.delete(message)
            }
        }
    }
}

struct MessageRow: View {
    let message: Message
    let showReasoning: Bool
    
    var body: some View {
        VStack(alignment: message.isUserMessage ? .trailing : .leading, spacing: 8) {
            HStack(alignment: .top) {
                if !message.isUserMessage {
                    Image(systemName: "brain.head.profile")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: message.isUserMessage ? .trailing : .leading, spacing: 8) {
                    // 先显示思考内容（如果有）
                    if showReasoning && !message.isUserMessage, let reasoning = message.reasoningContent, !reasoning.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("思考过程:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(reasoning)
                                .padding()
                                .background(Color.yellow.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    
                    // 显示正文内容
                    Text(message.content)
                        .padding()
                        .background(message.isUserMessage ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(message.isUserMessage ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                if message.isUserMessage {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUserMessage ? .trailing : .leading)
    }
}

#Preview {
    ChatView()
        .modelContainer(for: Message.self, inMemory: true)
}