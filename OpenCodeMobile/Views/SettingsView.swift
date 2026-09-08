import SwiftUI

// MARK: - SettingsView
// 设置页面: 服务器配置、密码管理、连接测试

struct SettingsView: View {
    @Environment(ConnectionViewModel.self) private var connectionVM

    @State private var hostname = ""
    @State private var port = "4096"
    @State private var useHTTPS = false
    @State private var username = "opencode"
    @State private var password = ""
    @State private var showSaveAlert = false

    var body: some View {
        Form {
            // MARK: - 服务器配置
            Section {
                TextField("Tailscale IP / 域名", text: $hostname)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                TextField("端口", text: $port)
                    .keyboardType(.numberPad)

                Toggle("使用 HTTPS", isOn: $useHTTPS)

                TextField("用户名", text: $username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                SecureField("密码", text: $password)
            } header: {
                Text("服务器配置")
            } footer: {
                Text("开发机上执行: `opencode serve --hostname 0.0.0.0 --port 4096` 并设置 `OPENCODE_SERVER_PASSWORD` 环境变量")
            }

            // MARK: - 连接状态
            Section {
                HStack {
                    Circle()
                        .fill(connectionVM.connectionState.color)
                        .frame(width: 12, height: 12)
                    Text(connectionVM.connectionState.displayText)
                }

                if let version = connectionVM.serverVersion {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("OpenCode v\(version)")
                    }
                    .foregroundStyle(.secondary)
                }

                Button("测试连接") {
                    saveConfig()
                    Task { await connectionVM.testConnection() }
                }

                Button("连接并启动实时事件") {
                    saveConfig()
                    connectionVM.connect()
                }
                .disabled(hostname.isEmpty || password.isEmpty)
            } header: {
                Text("连接")
            }

            // MARK: - 网络说明
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Tailscale", systemImage: "network")
                        .font(.headline)
                    Text("1. 在开发机和 iPhone 上安装 Tailscale")
                    Text("2. 开发机执行: opencode serve --hostname 0.0.0.0")
                    Text("3. 设置环境变量: OPENCODE_SERVER_PASSWORD=你的密码")
                    Text("4. 在此处填入开发机的 Tailscale IP")
                    Text("5. 确保 iPhone 的 Tailscale 处于开启状态")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text("使用说明")
            }

            // MARK: - 关于
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("关于")
            }
        }
        .navigationTitle("设置")
        .onAppear {
            // 加载当前配置
            hostname = connectionVM.serverConfig.hostname
            port = String(connectionVM.serverConfig.port)
            useHTTPS = connectionVM.serverConfig.useHTTPS
            username = connectionVM.serverConfig.username
            password = connectionVM.password
        }
        .alert("已保存", isPresented: $showSaveAlert) {
            Button("确定") {}
        } message: {
            Text("配置已保存，请点击「测试连接」验证")
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - 保存配置

    private func saveConfig() {
        connectionVM.serverConfig = ServerConfig(
            hostname: hostname,
            port: Int(port) ?? 4096,
            useHTTPS: useHTTPS,
            username: username
        )
        connectionVM.password = password
        showSaveAlert = true
    }
}
