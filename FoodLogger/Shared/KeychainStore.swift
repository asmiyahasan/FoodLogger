import Foundation
import Security

/// Stores API keys in the device Keychain, never in code or settings files.
nonisolated enum KeychainStore {
    nonisolated enum Key: String, Sendable {
        case usdaAPIKey
        case claudeAPIKey
    }

    private static let service = "com.asmiyahasan.FoodLogger"

    static func read(_ key: Key) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ value: String, for key: Key) -> Bool {
        delete(key)
        var query = baseQuery(for: key)
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func delete(_ key: Key) {
        _ = SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    private static func baseQuery(for key: Key) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        #if os(macOS)
        query[kSecUseDataProtectionKeychain as String] = true
        #endif
        return query
    }
}
