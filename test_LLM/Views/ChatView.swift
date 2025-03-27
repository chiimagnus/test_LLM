import SwiftUI

struct ChatView: View {
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
                    showingApiKeyAlert = true
                }) {
                    Image(systemName: "key.fill")
                }
                .padding(.horizontal)
                
                Button(action: {
                    viewModel.clearChat()
                }) {
                    Image(systemName: "trash")
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            
            // 聊天消息列表
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages.filter { $0.role != .system }) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages) { messages in
                    if let lastMessage = messages.last {
                        withAnimation {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
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
                    .background(Color(UIColor.secondarySystemBackground))
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
    }
}

struct MessageView: View {
    let message: ChatMessage
    
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
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    Text("硅基流动 AI")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    ChatView()
}
