import CryptoKit
import Foundation

/// Supplies the symmetric key that encrypts the journal at rest. The key itself
/// never lives in the database file and never leaves the device.
public protocol KeyProviding: Sendable {
    func key() throws -> SymmetricKey
}

/// Test/preview provider with an explicit key. Production uses KeychainKeyProvider.
public struct StaticKeyProvider: KeyProviding {
    private let keyData: Data

    public init(key: SymmetricKey) {
        keyData = key.withUnsafeBytes { Data($0) }
    }

    public static func random() -> StaticKeyProvider {
        StaticKeyProvider(key: SymmetricKey(size: .bits256))
    }

    public func key() throws -> SymmetricKey {
        SymmetricKey(data: keyData)
    }
}
