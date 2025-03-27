# Test LLM
使用swiftUI 和 swiftData 简单制作一调用LLM的iOS、macOS双平台的app。

## 功能
### 1.直接跟LLM对话
- 调用硅基流动API，实现实时对话功能
- 流式显示AI回复
- 保存对话历史

### 2.LLM读取用户活动记录，给出简短总结
- 记录用户日常活动
- 添加活动标签分类
- 使用LLM分析用户活动，生成简短总结

## 技术
- 调用[硅基流动](https://cloud.siliconflow.cn)的API
- 具体模型为deepseek-ai/DeepSeek-R1-Distill-Qwen-7B
- 使用SwiftUI构建跨平台界面
- 使用SwiftData进行数据持久化

## 文件结构
```
test_LLM/
├── test_LLMApp.swift        // 应用入口
├── ContentView.swift        // 主视图（TabView）
├── Views/
│   ├── ChatView.swift       // 聊天视图
│   └── ActivityView.swift   // 活动记录视图
├── Models/
│   ├── ChatMessage.swift    // 聊天消息模型
│   ├── PersistenceModels.swift // 持久化模型
│   ├── ChatViewModel.swift  // 聊天视图模型
│   ├── SiliconFlowRequest.swift // 请求模型
│   ├── SiliconFlowResponse.swift // 响应模型
│   └── SiliconFlowStreamResponse.swift // 流式响应模型
└── Services/
    └── SiliconFlowService.swift // API服务
``` 