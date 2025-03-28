import SwiftUI
import SwiftData

struct ActivityView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var activities: [ActivityRecord]
    @State private var newActivityContent: String = ""
    @State private var showingAddActivity: Bool = false
    @State private var selectedTags: [String] = []
    @State private var newTag: String = ""
    @State private var showingSummary: Bool = false
    @State private var summaryContent: String = ""
    @State private var isGeneratingSummary: Bool = false
    @State private var errorMessage: String? = nil
    
    // 获取API密钥
    @Query private var apiConfigs: [ApiKeyConfig]
    
    // 预定义标签
    let predefinedTags = ["工作", "学习", "娱乐", "生活", "健康", "其他"]
    
    // 日期格式化器
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("活动记录")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    generateSummary()
                }) {
                    Image(systemName: "sparkles")
                }
                .disabled(activities.isEmpty || isGeneratingSummary)
                .padding(.horizontal, 8)
                
                Button(action: {
                    showingAddActivity = true
                    newActivityContent = ""
                    selectedTags = []
                }) {
                    Image(systemName: "plus")
                }
            }
            .padding()
            .background(Color.primary.opacity(0.1))
            
            // 活动记录列表
            if activities.isEmpty {
                VStack {
                    Spacer()
                    Text("暂无活动记录")
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                List {
                    ForEach(activities.sorted(by: { $0.timestamp > $1.timestamp })) { activity in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(activity.content)
                                .font(.body)
                            
                            HStack {
                                Text(dateFormatter.string(from: activity.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                // 显示标签
                                ForEach(activity.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .onDelete(perform: deleteActivities)
                }
            }
            
            // 错误提示
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingAddActivity) {
            addActivityView
        }
        .sheet(isPresented: $showingSummary) {
            summaryView
        }
    }
    
    // 添加活动的视图
    private var addActivityView: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("添加活动记录")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
            
            Form {
                Section(header: Text("活动内容").font(.headline)) {
                    TextEditor(text: $newActivityContent)
                        .frame(minHeight: 120)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                }
                
                Section(header: Text("选择标签").font(.headline)) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(predefinedTags, id: \.self) { tag in
                                TagButton(tag: tag, isSelected: selectedTags.contains(tag)) {
                                    withAnimation(.spring()) {
                                        if selectedTags.contains(tag) {
                                            selectedTags.removeAll { $0 == tag }
                                        } else {
                                            selectedTags.append(tag)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("添加自定义标签").font(.headline)) {
                    HStack {
                        TextField("新标签", text: $newTag)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: {
                            let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmedTag.isEmpty && !selectedTags.contains(trimmedTag) {
                                withAnimation {
                                    selectedTags.append(trimmedTag)
                                    newTag = ""
                                }
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                        }
                        .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                
                if !selectedTags.isEmpty {
                    Section(header: Text("已选标签").font(.headline)) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedTags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        
                                        Button(action: {
                                            withAnimation {
                                                selectedTags.removeAll { $0 == tag }
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            // 底部操作栏
            HStack {
                Button(action: {
                    showingAddActivity = false
                }) {
                    Text("取消")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    addActivity()
                    showingAddActivity = false
                }) {
                    Text("保存")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(newActivityContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: -2)
        }
        .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity,
               minHeight: 500, idealHeight: 600, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.05))
    }
    
    // 总结视图
    private var summaryView: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("活动总结")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    showingSummary = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
            
            ScrollView {
                Text(summaryContent)
                    .font(.body)
                    .padding()
            }
            .background(Color.secondary.opacity(0.05))
        }
        .frame(minWidth: 400, idealWidth: 500, maxWidth: .infinity,
               minHeight: 300, idealHeight: 400, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.05))
    }
    
    // 添加活动
    private func addActivity() {
        let trimmedContent = newActivityContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContent.isEmpty {
            let activity = ActivityRecord(
                content: trimmedContent,
                timestamp: Date(),
                tags: selectedTags
            )
            modelContext.insert(activity)
            
            do {
                try modelContext.save()
            } catch {
                errorMessage = "保存失败: \(error.localizedDescription)"
            }
        }
    }
    
    // 删除活动
    private func deleteActivities(at offsets: IndexSet) {
        // 由于我们已经对显示的数组进行了排序，需要确保删除正确的项目
        let sortedActivities = activities.sorted(by: { $0.timestamp > $1.timestamp })
        for index in offsets {
            modelContext.delete(sortedActivities[index])
        }
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }
    
    // 生成总结
    private func generateSummary() {
        guard !activities.isEmpty else { return }
        guard let apiKey = apiConfigs.first?.key, !apiKey.isEmpty else {
            errorMessage = "请先设置API密钥"
            return
        }
        
        isGeneratingSummary = true
        errorMessage = nil
        showingSummary = true
        
        // 准备活动数据
        let sortedActivities = activities.sorted(by: { $0.timestamp > $1.timestamp })
        var activitiesText = "以下是用户近期的活动记录：\n\n"
        
        for activity in sortedActivities {
            let dateString = dateFormatter.string(from: activity.timestamp)
            let tagsString = activity.tags.isEmpty ? "" : " [标签: \(activity.tags.joined(separator: ", "))]"
            activitiesText += "- \(dateString)\(tagsString): \(activity.content)\n"
        }
        
        // 创建系统提示
        let prompt = """
        你是一位贴心的助手，请根据用户提供的活动记录，生成一份简短的总结。
        总结应该包括以下几个方面：
        1. 用户最近的活动模式和趋势
        2. 基于标签分类的活动分布
        3. 对用户活动的简短分析和建议
        
        请使用友好的语气，总结控制在300字以内。
        """
        
        // 创建消息数组
        let messages = [
            ChatMessage(role: .system, content: prompt),
            ChatMessage(role: .user, content: activitiesText)
        ]
        
        // 创建服务并发送请求
        let service = SiliconFlowService(apiKey: apiKey)
        
        var generatedContent = ""
        
        service.sendStreamMessage(
            messages: messages,
            onReceive: { content in
                generatedContent += content
                summaryContent = generatedContent
            },
            onComplete: { result in
                isGeneratingSummary = false
                
                switch result {
                case .success:
                    // 总结生成成功，不需要额外处理
                    break
                case .failure(let error):
                    errorMessage = "生成总结失败: \(error.localizedDescription)"
                }
            }
        )
    }
}

// 标签按钮组件
struct TagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.trailing, 5)
    }
}

#Preview {
    ActivityView()
} 