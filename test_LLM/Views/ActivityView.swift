//
//  ActivityView.swift
//  test_LLM
//
//  Created by Trae AI on 2025/3/27.
//

import SwiftUI
import SwiftData

struct ActivityView: View {
    @Environment(.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @State private var isGeneratingSummary: Bool = false
    @State private var newActivityDescription: String = ""
    
    private let llmService = LLMService()
    @AppStorage("apiKey") private var apiKey: String = ""
    
    var body: some View {
        List {
            Section(header: Text("添加新活动")) {
                HStack {
                    TextField("活动描述", text: $newActivityDescription)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: addActivity) {
                        Label("添加", systemImage: "plus")
                    }
                    .disabled(newActivityDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.vertical, 4)
            }
            
            if !items.isEmpty {
                Section(header: Text("活动总结")) {
                    if isGeneratingSummary {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    } else {
                        Button(action: generateSummary) {
                            Label("生成活动总结", systemImage: "text.badge.checkmark")
                        }
                        .disabled(apiKey.isEmpty)
                        
                        if let summary = items.first?.summary, !summary.isEmpty {
                            Text(summary)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            
            Section(header: Text("活动记录")) {
                if items.isEmpty {
                    Text("没有活动记录")
                        .foregroundColor(.gray)
                        .italic()
                } else {
                    ForEach(items) { item in
                        VStack(alignment: .leading) {
                            Text(item.description)
                                .font(.headline)
                            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteItems)
                }
            }
        }
        .navigationTitle("活动记录")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            #endif
        }
        .onAppear {
            llmService.setAPIKey(apiKey)
        }
        .onChange(of: apiKey) { _, newValue in
            llmService.setAPIKey(newValue)
        }
    }
    
    private func addActivity() {
        guard !newActivityDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        withAnimation {
            let newItem = Item(timestamp: Date(), description: newActivityDescription)
            modelContext.insert(newItem)
            newActivityDescription = ""
        }
    }
    
    private func generateSummary() {
        guard !items.isEmpty && !apiKey.isEmpty else { return }
        
        isGeneratingSummary = true
        
        llmService.summarizeActivities(activities: items) { result in
            DispatchQueue.main.async {
                isGeneratingSummary = false
                
                switch result {
                case .success(let summary):
                    if let firstItem = items.first {
                        firstItem.summary = summary
                    }
                case .failure(let error):
                    print("生成总结失败: \(error.localizedDescription)")
                    // 在实际应用中，应该向用户显示错误信息
                }
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ActivityView()
        .modelContainer(for: Item.self, inMemory: true)
}