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
    @Query private var messages: [Message]
    @State private var newMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var showingClearConfirmation: Bool = false
    
    private let llmService = LLMService()
    @AppStorage("apiKey") private var apiKey: String = ""
    
    var body: some View {
        VStack {
            if messages.isEmpty {
                ContentUnavailableView {
                    Label("没有消息", systemImage: "message")
                } description: {
                    Text("开始与AI助手对话吧")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            HStack {
                TextField("输入消息...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isLoading)
                
                Button(action: sendMessage) {
                    Image(systemName: isLoading ? "hourglass" : "paperplane.fill")
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding()
            
            if apiKey.isEmpty {
                HStack {
                    Text("请设置API密钥:")
                    SecureField("API密钥", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
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
    
    private func sendMessage() {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = Message(content: newMessage, isUserMessage: true)
        modelContext.insert(userMessage)
        newMessage = ""
        isLoading = true
        
        // 准备消息历史
        let messageHistory = messages.map { message in
            ["role": message.isUserMessage ? "user" : "assistant", "content": message.content]
        }
        
        llmService.sendMessage(messages: messageHistory) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    let assistantMessage = Message(content: response, isUserMessage: false)
                    modelContext.insert(assistantMessage)
                    
                case .failure(let error):
                    let errorMessage = Message(content: "错误: \(error.localizedDescription)", isUserMessage: false)
                    modelContext.insert(errorMessage)
                }
            }
        }
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
    
    var body: some View {
        HStack {
            if message.isUserMessage {
                Spacer()
                Text(message.content)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Image(systemName: "person.circle.fill")
                    .font(.title)
            } else {
                Image(systemName: "brain.head.profile")
                    .font(.title)
                Text(message.content)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ChatView()
        .modelContainer(for: Message.self, inMemory: true)
}