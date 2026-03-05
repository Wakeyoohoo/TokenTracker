import SwiftUI
import AppKit

/// Settings window with Providers list + General tab
struct SettingsView: View {
    @ObservedObject var viewModel: TokenTrackerViewModel
    @State private var selectedTab = 0
    @State private var selectedProviderId: String?
    @State private var providerSearch = ""
    @State private var showEnabledOnly = false
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
                .frame(minWidth: 200, maxWidth: 320)

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

                GroupBox("连接配置") {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            SecureField("输入 API Key", text: $viewModel.providers[index].apiKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: viewModel.providers[index].apiKey) { _, _ in
                                    viewModel.saveProvider(viewModel.providers[index])
                                }
                        }

                        HStack {
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
                                Label(error, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundColor(.orange)
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
