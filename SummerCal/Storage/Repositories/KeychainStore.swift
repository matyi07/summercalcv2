import Foundation
import Security

final class KeychainStore {
    static let shared = KeychainStore()
    private let serviceName = "com.summercal.v2"

    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        try? delete(key: key)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveError(status: status)
        }
    }

    func read(key: String) throws -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.readError(status: status)
        }
        return value
    }

    func delete(key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteError(status: status)
        }
    }

    func deleteAll() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName
        ]
        SecItemDelete(query as CFDictionary)
    }

    func saveAPIKey(provider: String, key: String) throws {
        try save(key: "ai_key_\(provider)", value: key)
    }

    func readAPIKey(provider: String) throws -> String {
        do {
            return try read(key: "ai_key_\(provider)")
        } catch {
            // Migration: try old keychain service used by SettingsViewModel before the fix
            if let legacy = try? readLegacy(provider: provider) {
                try save(key: "ai_key_\(provider)", value: legacy)
                return legacy
            }
            throw error
        }
    }

    func deleteAPIKey(provider: String) throws {
        try delete(key: "ai_key_\(provider)")
        try? deleteLegacy(provider: provider)
    }

    // MARK: - Legacy migration (previously SettingsViewModel used separate service)

    private func readLegacy(provider: String) throws -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.summercal.apikey",
            kSecAttrAccount: provider,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.readError(status: status)
        }
        return value
    }

    private func deleteLegacy(provider: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.summercal.apikey",
            kSecAttrAccount: provider
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case encodingError
    case saveError(status: OSStatus)
    case readError(status: OSStatus)
    case deleteError(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingError: "Failed to encode value"
        case .saveError(let s): "Failed to save to Keychain (status: \(s))"
        case .readError(let s): "Failed to read from Keychain (status: \(s))"
        case .deleteError(let s): "Failed to delete from Keychain (status: \(s))"
        }
    }
}
