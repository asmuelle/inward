import CryptoKit
import Foundation

public enum ExportError: Error, Equatable {
    case emptyPassphrase
    case sealingFailed
    /// Wrong passphrase, or the archive was tampered with — AES-GCM cannot tell
    /// the two apart, and it must not: both mean "do not trust this content."
    case wrongPassphraseOrCorrupt
    case malformedArchive
}

/// The on-disk shape of an encrypted export: a self-describing envelope carrying
/// everything needed to derive the key and open the box — except the passphrase,
/// which only the user holds. Safe to hand to Files or iCloud Drive.
public struct EncryptedArchive: Codable, Sendable, Equatable {
    public let version: Int
    public let kdf: String
    public let iterations: Int
    public let salt: Data
    /// AES-GCM combined box: nonce ‖ ciphertext ‖ tag.
    public let sealed: Data

    static let currentVersion = 1
    static let kdfIdentifier = "pbkdf2-hmac-sha256"
}

/// Passphrase-based authenticated encryption of arbitrary bytes. AES-256-GCM under
/// a key derived from the passphrase; the GCM tag authenticates the ciphertext, so
/// any tampering or wrong key fails closed rather than yielding garbage plaintext.
public enum EncryptedExport {
    public static func seal(
        _ plaintext: Data,
        passphrase: String,
        iterations: Int = PassphraseKey.defaultIterations
    ) throws -> EncryptedArchive {
        guard !passphrase.isEmpty else { throw ExportError.emptyPassphrase }

        let salt = PassphraseKey.randomSalt()
        let key = PassphraseKey.deriveKey(passphrase: passphrase, salt: salt, iterations: iterations)
        guard let sealed = try? AES.GCM.seal(plaintext, using: key).combined else {
            throw ExportError.sealingFailed
        }
        return EncryptedArchive(
            version: EncryptedArchive.currentVersion,
            kdf: EncryptedArchive.kdfIdentifier,
            iterations: iterations,
            salt: salt,
            sealed: sealed
        )
    }

    public static func open(_ archive: EncryptedArchive, passphrase: String) throws -> Data {
        guard !passphrase.isEmpty else { throw ExportError.emptyPassphrase }
        guard archive.version == EncryptedArchive.currentVersion,
              archive.kdf == EncryptedArchive.kdfIdentifier
        else { throw ExportError.malformedArchive }

        let key = PassphraseKey.deriveKey(passphrase: passphrase, salt: archive.salt, iterations: archive.iterations)
        guard let box = try? AES.GCM.SealedBox(combined: archive.sealed),
              let plaintext = try? AES.GCM.open(box, using: key)
        else { throw ExportError.wrongPassphraseOrCorrupt }
        return plaintext
    }
}
