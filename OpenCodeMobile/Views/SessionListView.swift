import SwiftUI

// MARK: - SessionListView
// 会话列表: 拉取、创建、删除、切换

struct SessionListView: View {
    @Environment(ConnectionViewModel.self) private var connectionVM
    @Environment(APIClient.self) private var apiClient
    @Environment(DataStore.self) private var dataStore
    @Environment(SSEClient.self) private var sseClient

    @State private var sessionListVM: SessionListViewModel?
    @State private var showNewSession = false
    @State private var newSessionTitle = ""
    @State private var selectedSession: Session?

    var body: some View {
        Group {
            if let vm = sessionListVM {
                sessionListContent(vm: vm)
            } else {
                ProgressView("正在加载...")
                    .onAppear {
                        sessionListVM = SessionListViewModel(
                            apiClient: apiClient,
                            dataStore: dataStore,
                            sseClient: sseClient
                        )
                        Task { await sessionListVM?.fetchSessions() }
                    }
            }
        }
        .navigationTitle("会话")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewSession = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Task { await sessionListVM?.fetchSessions() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showNewSession) {
            newSessionSheet
        }
        .navigationDestination(item: $selectedSession) { session in
            ChatView(session: session)
        }
    }

    // MARK: - 会话列表内容

    private func sessionListContent(vm: SessionListViewModel) -> some View {
        Group {
            if vm.sessions.isEmpty && !vm.isLoading {
                ContentUnavailableView {
                    Label("没有会话", systemImage: "bubble.left")
                } description: {
                    Text("点击右上角 + 创建新会话")
                }
            } else {
                List {
                    ForEach(vm.sessions) { session in
                        Button {
                            selectedSession = session
                        } label: {
                            SessionRowView(session: session, isRunning: vm.isRunning(session.id))
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await vm.deleteSession(id: session.id) }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .refreshable {
                    await vm.fetchSessions()
                }
            }
        }
        .overlay {
            if vm.isLoading && vm.sessions.isEmpty {
                ProgressView("正在加载会话...")
            }
        }
        .alert("错误", isPresented: .constant(vm.errorMessage != nil)) {
            Button("确定") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - 新建会话弹窗

    private var newSessionSheet: some View {
        NavigationStack {
            Form {
                TextField("标题 (可选)", text: $newSessionTitle)
            }
            .navigationTitle("新建会话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        showNewSession = false
                        newSessionTitle = ""
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("创建") {
                        Task {
                            if let session = await sessionListVM?.createSession(title: newSessionTitle.isEmpty ? nil : newSessionTitle) {
                                showNewSession = false
                                newSessionTitle = ""
                                selectedSession = session
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - SessionRowView

struct SessionRowView: View {
    let session: Session
    let isRunning: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                if let date = session.createdDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isRunning {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                        .opacity(0.6)
                        .scaleEffect(isRunning ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(),
                            value: isRunning
                        )
                    Text("运行中")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
