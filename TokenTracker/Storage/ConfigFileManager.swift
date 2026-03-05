import Foundation

/// Manages loading and saving custom provider JSON config files
/// Directory: ~/.config/tokentracker/providers/
final class ConfigFileManager {
    static let shared = ConfigFileManager()
    
    private let configDirURL: URL
    
    private init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        configDirURL = homeDir
            .appendingPathComponent(".config")
            .appendingPathComponent("tokentracker")
            .appendingPathComponent("providers")
    }
    
    /// Ensure the config directory exists
    func ensureDirectory() {
        try? FileManager.default.createDirectory(at: configDirURL, withIntermediateDirectories: true)
    }
    
    /// Load all custom provider configs from JSON files
    func loadCustomProviders() -> [ProviderConfig] {
        ensureDirectory()
        
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: configDirURL,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        
        let jsonFiles = files.filter { $0.pathExtension == "json" }
        var configs: [ProviderConfig] = []
        
        for file in jsonFiles {
            do {
                let data = try Data(contentsOf: file)
                var config = try JSONDecoder().decode(ProviderConfig.self, from: data)
                config.isBuiltIn = false
                config.providerType = .custom
                configs.append(config)
            } catch {
                print("Failed to load provider config from \(file.lastPathComponent): \(error)")
            }
        }
        
        return configs
    }
    
    /// Save a custom provider config as a JSON file
    func saveCustomProvider(_ config: ProviderConfig) throws {
        ensureDirectory()
        
        let fileName = config.id.replacingOccurrences(of: " ", with: "_").lowercased() + ".json"
        let fileURL = configDirURL.appendingPathComponent(fileName)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: fileURL)
    }
    
    /// Delete a custom provider config file
    func deleteCustomProvider(id: String) {
        let fileName = id.replacingOccurrences(of: " ", with: "_").lowercased() + ".json"
        let fileURL = configDirURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// Get the config directory path for user reference
    var configDirectoryPath: String {
        configDirURL.path
    }
}
