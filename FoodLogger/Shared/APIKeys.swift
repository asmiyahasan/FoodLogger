import Foundation

/// Finds an API key: first the Keychain (set in the app's Settings),
/// then Secrets.plist (set in Xcode; ignored by Git so it never reaches GitHub).
nonisolated enum APIKeys {
    static func value(for key: KeychainStore.Key) -> String? {
        if let saved = KeychainStore.read(key), !saved.isEmpty {
            return saved
        }
        return fromSecretsFile(key)
    }

    static func fromSecretsFile(_ key: KeychainStore.Key) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let value = (plist[key.rawValue] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty, !value.hasPrefix("PASTE_")
        else { return nil }
        return value
    }
}
