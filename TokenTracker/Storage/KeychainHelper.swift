import Foundation

/// API key storage backed by UserDefaults (no Keychain authorization prompts)
final class APIKeyStore {
    static let shared = APIKeyStore()
    private let prefix = "apikey_"
    
    private init() {}
    
    func save(_ value: String, for key: String) {
        UserDefaults.standard.set(value, forKey: "\(prefix)\(key)")
    }
    
    func read(for key: String) -> String? {
        return UserDefaults.standard.string(forKey: "\(prefix)\(key)")
    }
    
    func delete(for key: String) {
        UserDefaults.standard.removeObject(forKey: "\(prefix)\(key)")
    }
}
