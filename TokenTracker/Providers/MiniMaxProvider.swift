import Foundation

/// MiniMax usage provider - queries balance/remaining
struct MiniMaxProvider: UsageProvider {
    static var providerType: ProviderType { .miniMax }
    
    func fetchUsage(config: ProviderConfig) async throws -> UsageData {
        guard !config.apiKey.isEmpty else {
            throw ProviderError.invalidAPIKey
        }
        
        // Try the coding plan endpoint first
        let url = URL(string: "https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains")!
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
        return try parseResponse(data: data, rawString: rawString, config: config)
    }
    
    private func parseResponse(data: Data, rawString: String, config: ProviderConfig) throws -> UsageData {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.parseError("Invalid JSON")
        }

        var breakdowns: [ModelUsage] = []
        var totalBalance: Double = 0
        var totalRemaining: Double = 0
        var refreshExpiryTimestamp: TimeInterval? = nil
        var weeklyRefreshExpiryTimestamp: TimeInterval? = nil

        // Handle the model_remains array structure
        if let modelRemains = json["model_remains"] as? [[String: Any]] {
            var modelRefreshTimestamps: [TimeInterval] = []
            var hasAssignedTotal = false
            let nowTimestamp = Date().timeIntervalSince1970

            for model in modelRemains {
                let modelName = model["model_name"] as? String ?? "Unknown"

                // current_interval_total_count = 配额总量
                // current_interval_usage_count = 剩余配额（不是已用！）
                let total = model["current_interval_total_count"] as? Double ?? Double(model["current_interval_total_count"] as? Int ?? 0)
                let remaining = model["current_interval_usage_count"] as? Double ?? Double(model["current_interval_usage_count"] as? Int ?? 0)
                let used = total - remaining

                // Parse reset timestamp from end_time (milliseconds)
                if let endTime = model["end_time"] as? Double {
                    modelRefreshTimestamps.append(endTime / 1000)
                }

                // Parse weekly reset time: weekly_remains_time is a duration in milliseconds
                var weeklyResetTimestamp: TimeInterval? = nil
                if let weeklyRemainsMs = model["weekly_remains_time"] as? Double {
                    weeklyResetTimestamp = nowTimestamp + (weeklyRemainsMs / 1000)
                    // Take the first one's weekly reset timestamp
                    if weeklyRefreshExpiryTimestamp == nil {
                        weeklyRefreshExpiryTimestamp = weeklyResetTimestamp
                    }
                }

                // Totals: all models share the same quota pool, only take the first one's values
                if !hasAssignedTotal && total > 0 {
                    totalBalance = total
                    totalRemaining = remaining
                    hasAssignedTotal = true
                }

                breakdowns.append(ModelUsage(
                    modelName: modelName,
                    inputTokens: 0,
                    outputTokens: 0,
                    cost: used,
                    totalQuota: total,
                    remainingQuota: remaining,
                    refreshExpiryTimestamp: (model["end_time"] as? Double).map { $0 / 1000 },
                    weeklyRefreshExpiryTimestamp: weeklyResetTimestamp
                ))
            }

            // Use the nearest reset time
            if let nearestReset = modelRefreshTimestamps.min(), nearestReset > Date().timeIntervalSince1970 {
                refreshExpiryTimestamp = nearestReset
            }
        } else {
            // Fallback for their other possible API structures
            totalBalance = extractDouble(from: json, keyPath: "data.total_balance")
                ?? extractDouble(from: json, keyPath: "total_balance")
                ?? 0

            let remaining = extractDouble(from: json, keyPath: "data.available_balance")
                ?? extractDouble(from: json, keyPath: "available_balance")
                ?? extractDouble(from: json, keyPath: "data.remaining")
                ?? totalBalance

            totalRemaining = remaining
        }

        let totalUsed = totalBalance - totalRemaining

        return UsageData(
            providerId: config.id,
            providerName: config.displayName,
            inputTokens: 0,
            outputTokens: 0,
            cost: totalUsed,
            currency: "单位",
            totalQuota: totalBalance > 0 ? totalBalance : nil,
            usedAmount: totalUsed > 0 ? totalUsed : nil,
            remainingBalance: totalRemaining > 0 ? totalRemaining : nil,
            refreshExpiryTimestamp: refreshExpiryTimestamp,
            weeklyRefreshExpiryTimestamp: weeklyRefreshExpiryTimestamp,
            modelBreakdown: breakdowns.sorted { $0.cost > $1.cost },
            fetchedAt: Date(),
            errorMessage: nil,
            rawResponse: rawString
        )
    }
    
    /// Extract a Double from nested JSON using dot-separated key path
    private func extractDouble(from json: [String: Any], keyPath: String) -> Double? {
        let keys = keyPath.split(separator: ".").map(String.init)
        var current: Any = json
        
        for key in keys {
            if let dict = current as? [String: Any] {
                guard let next = dict[key] else { return nil }
                current = next
            } else {
                return nil
            }
        }
        
        if let d = current as? Double { return d }
        if let i = current as? Int { return Double(i) }
        if let s = current as? String { return Double(s) }
        return nil
    }

    private func extractDurationSeconds(_ value: Any?) -> TimeInterval? {
        guard let value else { return nil }

        let raw: Double
        if let doubleValue = value as? Double {
            raw = doubleValue
        } else if let intValue = value as? Int {
            raw = Double(intValue)
        } else if let stringValue = value as? String, let doubleValue = Double(stringValue) {
            raw = doubleValue
        } else {
            return nil
        }

        guard raw > 0 else { return nil }

        // MiniMax remains_time is a duration. Some responses may use ms; normalize to seconds.
        var seconds = raw
        let expectedMaxSeconds: TimeInterval = 5 * 3600
        if seconds > expectedMaxSeconds {
            seconds /= 1000
        }
        if seconds > expectedMaxSeconds {
            seconds /= 1000
        }

        guard seconds > 0 else { return nil }
        return seconds
    }

    private func makeExpiryTimestamp(fromRemains value: Any?, now: TimeInterval) -> TimeInterval? {
        guard let remainsSeconds = extractDurationSeconds(value) else { return nil }
        return now + remainsSeconds
    }
}
