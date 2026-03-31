import Foundation

/// Claude.ai Web Provider - uses session cookies to fetch subscription status
struct ClaudeWebProvider: UsageProvider {
    static var providerType: ProviderType { .claudeWeb }

    func fetchUsage(config: ProviderConfig) async throws -> UsageData {
        guard !config.apiKey.isEmpty else {
            throw ProviderError.invalidAPIKey
        }

        // The "API Key" for ClaudeWeb is actually the session_key cookie
        let sessionKey = config.apiKey

        // 1. Fetch organizations using ClaudeWebScanner (bypasses Cloudflare)
        let orgs = try await fetchOrganizations(sessionKey: sessionKey)
        guard let firstOrg = orgs.first else {
            throw ProviderError.parseError("No organizations found for this session")
        }

        let orgId = firstOrg["uuid"] as? String ?? ""
        let orgName = firstOrg["name"] as? String ?? "Claude.ai"

        // 2. Try to fetch subscription/usage info
        var totalQuota: Double? = nil
        var usedAmount: Double? = nil
        var remainingMsg: String?
        var refreshExpiryTimestamp: TimeInterval? = nil
        var weeklyRefreshExpiryTimestamp: TimeInterval? = nil

        if let sub = firstOrg["active_subscription"] as? [String: Any],
           let plan = sub["plan"] as? String {
            remainingMsg = "Plan: \(plan.capitalized)"
        }

        // Attempt to fetch usage stats using ClaudeWebScanner (bypasses Cloudflare)
        let stats = try? await fetchUsageStatsWithScanner(orgId: orgId, sessionKey: sessionKey)

        func parseTimestamp(_ string: String) -> TimeInterval? {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]

            if let date = formatter.date(from: string) {
                return date.timeIntervalSince1970
            }

            // Strip the timezone and parse, then add offset manually
            var cleanString = string
            var offsetSeconds: TimeInterval = 0

            if string.hasSuffix("+00:00") {
                cleanString = String(string.dropLast(6))
                offsetSeconds = 0
            } else if string.hasSuffix("Z") {
                cleanString = String(string.dropLast(1))
                offsetSeconds = 0
            } else if let range = string.range(of: "+", options: .backwards) {
                let tzPart = String(string[range.upperBound...]).replacingOccurrences(of: ":", with: "")
                if let tzMinutes = Int(tzPart) {
                    offsetSeconds = TimeInterval(tzMinutes) * 60
                }
                cleanString = String(string[..<range.lowerBound])
            }

            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: cleanString) {
                return date.timeIntervalSince1970 + offsetSeconds
            }

            return nil
        }

        if let stats = stats,
           let fiveHour = stats["five_hour"] as? [String: Any],
           let resetsAtStr = fiveHour["resets_at"] as? String {
            refreshExpiryTimestamp = parseTimestamp(resetsAtStr)
            if let utilization = fiveHour["utilization"] as? Double {
                usedAmount = utilization
            } else if let utilization = fiveHour["utilization"] as? Int {
                usedAmount = Double(utilization)
            }
            totalQuota = 100
        }

        // Parse weekly reset time from seven_day
        if let stats = stats,
           let sevenDay = stats["seven_day"] as? [String: Any],
           let weeklyResetsAtStr = sevenDay["resets_at"] as? String {
            weeklyRefreshExpiryTimestamp = parseTimestamp(weeklyResetsAtStr)
        }

        return UsageData(
            providerId: config.id,
            providerName: config.displayName,
            inputTokens: 0,
            outputTokens: 0,
            cost: 0,
            currency: "Messages",
            totalQuota: totalQuota,
            usedAmount: usedAmount,
            remainingBalance: nil,
            refreshExpiryTimestamp: refreshExpiryTimestamp,
            weeklyRefreshExpiryTimestamp: weeklyRefreshExpiryTimestamp,
            modelBreakdown: [],
            fetchedAt: Date(),
            errorMessage: remainingMsg,
            rawResponse: "Organization: \(orgName)\nID: \(orgId)"
        )
    }

    @MainActor
    private func fetchOrganizations(sessionKey: String) async throws -> [[String: Any]] {
        let url = URL(string: "https://claude.ai/api/organizations")!
        let data = try await ClaudeWebScanner.shared.fetch(url: url, sessionKey: sessionKey)

        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorObj = dict["error"] as? [String: Any] {
            let message = errorObj["message"] as? String ?? "未知错误"
            throw ProviderError.parseError("Claude API 错误: \(message)")
        }

        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            let content = String(data: data, encoding: .utf8) ?? "Non-UTF8"
            throw ProviderError.parseError("解析 Org 列表失败。内容预览: \(content.prefix(150))")
        }

        // CodexBar uses 'uuid', normalize to 'id'
        if let uuid = json["uuid"] as? String {
            return [["uuid": uuid, "id": uuid, "name": json["name"] ?? "Claude.ai", "active_subscription": json["active_subscription"] ?? [:]]]
        }
        return [json]
    }

    @MainActor
    private func fetchUsageStatsWithScanner(orgId: String, sessionKey: String) async throws -> [String: Any]? {
        let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage")!
        let data = try await ClaudeWebScanner.shared.fetch(url: url, sessionKey: sessionKey)
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
