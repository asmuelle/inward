import DesignSystem
import Foundation
@testable import Inward
import JournalStore
import PrivacyKit
import Testing

@MainActor
@Suite("Privacy wiring — lock gate and encrypted export models")
struct PrivacyWiringTests {
    // MARK: - Lock gate

    @Test("enabled + capable: engage locks, then a successful unlock opens it")
    func enabledLocksThenUnlocks() async {
        let gate = LockGateModel(
            authenticator: MockBiometricAuthenticator(outcome: .success),
            isEnabled: { true }
        )

        await gate.engage()
        #expect(gate.state == .locked)

        await gate.attemptUnlock()
        #expect(gate.state == .unlocked)
    }

    @Test("disabled: the gate never closes")
    func disabledStaysOpen() async {
        let gate = LockGateModel(
            authenticator: MockBiometricAuthenticator(outcome: .success),
            isEnabled: { false }
        )

        await gate.engage()

        #expect(gate.state == .unlocked)
    }

    @Test("a failed authentication keeps the gate closed")
    func failedUnlockStaysLocked() async {
        let gate = LockGateModel(
            authenticator: MockBiometricAuthenticator(outcome: .failed),
            isEnabled: { true }
        )

        await gate.engage()
        await gate.attemptUnlock()

        #expect(gate.state == .locked)
    }

    // MARK: - Export

    private func store(with entries: [Entry]) async throws -> EncryptedFileJournalStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-wiring-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("journal.inward")
        let store = EncryptedFileJournalStore(fileURL: url, keyProvider: StaticKeyProvider.random())
        for entry in entries {
            try await store.save(entry: entry, transcription: nil)
        }
        return store
    }

    @Test("export produces a file that restores with the same passphrase")
    func exportRoundTrips() async throws {
        let entries = [Entry(createdAt: Date(timeIntervalSince1970: 1_700_000_000), source: .text, transcriptRaw: "kept", textEdited: "kept", locale: "en_US")]
        // Small iteration count keeps the test fast; the path is otherwise identical.
        let model = ExportModel(store: try await store(with: entries), iterations: 1_000)

        await model.export(passphrase: "open sesame")

        guard case let .ready(url) = model.phase else {
            Issue.record("expected a ready export, got \(model.phase)")
            return
        }
        let restored = try JournalExporter.restore(from: Data(contentsOf: url), passphrase: "open sesame")
        #expect(restored.entries == entries)
    }

    @Test("an empty passphrase is reported, not exported")
    func emptyPassphraseReported() async throws {
        let model = ExportModel(store: try await store(with: []), iterations: 1_000)

        await model.export(passphrase: "")

        #expect(model.phase == .failed(Copy.exportPassphraseRequired))
    }
}
