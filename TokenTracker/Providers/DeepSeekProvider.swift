import Foundation

/// DeepSeek usage provider - uses balance API
struct DeepSeekProvider: UsageProvider {
    static var providerType: ProviderType { .deepSeek }
    
    func fetchUsage(config: ProviderConfig) async throws -> UsageData {
        guard !config.apiKey.isEmpty else {
            throw ProviderError.invalidAPIKey
        }
        
        let url = URL(string: "https://api.deepseek.com/user/balance")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ProviderError.httpError(httpResponse.statusCode, body)
        }
        
        let rawString = String(data: data, encoding: .utf8) ?? ""
        return try parseBalanceResponse(data: data, rawString: rawString, config: config)
    }
    
    private func parseBalanceResponse(data: Data, rawString: String, config: ProviderConfig) throws -> UsageData {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let balanceInfos = json["balance_infos"] as? [[String: Any]],
              let balanceInfo = balanceInfos.first else {
            throw ProviderError.parseError("Invalid balance response")
        }
        
        let totalBalance = Double(balanceInfo["total_balance"] as? String ?? "0") ?? 0
        let grantedBalance = Double(balanceInfo["granted_balance"] as? String ?? "0") ?? 0
        let toppedUpBalance = Double(balanceInfo["topped_up_balance"] as? String ?? "0") ?? 0
        let currency = balanceInfo["currency"] as? String ?? "CNY"
        
        let totalQuota = totalBalance + grantedBalance
        let remaining = totalBalance
        let used = totalQuota > 0 ? totalQuota - remaining : 0
        
        return UsageData(
            providerId: config.id,
            providerName: config.displayName,
            inputTokens: 0,
            outputTokens: 0,
            cost: used,
            currency: currency,
            totalQuota: totalQuota,
            usedAmount: used,
            remainingBalance: remaining,
            modelBreakdown: [],
            fetchedAt: Date(),
            errorMessage: nil,
            rawResponse: rawString
        )
    }
}
