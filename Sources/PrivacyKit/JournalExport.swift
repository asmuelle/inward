import Foundation
import JournalStore

/// The decrypted contents of an export: the user's entries and their transcription
/// provenance, plus when it was made. This is what an import reads back.
public struct ExportPayload: Codable, Sendable, Equatable {
    public let formatVersion: Int
    public let exportedAt: Date
    public let entries: [Entry]
    public let transcriptions: [Transcription]

    public init(formatVersion: Int = 1, exportedAt: Date, entries: [Entry], transcriptions: [Transcription]) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.entries = entries
        self.transcriptions = transcriptions
    }
}

/// Client-side-encrypted export of the whole journal. Entries are serialized then
/// sealed with a passphrase-derived key *before* any byte reaches Files or iCloud
/// Drive — the user holds the only key. Export and restore are deliberately free of
/// any device dependency, and reading/exporting is never paywalled (invariant #8).
public enum JournalExporter {
    /// Produce the encrypted archive bytes to write to a `.inwardbackup` file.
    /// `exportedAt` is injected rather than read from the clock so the result is
    /// deterministic and testable.
    public static func archiveData(
        entries: [Entry],
        transcriptions: [Transcription],
        exportedAt: Date,
        passphrase: String,
        iterations: Int = PassphraseKey.defaultIterations
    ) throws -> Data {
        let payload = ExportPayload(
            exportedAt: exportedAt,
            entries: entries,
            transcriptions: transcriptions
        )
        let plaintext = try encode(payload)
        let archive = try EncryptedExport.seal(plaintext, passphrase: passphrase, iterations: iterations)
        return try encode(archive)
    }

    /// Recover the journal from an archive produced by `archiveData`. Throws
    /// `ExportError.wrongPassphraseOrCorrupt` on a bad passphrase or tampering.
    public static func restore(from data: Data, passphrase: String) throws -> ExportPayload {
        let archive: EncryptedArchive
        do {
            archive = try decoder.decode(EncryptedArchive.self, from: data)
        } catch {
            throw ExportError.malformedArchive
        }
        let plaintext = try EncryptedExport.open(archive, passphrase: passphrase)
        do {
            return try decoder.decode(ExportPayload.self, from: plaintext)
        } catch {
            throw ExportError.malformedArchive
        }
    }

    // MARK: - Coding

    private static func encode(_ value: some Encodable) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw ExportError.sealingFailed
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
