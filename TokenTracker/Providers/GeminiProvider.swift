import Foundation

/// Google Gemini provider - manual entry mode since no simple public usage API
struct GeminiProvider: UsageProvider {
    static var providerType: ProviderType { .gemini }
    
    func fetchUsage(config: ProviderConfig) async throws -> UsageData {
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
            errorMessage: "手动输入模式 — 需通过 Google Cloud Console 查看"
        )
    }
}
