import CryptoKit
import Foundation
@testable import PrivacyKit
import Testing

private func hex(_ key: SymmetricKey) -> String {
    key.withUnsafeBytes { Data($0) }.map { String(format: "%02x", $0) }.joined()
}

@Suite("PassphraseKey — PBKDF2-HMAC-SHA256 derivation")
struct PassphraseKeyTests {
    // Published PBKDF2-HMAC-SHA256 test vectors (dkLen = 32). Matching these proves
    // the CryptoKit-based implementation is the real algorithm, not a lookalike.
    @Test("matches the standard vector at 1 iteration")
    func knownAnswerOneIteration() {
        let key = PassphraseKey.deriveKey(passphrase: "password", salt: Data("salt".utf8), iterations: 1)

        #expect(hex(key) == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
    }

    @Test("matches the standard vector at 2 iterations")
    func knownAnswerTwoIterations() {
        let key = PassphraseKey.deriveKey(passphrase: "password", salt: Data("salt".utf8), iterations: 2)

        #expect(hex(key) == "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43")
    }

    @Test("derivation is deterministic for the same inputs")
    func deterministic() {
        let salt = Data("fixed-salt-16byte".utf8)
        let a = PassphraseKey.deriveKey(passphrase: "open sesame", salt: salt, iterations: 1000)
        let b = PassphraseKey.deriveKey(passphrase: "open sesame", salt: salt, iterations: 1000)

        #expect(hex(a) == hex(b))
    }

    @Test("a different salt yields a different key")
    func saltSeparation() {
        let a = PassphraseKey.deriveKey(passphrase: "open sesame", salt: PassphraseKey.randomSalt(), iterations: 1000)
        let b = PassphraseKey.deriveKey(passphrase: "open sesame", salt: PassphraseKey.randomSalt(), iterations: 1000)

        #expect(hex(a) != hex(b))
    }

    @Test("a different passphrase yields a different key")
    func passphraseSeparation() {
        let salt = PassphraseKey.randomSalt()
        let a = PassphraseKey.deriveKey(passphrase: "open sesame", salt: salt, iterations: 1000)
        let b = PassphraseKey.deriveKey(passphrase: "open sesam", salt: salt, iterations: 1000)

        #expect(hex(a) != hex(b))
    }

    @Test("the random salt is the documented length")
    func saltLength() {
        #expect(PassphraseKey.randomSalt().count == PassphraseKey.saltByteCount)
    }
}
