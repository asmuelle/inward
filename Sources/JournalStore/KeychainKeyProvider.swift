#if canImport(Security)
    import CryptoKit
    import Foundation
    import Security

    /// Generates a 256-bit journal key on first use and keeps it in the keychain,
    /// device-only, accessible only while unlocked. The key never leaves the device:
    /// `ThisDeviceOnly` excludes it from any keychain sync.
    public struct KeychainKeyProvider: KeyProviding {
        private let service: String
        private let account: String

        public init(service: String = "app.inward.journal", account: String = "journal-key-v1") {
            self.service = service
            self.account = account
        }

        public func key() throws -> SymmetricKey {
            if let existing = try loadKeyData() {
                return SymmetricKey(data: existing)
            }
            let fresh = SymmetricKey(size: .bits256)
            try store(keyData: fresh.withUnsafeBytes { Data($0) })
            return fresh
        }

        private var baseQuery: [String: Any] {
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
        }

        private func loadKeyData() throws -> Data? {
            var query = baseQuery
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            switch status {
            case errSecSuccess:
                return result as? Data
            case errSecItemNotFound:
                return nil
            default:
                throw JournalStoreError.keyUnavailable
            }
        }

        private func store(keyData: Data) throws {
            var attributes = baseQuery
            attributes[kSecValueData as String] = keyData
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

            let status = SecItemAdd(attributes as CFDictionary, nil)
            guard status == errSecSuccess || status == errSecDuplicateItem else {
                throw JournalStoreError.keyUnavailable
            }
        }
    }
#endif
