import DesignSystem
import Foundation
import JournalStore
import PrivacyKit
import SwiftUI

/// Drives a client-side-encrypted export: gather the journal, seal it with the
/// user's passphrase via the tested JournalExporter, and hand back a file URL to
/// share. Nothing is decrypted or transmitted; the passphrase never leaves here.
@MainActor
@Observable
final class ExportModel {
    enum Phase: Equatable {
        case idle
        case working
        case ready(URL)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private let store: any JournalStoring
    private let iterations: Int

    init(store: any JournalStoring, iterations: Int = PassphraseKey.defaultIterations) {
        self.store = store
        self.iterations = iterations
    }

    func export(passphrase: String) async {
        phase = .working
        do {
            let entries = try await store.allEntries()
            var transcriptions: [Transcription] = []
            for entry in entries {
                if let transcription = try await store.transcription(entryID: entry.id) {
                    transcriptions.append(transcription)
                }
            }
            let data = try JournalExporter.archiveData(
                entries: entries,
                transcriptions: transcriptions,
                exportedAt: Date(),
                passphrase: passphrase,
                iterations: iterations
            )
            phase = .ready(try write(data))
        } catch ExportError.emptyPassphrase {
            phase = .failed(Copy.exportPassphraseRequired)
        } catch {
            phase = .failed(Copy.exportFailed)
        }
    }

    private func write(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Inward journal backup", conformingTo: .data)
            .deletingPathExtension()
            .appendingPathExtension("inwardbackup")
        #if os(iOS)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
            try data.write(to: url, options: [.atomic])
        #endif
        return url
    }
}

/// Passphrase entry, then a share button for the sealed file. Reading and export
/// are never paywalled (invariant #8).
struct ExportView: View {
    @State private var model: ExportModel
    @Environment(\.dismiss) private var dismiss

    @State private var passphrase = ""
    @State private var confirm = ""

    init(store: any JournalStoring) {
        _model = State(initialValue: ExportModel(store: store))
    }

    /// Test/preview seam: inject a model with a small iteration count.
    init(model: ExportModel) {
        _model = State(initialValue: model)
    }

    private var passphrasesMatch: Bool {
        !passphrase.isEmpty && passphrase == confirm
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.block) {
                    Text(Copy.exportHint)
                        .font(.lamplight(.caption))
                        .foregroundStyle(Color.inwardSage)
                        .fixedSize(horizontal: false, vertical: true)

                    PaperCard {
                        VStack(alignment: .leading, spacing: Lamplight.Spacing.element) {
                            SecureField(Copy.exportPassphrasePrompt, text: $passphrase)
                            Divider().overlay(Color.inwardSage.opacity(0.3))
                            SecureField(Copy.exportPassphraseConfirm, text: $confirm)
                        }
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                    }

                    statusArea
                }
                .padding(Lamplight.Spacing.block)
            }
            .background(Color.inwardPaper.ignoresSafeArea())
            .navigationTitle(Copy.exportTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Copy.settingsDone) { dismiss() }
                        .font(.lamplight(.chrome))
                }
            }
        }
    }

    @ViewBuilder private var statusArea: some View {
        switch model.phase {
        case .idle, .failed:
            if case let .failed(message) = model.phase {
                Text(message)
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardClay)
            }
            exportButton
        case .working:
            HStack(spacing: Lamplight.Spacing.element) {
                ProgressView().tint(.inwardClay)
                Text(Copy.exportWorking)
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardSage)
            }
        case let .ready(url):
            VStack(alignment: .leading, spacing: Lamplight.Spacing.element) {
                Text(Copy.exportReady)
                    .font(.lamplight(.entryProse))
                    .foregroundStyle(Color.inwardInk)
                ShareLink(item: url) {
                    Text(Copy.exportShare)
                        .font(.lamplight(.chrome))
                        .foregroundStyle(Color.inwardPaper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Lamplight.Spacing.element)
                        .background(Capsule().fill(Color.inwardClay))
                }
            }
        }
    }

    private var exportButton: some View {
        Button {
            Task { await model.export(passphrase: passphrase) }
        } label: {
            Text(Copy.exportAction)
                .font(.lamplight(.chrome))
                .foregroundStyle(Color.inwardPaper)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Lamplight.Spacing.element)
                .background(Capsule().fill(passphrasesMatch ? Color.inwardClay : Color.inwardSage))
        }
        .buttonStyle(.plain)
        .disabled(!passphrasesMatch)
    }
}
