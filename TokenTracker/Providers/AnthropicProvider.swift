import Foundation
import WebKit

/// Anthropic provider - uses the Admin API to fetch organization usage
struct AnthropicProvider: UsageProvider {
    static var providerType: ProviderType { .anthropic }
    
    func fetchUsage(config: ProviderConfig) async throws -> UsageData {
        guard !config.apiKey.isEmpty else {
            throw ProviderError.invalidAPIKey
        }
        
        // Anthropic Usage API requires an admin API key starting with "sk-ant-admin"
        guard config.apiKey.hasPrefix("sk-ant-admin") else {
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
                errorMessage: "⚠️ 官方查询接口仅支持管理员 API Key (以 sk-ant-admin 开头)"
            )
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startString = dateFormatter.string(from: Date.daysAgo(30))
        let endString = dateFormatter.string(from: Date())
        
        var components = URLComponents(string: "https://api.anthropic.com/v1/organizations/usage_report/messages")!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: startString),
            URLQueryItem(name: "end_date", value: endString),
            URLQueryItem(name: "group_by", value: "model")
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
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
        return try parseUsageResponse(data: data, rawString: rawString, config: config)
    }
    
    private func parseUsageResponse(data: Data, rawString: String, config: ProviderConfig) throws -> UsageData {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            throw ProviderError.parseError("Invalid JSON structure")
        }
        
        var totalInput: Int64 = 0
        var totalOutput: Int64 = 0
        var totalCost: Double = 0
        var modelMap: [String: ModelUsage] = [:]
        
        for bucket in dataArray {
            guard let results = bucket["results"] as? [[String: Any]] else { continue }
            
            for result in results {
                let model = result["model"] as? String ?? "unknown"
                
                let uncached = result["uncached_input_tokens"] as? Int64 ?? Int64(result["uncached_input_tokens"] as? Int ?? 0)
                let cached = result["cached_input_tokens"] as? Int64 ?? Int64(result["cached_input_tokens"] as? Int ?? 0)
                let cacheCreation = result["cache_creation_input_tokens"] as? Int64 ?? Int64(result["cache_creation_input_tokens"] as? Int ?? 0)
                
                let input = uncached + cached + cacheCreation
                let output = result["output_tokens"] as? Int64 ?? Int64(result["output_tokens"] as? Int ?? 0)
                
                // Parse cost mapping - it could be string or double
                let costVal: Double
                if let costStr = result["cost"] as? String, let c = Double(costStr) {
                    costVal = c
                } else if let c = result["cost"] as? Double {
                    costVal = c
                } else {
                    costVal = 0
                }
                
                totalInput += input
                totalOutput += output
                totalCost += costVal
                
                if var existing = modelMap[model] {
                    existing.inputTokens += input
                    existing.outputTokens += output
                    existing.cost += costVal
                    modelMap[model] = existing
                } else {
                    modelMap[model] = ModelUsage(
                        modelName: model,
                        inputTokens: input,
                        outputTokens: output,
                        cost: costVal,
                        totalQuota: nil,
                        remainingQuota: nil
                    )
                }
            }
        }
        
        return UsageData(
            providerId: config.id,
            providerName: config.displayName,
            inputTokens: totalInput,
            outputTokens: totalOutput,
            cost: totalCost,
            currency: "USD",
            totalQuota: nil,
            usedAmount: totalCost,
            remainingBalance: nil,
            modelBreakdown: Array(modelMap.values).sorted { $0.cost > $1.cost },
            fetchedAt: Date(),
            errorMessage: nil,
            rawResponse: rawString
        )
    }
}

/// Claude.ai Web Provider - uses session cookies to fetch subscription status
struct ClaudeWebProvider: UsageProvider {
    static var providerType: ProviderType { .claudeWeb }
    
    @MainActor
    func fetchUsage(config: ProviderConfig) async throws -> UsageData {
        guard !config.apiKey.isEmpty else {
            throw ProviderError.invalidAPIKey
        }
        
        let sessionKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let orgs = try await fetchOrganizations(sessionKey: sessionKey)
        guard let firstOrg = orgs.first else {
            throw ProviderError.parseError("No organizations found for this session")
        }
        
        let orgId = firstOrg["uuid"] as? String ?? ""
        let orgName = firstOrg["name"] as? String ?? "Claude.ai"
        
        // Fetch detailed usage (percentage and reset time)
        let usageUrl = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage")!
        let usageDataRaw = try await ClaudeWebScanner.shared.fetch(url: usageUrl, sessionKey: sessionKey)
        
        let usageJsonRaw = (try? JSONSerialization.jsonObject(with: usageDataRaw) as? [String: Any]) ?? [:]
        
        if let errorObj = usageJsonRaw["error"] as? [String: Any] {
            let message = errorObj["message"] as? String ?? "未知错误"
            let type = errorObj["type"] as? String ?? ""
            let errorCode = (errorObj["details"] as? [String: Any])?["error_code"] as? String ?? ""
            
            var fullError = "Claude API 错误: \(message)"
            if !type.isEmpty { fullError += " (\(type))" }
            if !errorCode.isEmpty { fullError += " [Code: \(errorCode)]" }
            
            throw ProviderError.parseError(fullError)
        }
        
        let usageJson = usageJsonRaw
        
        // Parse five_hour (session) usage - based on CodexBar's research
        var usagePercent = 0.0
        var resetAtStr = ""
        
        if let fiveHour = usageJson["five_hour"] as? [String: Any] {
            if let utilization = fiveHour["utilization"] as? Int {
                usagePercent = Double(utilization) / 100.0 // It's usually a percentage 0-100
            } else if let utilization = fiveHour["utilization"] as? Double {
                usagePercent = utilization / 100.0
            }
            
            if let resetsAt = fiveHour["resets_at"] as? String {
                resetAtStr = resetsAt
            }
        } else {
            // Fallback to old format just in case
            usagePercent = usageJson["usage_percent"] as? Double ?? 0.0
            resetAtStr = usageJson["reset_at"] as? String ?? ""
        }
        
        var remainingMsg: String = ""
        if let sub = firstOrg["active_subscription"] as? [String: Any],
           let plan = sub["plan"] as? String {
            remainingMsg = "Plan: \(plan.capitalized)"
        }
        
        if usagePercent > 0 {
            let pctFriendly = String(format: "%.1f%%", usagePercent * 100)
            remainingMsg += " | Used: \(pctFriendly)"
        }
        
        if !resetAtStr.isEmpty {
            // Basic formatting for reset time
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: resetAtStr) {
                let df = DateFormatter()
                df.dateFormat = "HH:mm"
                remainingMsg += " | Resets: \(df.string(from: date))"
            }
        }
        
        return UsageData(
            providerId: config.id,
            providerName: config.displayName,
            inputTokens: 0,
            outputTokens: 0,
            cost: 0,
            currency: "Messages",
            totalQuota: 100, // Represent as percentage total
            usedAmount: usagePercent * 100,
            remainingBalance: nil,
            modelBreakdown: [],
            fetchedAt: Date(),
            errorMessage: remainingMsg.isEmpty ? nil : remainingMsg,
            rawResponse: "Org: \(orgName)\nID: \(orgId)\nRaw Usage: \(String(data: usageDataRaw, encoding: .utf8) ?? "None")"
        )
    }
    
    @MainActor
    private func fetchOrganizations(sessionKey: String) async throws -> [[String: Any]] {
        let url = URL(string: "https://claude.ai/api/organizations")!
        
        // Use the hidden WKWebView scanner to bypass Cloudflare (Real browser fingerprint)
        let data = try await ClaudeWebScanner.shared.fetch(url: url, sessionKey: sessionKey)
        
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorObj = dict["error"] as? [String: Any] {
            let message = errorObj["message"] as? String ?? "未知错误"
            let type = errorObj["type"] as? String ?? ""
            let errorCode = (errorObj["details"] as? [String: Any])?["error_code"] as? String ?? ""
            
            var fullError = "Claude API 错误: \(message)"
            if !type.isEmpty { fullError += " (\(type))" }
            if !errorCode.isEmpty { fullError += " [Code: \(errorCode)]" }
            
            throw ProviderError.parseError(fullError)
        }
        
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            let content = String(data: data, encoding: .utf8) ?? "Non-UTF8"
            throw ProviderError.parseError("解析 Org 列表失败。内容预览: \(content.prefix(150))")
        }
        
        // CodexBar uses 'uuid', while some older versions might use 'id'
        // Let's normalize it to a consistent structure
        return json.map { org in
            var normalized = org
            if let uuid = org["uuid"] as? String {
                normalized["id"] = uuid
            }
            return normalized
        }
    }
}

// MARK: - Claude Web Scanner (Bypasses Cloudflare)

/// A utility to perform Claude.ai API requests using a hidden WKWebView to bypass Cloudflare TLS fingerprinting.
@MainActor
class ClaudeWebScanner: NSObject, WKNavigationDelegate {
    static let shared = ClaudeWebScanner()
    
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<Data, Error>?
    
    // Simple cache to avoid redundant heavy loads
    private var cache: [URL: (data: Data, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 30 // 30 seconds
    
    private override init() {
        super.init()
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        // Set a realistic user agent
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
        self.webView = webView
    }
    
    func fetch(url: URL, sessionKey: String) async throws -> Data {
        // 1. Check cache first
        if let entry = cache[url], Date().timeIntervalSince(entry.timestamp) < cacheTTL {
            return entry.data
        }
        
        // Ensure only one fetch at a time
        if continuation != nil {
            throw NSError(domain: "ClaudeWebScanner", code: -2, userInfo: [NSLocalizedDescriptionKey: "A fetch is already in progress"])
        }
        
        let cookieStore = webView!.configuration.websiteDataStore.httpCookieStore
        
        // Clear existing session_key if any
        let cookies = await cookieStore.allCookies()
        for c in cookies where c.name == "session_key" {
            await cookieStore.deleteCookie(c)
        }
        
        // Set new session_key for both apex and dot domains
        let cookieProperties: [HTTPCookiePropertyKey: Any] = [
            .domain: ".claude.ai",
            .path: "/",
            .name: "session_key",
            .value: sessionKey,
            .secure: "TRUE",
            .expires: Date(timeIntervalSinceNow: 3600 * 24 * 30)
        ]
        
        if let cookie = HTTPCookie(properties: cookieProperties) {
            await cookieStore.setCookie(cookie)
        }
        
        var apexProperties = cookieProperties
        apexProperties[.domain] = "claude.ai"
        if let apexCookie = HTTPCookie(properties: apexProperties) {
            await cookieStore.setCookie(apexCookie)
        }

        // Also set 'sessionKey' (camelCase) which CodexBar uses in its headers
        var camelProperties = cookieProperties
        camelProperties[.name] = "sessionKey"
        if let camelCookie = HTTPCookie(properties: camelProperties) {
            await cookieStore.setCookie(camelCookie)
        }

        var camelApexProperties = apexProperties
        camelApexProperties[.name] = "sessionKey"
        if let camelApexCookie = HTTPCookie(properties: camelApexProperties) {
            await cookieStore.setCookie(camelApexCookie)
        }
        
        // Give a tiny bit of time for the store to sync with the internal process
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            var request = URLRequest(url: url)
            request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")
            request.setValue("https://claude.ai/chat", forHTTPHeaderField: "Referer")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            
            webView?.load(request)
            
            // Timeout safety (20s)
            Task {
                try? await Task.sleep(nanoseconds: 20 * 1_000_000_000)
                if self.continuation != nil {
                    self.continuation?.resume(throwing: NSError(domain: "ClaudeWebScanner", code: -3, userInfo: [NSLocalizedDescriptionKey: "WebView request timed out"]))
                    self.continuation = nil
                    self.webView?.stopLoading()
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            // Track the last status code for debugging
            self.lastStatusCode = response.statusCode
        }
        decisionHandler(.allow)
    }
    
    // MARK: - WKNavigationDelegate
    
    private var lastStatusCode: Int?
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Robust JS extraction for JSON responses in a browser
        let js = """
        (function() {
            var text = document.body.innerText || document.body.textContent || "";
            var pre = document.querySelector('pre');
            if (pre) text = pre.innerText || pre.textContent || text;
            return text.trim();
        })()
        """
        
        // Give a bit more time for any JS challenges to clear (1s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            webView.evaluateJavaScript(js) { [weak self] result, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.continuation?.resume(throwing: error)
                } else if let jsonString = result as? String, let data = jsonString.data(using: .utf8) {
                    // Try to parse just to validate
                    if (try? JSONSerialization.jsonObject(with: data)) != nil {
                        // Cache the successful result
                        if let url = webView.url {
                            self.cache[url] = (data, Date())
                        }
                        self.continuation?.resume(returning: data)
                    } else {
                        // Potential Cloudflare or error page
                        var errorMsg = "解析 JSON 失败 (不是有效的格式)。"
                        if let status = self.lastStatusCode {
                            errorMsg += " (HTTP Status: \(status))"
                        }
                        let msgPreview = jsonString.count > 120 ? String(jsonString.prefix(120)) + "..." : jsonString
                        self.continuation?.resume(throwing: NSError(domain: "ClaudeWebScanner", code: -4, userInfo: [NSLocalizedDescriptionKey: "\(errorMsg) 内容预览: \(msgPreview)"]))
                    }
                } else {
                    self.continuation?.resume(throwing: NSError(domain: "ClaudeWebScanner", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法从网页中提取文本内容"]))
                }
                self.continuation = nil
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if continuation != nil {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if continuation != nil {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
