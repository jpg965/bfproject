import SwiftUI

// MARK: - ChatView
// 聊天界面: 消息列表 + 输入框

struct ChatView: View {
    let session: Session

    @Environment(ConnectionViewModel.self) private var connectionVM
    @Environment(APIClient.self) private var apiClient
    @Environment(DataStore.self) private var dataStore
    @Environment(SSEClient.self) private var sseClient

    @State private var chatVM: ChatViewModel?
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        Group {
            if let vm = chatVM {
                chatContent(vm: vm)
            } else {
                ProgressView("正在加载会话...")
                    .onAppear {
                        chatVM = ChatViewModel(
                            sessionID: session.id,
                            apiClient: apiClient,
                            dataStore: dataStore,
                            sseClient: sseClient
                        )
                        Task { await chatVM?.fetchMessages() }
                    }
            }
        }
        .navigationTitle(session.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 聊天内容

    private func chatContent(vm: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if vm.isLoading && vm.messages.isEmpty {
                            ProgressView("加载中...")
                                .padding()
                        }

                        ForEach(vm.messages) { message in
                            MessageRowView(message: message, isUser: vm.isUserMessage(message))
                                .id(message.id)
                        }

                        // 流式输出指示器
                        if vm.isStreaming {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("AI 正在回复...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading)
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.messages.count) { _, _ in
                    withAnimation {
                        if let lastID = vm.messages.last?.id {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: vm.streamingText) { _, _ in
                    withAnimation(.linear(duration: 0.1)) {
                        if let lastID = vm.messages.last?.id {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }

            // 错误提示
            if let error = vm.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
            }

            // 输入栏
            inputBar(vm: vm)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if vm.isStreaming {
                    Button {
                        Task { await vm.abortSession() }
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .onAppear {
            isInputFocused = false
        }
    }

    // MARK: - 输入栏

    private func inputBar(vm: ChatViewModel) -> some View {
        HStack(spacing: 8) {
            // 文本输入框
            TextField("输入消息...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .submitLabel(.send)
                .onSubmit {
                    sendMessage(vm: vm)
                }

            // 发送按钮
            Button {
                sendMessage(vm: vm)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(inputText.isEmpty || vm.isSending ? .gray : .accentColor)
            }
            .disabled(inputText.isEmpty || vm.isSending || vm.isStreaming)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    // MARK: - 发送

    private func sendMessage(vm: ChatViewModel) {
        let text = inputText
        inputText = ""
        Task { await vm.sendMessage(text: text) }
    }
}
