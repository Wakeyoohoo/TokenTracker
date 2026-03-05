import Foundation

/// Anthropic provider - manual entry mode since no public usage API
struct AnthropicProvider: UsageProvider {
    static var providerType: ProviderType { .anthropic }
    
    func fetchUsage(config: ProviderConfig) async throws -> UsageData {
        // Anthropic doesn't have a public usage API
        // Return stored manual data or empty
        return UsageData(
            providerId: config.id,
            providerName: config.displayName,
            inputTokens: 0,
            outputTokens: 0,
            cost: 0,
            currency: "USD",
            totalQuota: nil,
            usedAmount: nil,
            remainingBalance: nil,
            modelBreakdown: [],
            fetchedAt: Date(),
            errorMessage: "手动输入模式 — 暂无公开用量 API"
        )
    }
}
