import SwiftUI
import SwiftData

struct ChatView: View {
    // 获取SwiftData模型上下文
    @Environment(\.modelContext) private var modelContext
    
    // 查询API密钥配置
    @Query private var apiConfigs: [ApiKeyConfig]
    
    @StateObject private var viewModel = ChatViewModel()
    @State private var showingApiKeyAlert = false
    @State private var apiKeyInput: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("硅基流动 AI 聊天")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    // 预填充现有API密钥
                    if let apiConfig = apiConfigs.first {
                        apiKeyInput = apiConfig.key
                    }
                    showingApiKeyAlert = true
                }) {
                    Image(systemName: "key.fill")
                }
                .padding(.horizontal, 8)
                
                Button(action: {
                    viewModel.clearChat()
                }) {
                    Image(systemName: "trash")
                }
            }
            .padding()
            .background(Color.primary.opacity(0.1))
            
            // 聊天消息列表
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // 显示历史消息
                        ForEach(viewModel.messages.filter { $0.role != .system }) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                        
                        // 显示流式消息（如果有）
                        if let streamingMessage = viewModel.streamingMessage {
                            MessageView(message: streamingMessage, isStreaming: true)
                                .id("streaming")
                                .animation(.default, value: streamingMessage.content)
                        }
                        
                        // 空视图，用于自动滚动到底部
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding()
                }
                // 监听消息数组变化，滚动到最新消息
                .onChange(of: viewModel.messages.count) { oldValue, newValue in
                    withAnimation {
                        scrollView.scrollTo("bottom", anchor: .bottom)
                    }
                }
                // 监听流式内容变化，滚动到流式消息
                .onChange(of: viewModel.streamingContent) { oldValue, newValue in
                    withAnimation {
                        scrollView.scrollTo("streaming", anchor: .bottom)
                    }
                }
                // 当有新的流式消息时滚动到底部
                .onChange(of: viewModel.streamingMessage != nil) { oldValue, newValue in
                    withAnimation {
                        scrollView.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            // 错误提示
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            // 输入区域
            HStack {
                TextField("输入消息...", text: $viewModel.inputText)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                    .disabled(viewModel.isLoading)
                    .onSubmit {
                        if !viewModel.inputText.isEmpty && !viewModel.isLoading {
                            viewModel.sendMessage()
                        }
                    }
                
                Button(action: {
                    viewModel.sendMessage()
                }) {
                    Image(systemName: viewModel.isLoading ? "hourglass" : "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(viewModel.inputText.isEmpty || viewModel.isLoading ? .gray : .blue)
                }
                .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
            }
            .padding()
        }
        .alert("设置 API 密钥", isPresented: $showingApiKeyAlert) {
            TextField("输入 API 密钥", text: $apiKeyInput)
            
            Button("取消", role: .cancel) { }
            
            Button("确定") {
                viewModel.updateApiKey(apiKeyInput)
            }
        } message: {
            Text("请输入硅基流动的 API 密钥")
        }
        .onAppear {
            // 在视图出现时更新ViewModel的modelContext和API密钥
            let initialApiKey = apiConfigs.first?.key ?? ""
            viewModel.setupWithContext(modelContext: modelContext, apiKey: initialApiKey)
        }
    }
}

struct MessageView: View {
    let message: ChatMessage
    var isStreaming: Bool = false
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                
                Text(message.content)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.content)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            Group {
                                if isStreaming {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.blue, lineWidth: 2)
                                }
                            }
                        )
                        // 为消息内容添加动画效果
                        .animation(.default, value: message.content)
                    
                    HStack {
                        Text("硅基流动 AI")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if isStreaming {
                            // 流式输出时显示动画
                            TypingIndicator()
                        }
                    }
                    .padding(.leading, 8)
                }
                
                Spacer()
            }
        }
    }
}

// 打字指示器动画
struct TypingIndicator: View {
    @State private var showDot1 = false
    @State private var showDot2 = false
    @State private var showDot3 = false
    
    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .frame(width: 4, height: 4)
                .opacity(showDot1 ? 1 : 0.2)
            
            Circle()
                .frame(width: 4, height: 4)
                .opacity(showDot2 ? 1 : 0.2)
            
            Circle()
                .frame(width: 4, height: 4)
                .opacity(showDot3 ? 1 : 0.2)
        }
        .foregroundColor(.gray)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        let animation = Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true)
        
        withAnimation(animation) {
            showDot1 = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(animation) {
                showDot2 = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(animation) {
                showDot3 = true
            }
        }
    }
}

#Preview {
    ChatView()
}
