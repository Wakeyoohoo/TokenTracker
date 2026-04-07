import Foundation

/// Google Gemini provider - supports manual entry, custom usage endpoint, or official dashboard link
struct GeminiProvider: UsageProvider {
    static var providerType: ProviderType { .gemini }
    
    func fetchUsage(config: ProviderConfig) async throws -> UsageData {
        // 1. If there's an endpoint config (e.g. One API proxy), try to fetch from it
        if config.endpointConfig != nil {
            do {
                return try await CustomProvider().fetchUsage(config: config)
            } catch {
                // Fallback to manual if proxy fails
            }
        }
        
        // 2. Official Gemini (AI Studio) Mode:
        // Since Google doesn't provide a Billing API for standard API Keys,
        // we return a special state that UI can interpret to show a "View Dashboard" button.
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
            errorMessage: nil,
            rawResponse: "Gemini 官方计费托管在 Google Cloud 中，暂无 API 查询权限。\n\n项目 ID: 请在 Google AI Studio 确认\n消耗估算: 1.5 Flash 免费层级无限次，付费层级按量计费。"
        )
    }
}
