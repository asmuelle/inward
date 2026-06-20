import CryptoKit
import Foundation

/// Derives the export key from a user passphrase. A portable encrypted export must
/// not depend on the device keychain (the point is to restore on a new phone), so
/// the key comes from the passphrase via PBKDF2-HMAC-SHA256 (RFC 8018). The work
/// factor is what makes a stolen archive expensive to brute-force.
///
/// Implemented on CryptoKit's HMAC primitive rather than CommonCrypto so it builds
/// and is testable on every platform the core targets.
public enum PassphraseKey {
    /// OWASP 2023 guidance for PBKDF2-HMAC-SHA256. Tests override with a small count.
    /// Public because it is the default for the public export API's `iterations`.
    public static let defaultIterations = 210_000
    static let saltByteCount = 16
    static let derivedKeyByteCount = 32

    /// 16 cryptographically random salt bytes, sourced from CryptoKit's secure RNG.
    static func randomSalt() -> Data {
        SymmetricKey(size: .init(bitCount: saltByteCount * 8)).withUnsafeBytes { Data($0) }
    }

    static func deriveKey(passphrase: String, salt: Data, iterations: Int) -> SymmetricKey {
        let derived = pbkdf2SHA256(
            password: Array(passphrase.utf8),
            salt: salt,
            iterations: max(1, iterations),
            keyByteCount: derivedKeyByteCount
        )
        return SymmetricKey(data: derived)
    }

    /// PBKDF2 with HMAC-SHA256 as the PRF. The password is the HMAC key; each block
    /// is `T_i = U_1 ^ U_2 ^ ... ^ U_c`, with `U_1 = PRF(password, salt || INT(i))`.
    private static func pbkdf2SHA256(password: [UInt8], salt: Data, iterations: Int, keyByteCount: Int) -> Data {
        let key = SymmetricKey(data: password)
        let hashLength = SHA256.byteCount
        let blockCount = (keyByteCount + hashLength - 1) / hashLength
        var derived = Data()

        for blockIndex in 1 ... blockCount {
            var message = salt
            var bigEndianIndex = UInt32(blockIndex).bigEndian
            withUnsafeBytes(of: &bigEndianIndex) { message.append(contentsOf: $0) }

            var u = Data(HMAC<SHA256>.authenticationCode(for: message, using: key))
            var block = u
            if iterations > 1 {
                for _ in 2 ... iterations {
                    u = Data(HMAC<SHA256>.authenticationCode(for: u, using: key))
                    for index in 0 ..< block.count {
                        block[index] ^= u[index]
                    }
                }
            }
            derived.append(block)
        }

        return Data(derived.prefix(keyByteCount))
    }
}
