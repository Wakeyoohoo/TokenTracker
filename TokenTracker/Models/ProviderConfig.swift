import Foundation
import SwiftUI

/// Configuration for a single API provider - can be built-in or user-defined
struct ProviderConfig: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    var iconName: String        // SF Symbol name
    var brandColorHex: String   // Hex color like "#10A37F"
    var isEnabled: Bool
    var apiKey: String
    
    /// Provider type determines how usage data is fetched
    var providerType: ProviderType
    
    /// For custom/generic providers: endpoint configuration
    var endpointConfig: EndpointConfig?
    
    /// Whether this is a built-in or user-created provider
    var isBuiltIn: Bool
    
    var brandColor: Color {
        Color(hex: brandColorHex)
    }
    
    static func == (lhs: ProviderConfig, rhs: ProviderConfig) -> Bool {
        lhs.id == rhs.id
    }
}

enum ProviderType: String, Codable, CaseIterable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case deepSeek = "deepseek"
    case miniMax = "minimax"
    case gemini = "gemini"
    case custom = "custom"      // User-defined generic provider
    
    var defaultDisplayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .deepSeek: return "DeepSeek"
        case .miniMax: return "MiniMax"
        case .gemini: return "Google Gemini"
        case .custom: return "Custom"
        }
    }
    
    var defaultIconName: String {
        switch self {
        case .openAI: return "brain.head.profile"
        case .anthropic: return "sparkle"
        case .deepSeek: return "magnifyingglass.circle"
        case .miniMax: return "waveform"
        case .gemini: return "diamond"
        case .custom: return "puzzlepiece"
        }
    }
    
    var defaultColorHex: String {
        switch self {
        case .openAI: return "#10A37F"
        case .anthropic: return "#D4A574"
        case .deepSeek: return "#4D6BFE"
        case .miniMax: return "#8B5CF6"
        case .gemini: return "#4285F4"
        case .custom: return "#6B7280"
        }
    }
    
    var supportsAutoFetch: Bool {
        switch self {
        case .openAI, .deepSeek, .miniMax, .custom:
            return true
        case .anthropic, .gemini:
            return false
        }
    }
}

/// Configuration for a custom API endpoint
struct EndpointConfig: Codable {
    var baseURL: String
    var path: String
    var method: String  // "GET" or "POST"
    var authType: AuthType
    var authHeader: String  // e.g., "Authorization"
    var authPrefix: String  // e.g., "Bearer "
    
    /// JSON key paths to extract data from response
    var balanceKeyPath: String?      // e.g., "balance_infos.0.total_balance"
    var remainingKeyPath: String?    // e.g., "balance_infos.0.granted_balance"
    var currencyKeyPath: String?
    var currency: String
    
    enum AuthType: String, Codable {
        case bearer
        case apiKey   // Custom header: "X-API-Key: xxx"
    }
}
