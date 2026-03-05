import Foundation

/// Unified usage data model returned by all providers
struct UsageData: Codable, Identifiable {
    var id: String { providerId }
    
    let providerId: String
    let providerName: String
    
    /// Token counts
    var inputTokens: Int64
    var outputTokens: Int64
    var totalTokens: Int64 { inputTokens + outputTokens }
    
    /// Cost in the provider's currency
    var cost: Double
    var currency: String  // "USD", "CNY", etc.
    
    /// Quota / balance info
    var totalQuota: Double?       // Total balance/quota amount
    var usedAmount: Double?       // Amount used
    var remainingBalance: Double? // Remaining balance
    var refreshExpiryTimestamp: TimeInterval? = nil  // Expiry unix timestamp (seconds)
    
    /// Computed usage percentage (0.0 ~ 1.0)
    var usagePercentage: Double? {
        guard let total = totalQuota, total > 0 else { return nil }
        if let used = usedAmount {
            return min(used / total, 1.0)
        }
        if let remaining = remainingBalance {
            return min(1.0 - (remaining / total), 1.0)
        }
        return nil
    }
    
    /// Per-model breakdown
    var modelBreakdown: [ModelUsage]
    
    /// When this data was fetched
    var fetchedAt: Date
    
    /// Error message if fetch failed
    var errorMessage: String?
    
    /// Raw unparsed JSON string response for debugging in the Settings UI
    var rawResponse: String?
    
    static func empty(providerId: String, providerName: String) -> UsageData {
        UsageData(
            providerId: providerId,
            providerName: providerName,
            inputTokens: 0,
            outputTokens: 0,
            cost: 0,
            currency: "USD",
            totalQuota: nil,
            usedAmount: nil,
            remainingBalance: nil,
            refreshExpiryTimestamp: nil,
            modelBreakdown: [],
            fetchedAt: Date(),
            errorMessage: nil,
            rawResponse: nil
        )
    }
    
    static func error(providerId: String, providerName: String, message: String) -> UsageData {
        var data = empty(providerId: providerId, providerName: providerName)
        data.errorMessage = message
        return data
    }
}

struct ModelUsage: Codable, Identifiable {
    var id: String { modelName }
    
    let modelName: String
    var inputTokens: Int64
    var outputTokens: Int64
    var totalTokens: Int64 { inputTokens + outputTokens }
    var cost: Double
    var totalQuota: Double? // For model-specific quotas, like MiniMax
    var remainingQuota: Double? // Remaining quota for providers that expose model-level remains
    var refreshExpiryTimestamp: TimeInterval? = nil // Model-level expiry unix timestamp (seconds)
}
