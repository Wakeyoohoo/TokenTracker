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
        register(ClaudeWebProvider())
        register(ClaudeCLIProvider())
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
            showInStatusBar: true,
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
            showInStatusBar: true,
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
            showInStatusBar: true,
            apiKey: "",
            providerType: .miniMax,
            endpointConfig: nil,
            isBuiltIn: true
        ),
        ProviderConfig(
            id: "anthropic",
            displayName: "Anthropic (Claude)",
            iconName: "sparkle",
            brandColorHex: "#D4A574",
            isEnabled: false,
            showInStatusBar: true,
            apiKey: "",
            providerType: .anthropic,
            endpointConfig: nil,
            isBuiltIn: true
        ),
        ProviderConfig(
            id: "gemini",
            displayName: "Google Gemini",
            iconName: "diamond",
            brandColorHex: "#4285F4",
            isEnabled: false,
            showInStatusBar: true,
            apiKey: "",
            providerType: .gemini,
            endpointConfig: nil,
            isBuiltIn: true
        ),
        ProviderConfig(
            id: "claude-web",
            displayName: "Claude.ai (Web)",
            iconName: "person.badge.shield.checkmark",
            brandColorHex: "#D4A574",
            isEnabled: false,
            showInStatusBar: true,
            apiKey: "",
            providerType: .claudeWeb,
            endpointConfig: nil,
            isBuiltIn: true
        ),
        ProviderConfig(
            id: "claude-cli",
            displayName: "Claude CLI",
            iconName: "terminal",
            brandColorHex: "#D4A574",
            isEnabled: false,
            showInStatusBar: true,
            apiKey: "",
            providerType: .claudeCLI,
            endpointConfig: nil,
            isBuiltIn: true
        )
    ]
}
