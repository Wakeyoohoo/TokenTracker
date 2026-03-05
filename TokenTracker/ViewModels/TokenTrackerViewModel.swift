import Foundation
import SwiftUI
import Combine
import ServiceManagement

/// Main view model that manages all providers and usage data
@MainActor
final class TokenTrackerViewModel: ObservableObject {
    @Published var providers: [ProviderConfig] = []
    @Published var usageData: [String: UsageData] = [:]  // keyed by provider id
    @Published var isRefreshing = false
    @Published var lastRefreshTime: Date?
    @Published var showSettings = false
    @Published var showAddProvider = false
    
    /// Polling interval in seconds
    @AppStorage("pollingInterval") var pollingInterval: TimeInterval = 300  // 5 minutes
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    
    private var pollingTimer: Timer?
    private let registry = ProviderRegistry.shared
    private let configManager = ConfigFileManager.shared
    
    // MARK: - Computed
    
    var enabledProviders: [ProviderConfig] {
        providers.filter { $0.isEnabled }
    }
    
    var totalCost: Double {
        enabledProviders.compactMap { usageData[$0.id]?.cost }.reduce(0, +)
    }
    
    var totalTokens: Int64 {
        enabledProviders.compactMap { usageData[$0.id]?.totalTokens }.reduce(0, +)
    }
    
    var menuBarTitle: String {
        if enabledProviders.isEmpty {
            return "TT"
        }

        struct MenuBlock {
            let providerTop: String
            let providerBottom: String
            let topDetail: String
            let bottomDetail: String
            let providerWidth: Int
            let detailWidth: Int
        }

        let allBlocks: [MenuBlock] = enabledProviders.compactMap { config in
            guard let usage = usageData[config.id] else { return nil }

            let providerRows = menuBarProviderRows(for: menuBarProviderCode(for: config))
            let primaryValue = menuBarPrimaryValue(for: usage)
            let percentageValue = menuBarPercentage(for: usage)
            let topDetail = primaryValue.isEmpty ? "--" : primaryValue
            let bottomDetail = percentageValue.isEmpty ? "--" : percentageValue
            return MenuBlock(
                providerTop: providerRows.top,
                providerBottom: providerRows.bottom,
                topDetail: topDetail,
                bottomDetail: bottomDetail,
                providerWidth: max(providerRows.top.count, providerRows.bottom.count),
                detailWidth: max(topDetail.count, bottomDetail.count)
            )
        }

        let maxVisibleBlocks = 2
        var blocks = Array(allBlocks.prefix(maxVisibleBlocks))
        if allBlocks.count > maxVisibleBlocks, let last = blocks.last {
            let hiddenCount = allBlocks.count - maxVisibleBlocks
            let topDetail = last.topDetail + " +\(hiddenCount)"
            blocks[blocks.count - 1] = MenuBlock(
                providerTop: last.providerTop,
                providerBottom: last.providerBottom,
                topDetail: topDetail,
                bottomDetail: last.bottomDetail,
                providerWidth: last.providerWidth,
                detailWidth: max(topDetail.count, last.bottomDetail.count)
            )
        }

        guard !blocks.isEmpty else { return "TT" }
        let blockSeparator = "  "
        let columnSeparator = " "
        let line1 = blocks.map { block in
            pad(block.providerTop, to: block.providerWidth)
                + columnSeparator
                + pad(block.topDetail, to: block.detailWidth)
        }.joined(separator: blockSeparator)
        let line2 = blocks.map { block in
            pad(block.providerBottom, to: block.providerWidth)
                + columnSeparator
                + pad(block.bottomDetail, to: block.detailWidth)
        }.joined(separator: blockSeparator)

        return line1 + "\n" + line2
    }

    private func menuBarProviderCode(for config: ProviderConfig) -> String {
        let normalized = config.displayName.filter { $0.isLetter || $0.isNumber }
        if normalized.isEmpty { return "??" }
        return String(normalized.prefix(2)).uppercased()
    }

    private func menuBarProviderRows(for code: String) -> (top: String, bottom: String) {
        let chars = Array(code)
        guard !chars.isEmpty else { return ("?", "?") }
        if chars.count == 1 {
            let text = String(chars[0])
            return (text, text)
        }
        return (String(chars[0]), String(chars[1]))
    }

    private func menuBarPrimaryValue(for usage: UsageData) -> String {
        if let remaining = usage.remainingBalance {
            return menuBarCompactValue(remaining, currency: usage.currency)
        }
        if let total = usage.totalQuota {
            return menuBarCompactValue(total, currency: usage.currency)
        }
        if usage.cost > 0 {
            return menuBarCompactValue(usage.cost, currency: usage.currency)
        }
        if usage.totalTokens > 0 {
            return usage.totalTokens.formattedTokens.lowercased()
        }
        return ""
    }

    private func menuBarPercentage(for usage: UsageData) -> String {
        guard let pct = usage.usagePercentage else { return "" }
        return "\(Int((pct * 100).rounded()))%"
    }

    private func menuBarCompactValue(_ value: Double, currency: String) -> String {
        let trimmedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCurrency = !trimmedCurrency.isEmpty
            && trimmedCurrency != "Tokens"
            && !trimmedCurrency.contains("单位")
            && !trimmedCurrency.contains("额度")

        if isCurrency {
            let symbol: String
            switch trimmedCurrency.uppercased() {
            case "USD": symbol = "$"
            case "CNY", "RMB": symbol = "¥"
            case "EUR": symbol = "€"
            case "GBP": symbol = "£"
            default: symbol = ""
            }
            return symbol + compactDecimal(value)
        }

        return Double(max(value, 0)).formattedQuotaValue.lowercased()
    }

    private func compactDecimal(_ value: Double) -> String {
        if value >= 100 {
            return "\(Int(value.rounded()))"
        }

        let text = String(format: "%.1f", value)
        if text.hasSuffix(".0") {
            return String(text.dropLast(2))
        }
        return text
    }

    private func pad(_ text: String, to width: Int) -> String {
        guard text.count < width else { return text }
        return text + String(repeating: " ", count: width - text.count)
    }

    static let shared = TokenTrackerViewModel()
    
    private init() {
        loadProviders()
        syncLaunchAtLoginStatus()
    }
    
    // MARK: - Provider Management
    
    func loadProviders() {
        // Start with built-in providers
        var allConfigs = ProviderRegistry.builtInConfigs
        
        // Load saved state (enabled/disabled, API keys)
        for i in 0..<allConfigs.count {
            let id = allConfigs[i].id
            allConfigs[i].isEnabled = UserDefaults.standard.bool(forKey: "provider_\(id)_enabled")
            allConfigs[i].apiKey = APIKeyStore.shared.read(for: id) ?? ""
        }
        
        // Load custom providers from config files
        let customProviders = configManager.loadCustomProviders()
        for var custom in customProviders {
            custom.apiKey = APIKeyStore.shared.read(for: custom.id) ?? ""
            custom.isEnabled = UserDefaults.standard.bool(forKey: "provider_\(custom.id)_enabled")
            allConfigs.append(custom)
        }
        
        providers = allConfigs
    }
    
    func saveProvider(_ config: ProviderConfig) {
        // Save API key to local defaults storage
        if !config.apiKey.isEmpty {
            APIKeyStore.shared.save(config.apiKey, for: config.id)
        } else {
            APIKeyStore.shared.delete(for: config.id)
        }
        
        // Save enabled state
        UserDefaults.standard.set(config.isEnabled, forKey: "provider_\(config.id)_enabled")
        
        // Update in-memory list
        if let index = providers.firstIndex(where: { $0.id == config.id }) {
            providers[index] = config
        }
    }
    
    func addCustomProvider(_ config: ProviderConfig) {
        do {
            try configManager.saveCustomProvider(config)
            var saved = config
            saved.isBuiltIn = false
            providers.append(saved)
            saveProvider(saved)
        } catch {
            print("Failed to save custom provider: \(error)")
        }
    }
    
    func deleteProvider(_ config: ProviderConfig) {
        guard !config.isBuiltIn else { return }
        configManager.deleteCustomProvider(id: config.id)
        APIKeyStore.shared.delete(for: config.id)
        UserDefaults.standard.removeObject(forKey: "provider_\(config.id)_enabled")
        providers.removeAll { $0.id == config.id }
        usageData.removeValue(forKey: config.id)
    }
    
    func toggleProvider(_ config: ProviderConfig) {
        guard let index = providers.firstIndex(where: { $0.id == config.id }) else { return }
        providers[index].isEnabled.toggle()
        UserDefaults.standard.set(providers[index].isEnabled, forKey: "provider_\(config.id)_enabled")
        
        if providers[index].isEnabled {
            Task { await fetchUsage(for: providers[index]) }
        }
    }

    func setAllProvidersEnabled(_ enabled: Bool) {
        var didChange = false
        for index in providers.indices {
            if providers[index].isEnabled != enabled {
                providers[index].isEnabled = enabled
                UserDefaults.standard.set(enabled, forKey: "provider_\(providers[index].id)_enabled")
                didChange = true
            }
        }

        if enabled && didChange {
            Task { await refreshAll() }
        }
    }
    
    // MARK: - Data Fetching
    
    func refreshAll() async {
        isRefreshing = true
        
        await withTaskGroup(of: Void.self) { group in
            for provider in enabledProviders {
                group.addTask { [weak self] in
                    await self?.fetchUsage(for: provider)
                }
            }
        }
        
        lastRefreshTime = Date()
        isRefreshing = false
    }
    
    func fetchUsage(for config: ProviderConfig) async {
        do {
            let data = try await registry.fetchUsage(for: config)
            usageData[config.id] = data
        } catch {
            usageData[config.id] = UsageData.error(
                providerId: config.id,
                providerName: config.displayName,
                message: error.localizedDescription
            )
        }
    }
    
    // MARK: - Polling
    
    func startPolling() {
        stopPolling()
        
        // Initial fetch
        Task { await refreshAll() }
        
        // Set up timer
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAll()
            }
        }
    }
    
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    func updatePollingInterval(_ interval: TimeInterval) {
        pollingInterval = interval
        if pollingTimer != nil {
            startPolling()  // Restart with new interval
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            // Revert to actual system state on failure.
            launchAtLogin = SMAppService.mainApp.status == .enabled
            print("Failed to update launch at login: \(error)")
        }
    }

    func syncLaunchAtLoginStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
    
    /// Available polling intervals
    static let pollingIntervals: [(String, TimeInterval)] = [
        ("1 分钟", 60),
        ("5 分钟", 300),
        ("15 分钟", 900),
        ("30 分钟", 1800),
        ("1 小时", 3600),
    ]
}
