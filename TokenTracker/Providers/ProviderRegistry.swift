import Foundation

/// Registry of all available providers - maps ProviderType to implementation
final class ProviderRegistry {
    static let shared = ProviderRegistry()
    
    private var providers: [ProviderType: any UsageProvider] = [:]
    
    private init() {
        // Register built-in providers
        register(OpenAIProvider())
        register(DeepSeekProvider())
        register(MiniMaxProvider())
        register(AnthropicProvider())
        register(GeminiProvider())
        register(CustomProvider())
    }
    
    func register(_ provider: any UsageProvider) {
        providers[type(of: provider).providerType] = provider
    }
    
    func provider(for type: ProviderType) -> (any UsageProvider)? {
        providers[type]
    }
    
    func fetchUsage(for config: ProviderConfig) async throws -> UsageData {
        guard let provider = providers[config.providerType] else {
            return UsageData.error(
                providerId: config.id,
                providerName: config.displayName,
                message: "Provider not found"
            )
        }
        return try await provider.fetchUsage(config: config)
    }
    
    /// Built-in provider configurations (defaults)
    static let builtInConfigs: [ProviderConfig] = [
        ProviderConfig(
            id: "openai",
            displayName: "OpenAI",
            iconName: "brain.head.profile",
            brandColorHex: "#10A37F",
            isEnabled: false,
            apiKey: "",
            providerType: .openAI,
            endpointConfig: nil,
            isBuiltIn: true
        ),
        ProviderConfig(
            id: "deepseek",
            displayName: "DeepSeek",
            iconName: "magnifyingglass.circle",
            brandColorHex: "#4D6BFE",
            isEnabled: false,
            apiKey: "",
            providerType: .deepSeek,
            endpointConfig: nil,
            isBuiltIn: true
        ),
        ProviderConfig(
            id: "minimax",
            displayName: "MiniMax",
            iconName: "waveform",
            brandColorHex: "#8B5CF6",
            isEnabled: false,
            apiKey: "",
            providerType: .miniMax,
            endpointConfig: nil,
            isBuiltIn: true
        ),
    ]
}
