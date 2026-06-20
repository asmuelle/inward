import Foundation
import JournalStore
@testable import PrivacyKit
import Testing

// Small iteration count keeps the suite fast; the algorithm is identical.
private let testIterations = 1000

private func sampleEntry(_ text: String) -> Entry {
    Entry(
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        source: .voice,
        transcriptRaw: text,
        textEdited: text,
        durationSec: 12.5,
        locale: "en_US"
    )
}

@Suite("EncryptedExport — passphrase-sealed bytes, fail-closed")
struct EncryptedExportTests {
    @Test("seal then open with the right passphrase round-trips the bytes")
    func roundTrips() throws {
        let plaintext = Data("a quiet evening, kept".utf8)

        let archive = try EncryptedExport.seal(plaintext, passphrase: "open sesame", iterations: testIterations)
        let recovered = try EncryptedExport.open(archive, passphrase: "open sesame")

        #expect(recovered == plaintext)
    }

    @Test("the wrong passphrase fails closed")
    func wrongPassphraseFails() throws {
        let archive = try EncryptedExport.seal(Data("secret".utf8), passphrase: "correct horse", iterations: testIterations)

        #expect(throws: ExportError.wrongPassphraseOrCorrupt) {
            try EncryptedExport.open(archive, passphrase: "wrong horse")
        }
    }

    @Test("a tampered ciphertext fails closed — the GCM tag catches it")
    func tamperFails() throws {
        let archive = try EncryptedExport.seal(Data("secret".utf8), passphrase: "open sesame", iterations: testIterations)
        var sealed = archive.sealed
        sealed[sealed.count - 1] ^= 0xFF
        let tampered = EncryptedArchive(
            version: archive.version, kdf: archive.kdf, iterations: archive.iterations, salt: archive.salt, sealed: sealed
        )

        #expect(throws: ExportError.wrongPassphraseOrCorrupt) {
            try EncryptedExport.open(tampered, passphrase: "open sesame")
        }
    }

    @Test("an empty passphrase is refused on both ends")
    func emptyPassphraseRefused() throws {
        #expect(throws: ExportError.emptyPassphrase) {
            try EncryptedExport.seal(Data("x".utf8), passphrase: "", iterations: testIterations)
        }
        let archive = try EncryptedExport.seal(Data("x".utf8), passphrase: "real", iterations: testIterations)
        #expect(throws: ExportError.emptyPassphrase) {
            try EncryptedExport.open(archive, passphrase: "")
        }
    }

    @Test("an unknown archive version is rejected, not silently opened")
    func unknownVersionRejected() throws {
        let archive = try EncryptedExport.seal(Data("x".utf8), passphrase: "real", iterations: testIterations)
        let future = EncryptedArchive(
            version: 99, kdf: archive.kdf, iterations: archive.iterations, salt: archive.salt, sealed: archive.sealed
        )

        #expect(throws: ExportError.malformedArchive) {
            try EncryptedExport.open(future, passphrase: "real")
        }
    }

    @Test("an out-of-range iteration count from a tampered archive is rejected before any derivation", arguments: [1, 999, 20_000_000])
    func outOfRangeIterationsRejected(iterations: Int) throws {
        let archive = try EncryptedExport.seal(Data("x".utf8), passphrase: "real", iterations: testIterations)
        let tampered = EncryptedArchive(
            version: archive.version, kdf: archive.kdf, iterations: iterations, salt: archive.salt, sealed: archive.sealed
        )

        // Rejected on the parameter guard — a billion-round DoS never starts.
        #expect(throws: ExportError.malformedArchive) {
            try EncryptedExport.open(tampered, passphrase: "real")
        }
    }
}

@Suite("JournalExporter — client-side-encrypted journal export")
struct JournalExporterTests {
    private let exportedAt = Date(timeIntervalSince1970: 1_700_500_000)

    @Test("a journal round-trips through an encrypted archive")
    func journalRoundTrips() throws {
        let entries = [sampleEntry("Coffee on the balcony before anyone woke up."), sampleEntry("Long day, quiet end.")]
        let transcriptions = [Transcription(entryId: entries[0].id, engine: .speechTranscriber, confidence: 0.92, completedAt: exportedAt)]

        let data = try JournalExporter.archiveData(
            entries: entries, transcriptions: transcriptions, exportedAt: exportedAt, passphrase: "open sesame", iterations: testIterations
        )
        let restored = try JournalExporter.restore(from: data, passphrase: "open sesame")

        #expect(restored.entries == entries)
        #expect(restored.transcriptions == transcriptions)
        #expect(restored.exportedAt == exportedAt)
    }

    @Test("entry text never appears as plaintext in the exported bytes")
    func neverPlaintextOnDisk() throws {
        let secret = "balcony"
        let data = try JournalExporter.archiveData(
            entries: [sampleEntry("Coffee on the \(secret) before anyone woke up.")],
            transcriptions: [],
            exportedAt: exportedAt,
            passphrase: "open sesame",
            iterations: testIterations
        )

        #expect(data.range(of: Data(secret.utf8)) == nil, "the user's words must be opaque on disk")
    }

    @Test("the wrong passphrase cannot restore a journal")
    func wrongPassphraseCannotRestore() throws {
        let data = try JournalExporter.archiveData(
            entries: [sampleEntry("private")], transcriptions: [], exportedAt: exportedAt, passphrase: "right", iterations: testIterations
        )

        #expect(throws: ExportError.wrongPassphraseOrCorrupt) {
            try JournalExporter.restore(from: data, passphrase: "nope")
        }
    }

    @Test("garbage input is reported as a malformed archive, not a crash")
    func garbageIsMalformed() {
        #expect(throws: ExportError.malformedArchive) {
            try JournalExporter.restore(from: Data("not an archive".utf8), passphrase: "whatever")
        }
    }
}
