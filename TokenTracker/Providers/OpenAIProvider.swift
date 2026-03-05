import Foundation

/// OpenAI usage provider - uses the Admin API to fetch organization usage
struct OpenAIProvider: UsageProvider {
    static var providerType: ProviderType { .openAI }
    
    func fetchUsage(config: ProviderConfig) async throws -> UsageData {
        guard !config.apiKey.isEmpty else {
            throw ProviderError.invalidAPIKey
        }
        
        // Use /organization/usage/completions endpoint
        let now = Int(Date().timeIntervalSince1970)
        let startOfMonth = Int(Date.daysAgo(30).timeIntervalSince1970)
        
        var components = URLComponents(string: "https://api.openai.com/v1/organization/usage/completions")!
        components.queryItems = [
            URLQueryItem(name: "start_time", value: "\(startOfMonth)"),
            URLQueryItem(name: "end_time", value: "\(now)"),
            URLQueryItem(name: "bucket_width", value: "1d"),
            URLQueryItem(name: "group_by", value: "model"),
        ]
        
        var request = URLRequest(url: components.url!)
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
                let input = (result["input_tokens"] as? Int64) ?? Int64(result["input_tokens"] as? Int ?? 0)
                let output = (result["output_tokens"] as? Int64) ?? Int64(result["output_tokens"] as? Int ?? 0)
                let numRequests = result["num_model_requests"] as? Int ?? 0
                
                // Approximate cost calculation (can be refined per-model)
                let inputCost = Double(input) / 1_000_000 * 2.50   // Default rate
                let outputCost = Double(output) / 1_000_000 * 10.0
                let cost = inputCost + outputCost
                
                totalInput += input
                totalOutput += output
                totalCost += cost
                
                if var existing = modelMap[model] {
                    existing.inputTokens += input
                    existing.outputTokens += output
                    existing.cost += cost
                    modelMap[model] = existing
                } else {
                    modelMap[model] = ModelUsage(
                        modelName: model,
                        inputTokens: input,
                        outputTokens: output,
                        cost: cost,
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
