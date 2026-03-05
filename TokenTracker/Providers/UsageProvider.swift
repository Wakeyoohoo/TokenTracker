import Foundation

/// Protocol that all usage providers must implement
protocol UsageProvider {
    /// Unique identifier for this provider type
    static var providerType: ProviderType { get }
    
    /// Fetch usage data using the given API key
    func fetchUsage(config: ProviderConfig) async throws -> UsageData
}

/// Errors that providers can throw
enum ProviderError: LocalizedError {
    case invalidAPIKey
    case networkError(String)
    case parseError(String)
    case unsupported(String)
    case httpError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .parseError(let msg):
            return "Parse error: \(msg)"
        case .unsupported(let msg):
            return msg
        case .httpError(let code, let msg):
            return "HTTP \(code): \(msg)"
        }
    }
}
