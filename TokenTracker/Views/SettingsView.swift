import SwiftUI
import AppKit

/// Settings window with Providers list + General tab
struct SettingsView: View {
    @ObservedObject var viewModel: TokenTrackerViewModel
    @State private var selectedTab = 0
    @State private var selectedProviderId: String?
    @State private var providerSearch = ""
    @State private var showEnabledOnly = false
    @State private var showClaudeLogin = false
    @Environment(\.dismiss) private var dismiss

    private var filteredProviders: [ProviderConfig] {
        let keyword = providerSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return viewModel.providers.filter { config in
            let matchesSearch = keyword.isEmpty
                || config.displayName.localizedCaseInsensitiveContains(keyword)
                || config.id.localizedCaseInsensitiveContains(keyword)
            let matchesEnabled = !showEnabledOnly || config.isEnabled
            return matchesSearch && matchesEnabled
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Providers").tag(0)
                Text("General").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            if selectedTab == 0 {
                providersTab
            } else {
                generalTab
            }
        }
        .frame(minWidth: 720, minHeight: 560, alignment: .topLeading)
        .sheet(isPresented: $viewModel.showAddProvider) {
            AddProviderView(viewModel: viewModel)
        }
        .sheet(isPresented: $showClaudeLogin) {
            if let selectedId = selectedProviderId,
               let index = viewModel.providers.firstIndex(where: { $0.id == selectedId }) {
                ClaudeLoginView(sessionKey: $viewModel.providers[index].apiKey, onFinished: {
                    viewModel.saveProvider(viewModel.providers[index])
                })
            }
        }
    }
    
    // MARK: - Providers Tab
    
    private var providersTab: some View {
        VStack(spacing: 0) {
            providerToolbar
            Divider()

            HSplitView {
                // Sidebar: provider list
                VStack(spacing: 0) {
                    List(selection: $selectedProviderId) {
                        ForEach(filteredProviders) { config in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(config.brandColor)
                                    .frame(width: 8, height: 8)
                                Text(config.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer(minLength: 8)
                                Toggle("", isOn: Binding(
                                    get: { config.isEnabled },
                                    set: { newValue in
                                        guard let latest = viewModel.providers.first(where: { $0.id == config.id }) else { return }
                                        if latest.isEnabled != newValue {
                                            viewModel.toggleProvider(latest)
                                        }
                                        if newValue {
                                            selectedTab = 0
                                            selectedProviderId = config.id
                                        }
                                    }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                            }
                            .padding(.vertical, 2)
                            .tag(config.id)
                        }
                    }
                    .listStyle(.sidebar)

                    Divider()

                    HStack {
                        Button(action: {
                            viewModel.showAddProvider = true
                        }) {
                            Label("添加自定义", systemImage: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if let selectedId = selectedProviderId,
                           let config = viewModel.providers.first(where: { $0.id == selectedId }),
                           !config.isBuiltIn {
                            Button(action: {
                                viewModel.deleteProvider(config)
                                selectedProviderId = nil
                            }) {
                                Label("删除", systemImage: "minus")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)

                // Detail panel
                if let selectedId = selectedProviderId,
                   let configIndex = viewModel.providers.firstIndex(where: { $0.id == selectedId }) {
                    providerDetail(index: configIndex)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("选择一个平台进行配置")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    private var providerToolbar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("搜索平台", text: $providerSearch)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                Toggle("仅启用", isOn: $showEnabledOnly)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.caption)
            }

            HStack {
                Text("已启用 \(viewModel.enabledProviders.count)/\(viewModel.providers.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("全开") {
                    viewModel.setAllProvidersEnabled(true)
                }
                .font(.caption)
                Button("全关") {
                    viewModel.setAllProvidersEnabled(false)
                }
                .font(.caption)
                Button("刷新") {
                    Task { await viewModel.refreshAll() }
                }
                .font(.caption)
                .disabled(viewModel.isRefreshing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func providerDetail(index: Int) -> some View {
        let config = viewModel.providers[index]

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Provider name & icon
                HStack {
                    Image(systemName: config.iconName)
                        .font(.title2)
                        .foregroundColor(config.brandColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(config.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(config.id)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(config.isEnabled ? "已启用" : "已停用")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((config.isEnabled ? Color.green : Color.gray).opacity(0.15))
                        .foregroundColor(config.isEnabled ? .green : .secondary)
                        .cornerRadius(10)
                }

                // Status bar toggle
                HStack {
                    Toggle("在状态栏展示", isOn: Binding(
                        get: { config.showInStatusBar },
                        set: { _ in
                            viewModel.toggleShowInStatusBar(config)
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    Spacer()
                }
                .padding(.horizontal, 4)

                GroupBox("连接配置") {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(config.providerType == .claudeWeb ? "Session Key (Cookie)" : "API Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            SecureField(config.providerType == .claudeWeb ? "输入 session_key (来自 Cookie)" : "输入 API Key", text: $viewModel.providers[index].apiKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: viewModel.providers[index].apiKey) { _, _ in
                                    viewModel.saveProvider(viewModel.providers[index])
                                }
                            
                            if config.providerType == .claudeWeb {
                                Text("此项非 API Key，请登录 claude.ai 从浏览器 Cookie 中获取 session_key 的值。")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                            }
                        }

                        HStack {
                            if config.providerType == .claudeWeb {
                                Button(action: {
                                    showClaudeLogin = true
                                }) {
                                    Label("登录并自动获取", systemImage: "safari")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .padding(.top, 4)
                            }

                            Button("测试连接 API") {
                                Task { await viewModel.fetchUsage(for: viewModel.providers[index]) }
                            }
                            .disabled(viewModel.providers[index].apiKey.isEmpty)

                            Button("刷新该平台") {
                                Task { await viewModel.fetchUsage(for: viewModel.providers[index]) }
                            }
                            .disabled(viewModel.isRefreshing || viewModel.providers[index].apiKey.isEmpty)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }

                // Provider type info
                if !config.providerType.supportsAutoFetch {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.orange)
                        Text("该平台暂无公开用量 API，目前为手动模式")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                // Custom endpoint info
                if let endpoint = config.endpointConfig {
                    GroupBox("API 端点") {
                        Text("\(endpoint.method) \(endpoint.baseURL)\(endpoint.path)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }

                GroupBox("连接状态") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let usage = viewModel.usageData[config.id] {
                            if let error = usage.errorMessage {
                                HStack {
                                    Label(error, systemImage: "exclamationmark.triangle")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .textSelection(.enabled)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(error, forType: .string)
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.plain)
                                    .help("复制错误信息")
                                }
                            } else {
                                Label("已连接 ✓", systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            Text("最近拉取: \(usage.fetchedAt.shortTimeString)")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            if let rawResponse = usage.rawResponse {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Latest Response")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)

                                    ScrollView {
                                        Text(rawResponse)
                                            .font(.system(.caption2, design: .monospaced))
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .textSelection(.enabled)
                                    }
                                    .frame(maxHeight: 120)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            }
                        } else {
                            Text("尚未拉取数据")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - General Tab
    
    private var generalTab: some View {
        Form {
            Section("自动刷新") {
                Picker("轮询间隔", selection: $viewModel.pollingInterval) {
                    ForEach(TokenTrackerViewModel.pollingIntervals, id: \.1) { name, interval in
                        Text(name).tag(interval)
                    }
                }
                .onChange(of: viewModel.pollingInterval) { _, newValue in
                    viewModel.updatePollingInterval(newValue)
                }
            }
            
            Section("数据") {
                HStack {
                    Button("立即刷新一次") {
                        Task { await viewModel.refreshAll() }
                    }
                    .disabled(viewModel.isRefreshing)

                    if viewModel.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.6)
                    }

                    Spacer()

                    if let time = viewModel.lastRefreshTime {
                        Text("上次刷新 \(time.shortTimeString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("尚未刷新")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("系统") {
                Toggle("开机自动启动", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { newValue in
                        viewModel.setLaunchAtLogin(newValue)
                    }
                ))

                Toggle("显示状态栏图标", isOn: $viewModel.showStatusBar)
            }
            
            Section("自定义 Provider 配置目录") {
                HStack {
                    Text(ConfigFileManager.shared.configDirectoryPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    
                    Button("打开") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: ConfigFileManager.shared.configDirectoryPath))
                    }
                    .font(.caption)

                    Button("复制") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(
                            ConfigFileManager.shared.configDirectoryPath,
                            forType: .string
                        )
                    }
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Claude Login Components

import WebKit

struct ClaudeLoginView: View {
    @Binding var sessionKey: String
    var onFinished: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange.gradient)
                
                Text("配置 Claude Pro 会话")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("安全地从浏览器中提取 Session Key 以同步用量")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            Divider()
                .padding(.horizontal, 40)
            
            // Steps
            VStack(alignment: .leading, spacing: 28) {
                StepRow(number: "1", title: "点击进入官网", description: "在浏览器登录 claude.ai 并停留在主页。") {
                    if let url = URL(string: "https://claude.ai") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                StepRow(number: "2", title: "提取数据", description: "按 F12 -> Application -> Cookies -> https://claude.ai，找到并双击复制 'session_key'。")
            }
            .padding(40)
            
            Spacer()
            
            // Input Area
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "keyboard")
                        .foregroundColor(.orange)
                    
                    SecureField("在此粘贴 sk-ant-sid01-...", text: $sessionKey)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
                        )
                }
                .padding(.horizontal, 40)
                
                HStack(spacing: 20) {
                    Button("取消") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    
                    Button("保存并关闭") {
                        onFinished()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(sessionKey.isEmpty)
                    .frame(width: 120)
                }
            }
            .padding(.bottom, 40)
        }
        .frame(width: 520, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

private struct StepRow: View {
    let number: String
    let title: String
    let description: String
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.orange.gradient))
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.headline)
                    
                    if let action = action {
                        Button(action: action) {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
    }
}
