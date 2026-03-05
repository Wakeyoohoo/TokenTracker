import Foundation

/// Generic custom provider that uses EndpointConfig to make API calls
/// This powers the config-file and UI-based provider registration
struct CustomProvider: UsageProvider {
    static var providerType: ProviderType { .custom }
    
    func fetchUsage(config: ProviderConfig) async throws -> UsageData {
        guard let endpointConfig = config.endpointConfig else {
            throw ProviderError.unsupported("No endpoint configuration for custom provider")
        }
        
        guard !config.apiKey.isEmpty else {
            throw ProviderError.invalidAPIKey
        }
        
        // Build the URL
        let urlString = endpointConfig.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            + "/" + endpointConfig.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        guard let url = URL(string: urlString) else {
            throw ProviderError.networkError("Invalid URL: \(urlString)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpointConfig.method
        
        // Set auth header
        let authValue: String
        switch endpointConfig.authType {
        case .bearer:
            authValue = "\(endpointConfig.authPrefix)\(config.apiKey)"
        case .apiKey:
            authValue = config.apiKey
        }
        request.setValue(authValue, forHTTPHeaderField: endpointConfig.authHeader)
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
        return try parseResponse(data: data, rawString: rawString, config: config, endpointConfig: endpointConfig)
    }
    
    private func parseResponse(data: Data, rawString: String, config: ProviderConfig, endpointConfig: EndpointConfig) throws -> UsageData {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.parseError("Invalid JSON response")
        }
        
        let totalBalance = extractValue(from: json, keyPath: endpointConfig.balanceKeyPath) ?? 0
        let remaining = extractValue(from: json, keyPath: endpointConfig.remainingKeyPath) ?? totalBalance
        let used = totalBalance > 0 ? totalBalance - remaining : 0
        
        return UsageData(
            providerId: config.id,
            providerName: config.displayName,
            inputTokens: 0,
            outputTokens: 0,
            cost: used,
            currency: endpointConfig.currency,
            totalQuota: totalBalance > 0 ? totalBalance : nil,
            usedAmount: used > 0 ? used : nil,
            remainingBalance: remaining > 0 ? remaining : nil,
            modelBreakdown: [],
            fetchedAt: Date(),
            errorMessage: nil,
            rawResponse: rawString
        )
    }
    
    /// Extract a numeric value from nested JSON using dot-separated key path
    private func extractValue(from json: [String: Any], keyPath: String?) -> Double? {
        guard let keyPath = keyPath, !keyPath.isEmpty else { return nil }
        
        let keys = keyPath.split(separator: ".").map(String.init)
        var current: Any = json
        
        for key in keys {
            if let dict = current as? [String: Any] {
                guard let next = dict[key] else { return nil }
                current = next
            } else if let arr = current as? [Any], let index = Int(key), index < arr.count {
                current = arr[index]
            } else {
                return nil
            }
        }
        
        if let d = current as? Double { return d }
        if let i = current as? Int { return Double(i) }
        if let s = current as? String { return Double(s) }
        return nil
    }
}
