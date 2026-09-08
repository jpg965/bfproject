# OpenCode Mobile

iOS 客户端，通过 Tailscale 远程连接开发机上运行的 [opencode](https://opencode.ai) server，在 iPhone 上实现移动端 AI 编码协作。

## 功能

### Phase 1 (MVP - 当前)
- 对话式编码：创建会话、发送消息、实时接收 AI 流式回复
- 会话管理：列表、切换、删除
- 实时监控：前台 SSE 事件流
- 本地缓存：SwiftData 离线查看历史会话和消息
- 后台轮询：App 进入后台时自动检查新消息

### Phase 2 (计划中)
- 代码 Diff 审查
- 权限审批 (approve/reject)

### Phase 3 (计划中)
- 文件浏览

## 架构

- **语言**: Swift / SwiftUI
- **架构模式**: MVVM + `@Observable` (iOS 17+)
- **最低版本**: iOS 17.0
- **本地存储**: SwiftData
- **网络**: URLSession (REST API + SSE)
- **密码存储**: Keychain

## 项目结构

```
OpenCodeMobile/
├── OpenCodeMobileApp.swift          # App 入口
├── Models/
│   ├── Session.swift                 # 会话数据模型
│   ├── Message.swift                 # 消息和 Part 模型
│   └── ServerConfig.swift            # 服务器配置 + SSE 事件模型
├── Networking/
│   ├── APIEndpoint.swift             # API 端点定义 + 错误类型
│   ├── APIClient.swift               # opencode REST API 客户端
│   └── SSEClient.swift               # SSE 事件流客户端
├── Persistence/
│   └── DataStore.swift               # SwiftData 持久化层
├── Utilities/
│   ├── KeychainHelper.swift          # Keychain 封装
│   └── AppLifecycleManager.swift     # 前台/后台生命周期管理
├── ViewModels/
│   ├── ConnectionViewModel.swift     # 连接配置 + 状态
│   ├── SessionListViewModel.swift    # 会话列表管理
│   └── ChatViewModel.swift           # 聊天交互 + 流式接收
└── Views/
    ├── ContentView.swift              # 主界面 (TabView)
    ├── SessionListView.swift          # 会话列表页
    ├── ChatView.swift                 # 聊天页
    ├── MessageRowView.swift           # 消息气泡 + Markdown/代码渲染
    └── SettingsView.swift             # 设置页
```

## 环境准备

### 1. 安装 opencode (开发机)

```bash
curl -fsSL https://opencode.ai/install | bash
```

### 2. 安装 Tailscale

**开发机 (Mac/Linux)**:
```bash
# Mac: 从 Mac App Store 安装 Tailscale
# 或 brew install --cask tailscale

# Linux:
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

**iPhone**: 从 App Store 搜索安装 Tailscale，登录同一账号

### 3. 获取开发机 Tailscale IP

```bash
tailscale ip -4
# 输出类似: 100.64.0.1
```

### 4. 启动 opencode server

```bash
# 设置密码 (Basic Auth)
export OPENCODE_SERVER_PASSWORD="your-secret-password"

# 启动无头服务器，监听所有接口
opencode serve --hostname 0.0.0.0 --port 4096
```

### 5. Xcode 项目创建

由于无法在沙箱中生成 `.xcodeproj`，请在你的 Mac 上：

1. 打开 Xcode → File → New → Project
2. 选择 iOS → App
3. Product Name: `OpenCodeMobile`
4. Interface: SwiftUI
5. Language: Swift
6. Minimum Deployments: iOS 17.0
7. 创建后，将本项目的所有 `.swift` 文件拖入项目（按目录分组）
8. 删除 Xcode 自动生成的 `ContentView.swift` 和 `App.swift`（用本项目的替代）

## 配置 App

1. 在 iPhone 上打开 App
2. 进入「设置」Tab
3. 填入:
   - Tailscale IP (如 `100.64.0.1`)
   - 端口: `4096`
   - 用户名: `opencode` (默认)
   - 密码: 你设置的 `OPENCODE_SERVER_PASSWORD`
4. 点击「测试连接」
5. 连接成功后点击「连接并启动实时事件」

## 使用流程

1. 打开 App → 自动连接 (如已配置)
2. 「会话」Tab → 点 `+` 创建新会话
3. 输入 prompt → 发送
4. AI 回复实时流式显示 (通过 SSE)
5. App 进入后台时自动轮询新消息
6. 回到前台自动重连 SSE + 拉取增量消息

## 后续优化建议

- [ ] 集成 MarkdownUI 或 SiriusMarkdown 替代 SimpleMarkdownView
- [ ] 集成 Highlightr 做代码语法高亮
- [ ] 添加推送通知 (Phase 2)
- [ ] 代码 Diff 审查界面 (Phase 2)
- [ ] 权限审批交互 (Phase 2)
- [ ] 文件浏览器 (Phase 3)
- [ ] 多服务器配置管理
- [ ] 会话搜索/过滤
- [ ] 暗色/亮色主题切换
- [ ] iPad 适配

## 技术决策说明

| 决策 | 选择 | 理由 |
|------|------|------|
| 框架 | SwiftUI 原生 | 最佳 iOS 体验，深度系统集成 |
| 架构 | MVVM + @Observable | 零基础友好，样板代码少 |
| iOS 版本 | 17+ | SwiftData + @Observable 需要 |
| 网络连接 | Tailscale | 零配置组网，端到端加密 |
| 认证 | Tailscale + Basic Auth | 双重保险 |
| 后台策略 | 前台 SSE + 后台轮询 | iOS 对后台 URLSession 有硬限制 |
| 本地缓存 | SwiftData | iOS 17 原生，与 @Observable 配合 |
| Markdown | 混合方案 | 库渲染 Markdown + Highlightr 代码高亮 |
