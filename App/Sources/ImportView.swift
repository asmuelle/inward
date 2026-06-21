import DesignSystem
import Foundation
import JournalStore
import PrivacyKit
import SwiftUI
import UniformTypeIdentifiers

/// Restores an encrypted export produced on another device. The archive is
/// opened locally with the user's passphrase via the tested JournalExporter,
/// then merged additively: entries already present (by id) are left untouched,
/// so importing is safe to repeat and never overwrites local edits. Nothing is
/// transmitted — this is the receiving half of manual, device-to-device transfer.
@MainActor
@Observable
final class ImportModel {
    enum Phase: Equatable {
        case idle
        case working
        case done(added: Int)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private let store: any JournalStoring

    init(store: any JournalStoring) {
        self.store = store
    }

    func restore(from url: URL, passphrase: String) async {
        guard !passphrase.isEmpty else {
            phase = .failed(Copy.importPassphraseRequired)
            return
        }
        phase = .working
        do {
            let data = try readSecurityScoped(url)
            let payload = try JournalExporter.restore(from: data, passphrase: passphrase)
            phase = try await .done(added: merge(payload))
        } catch ExportError.wrongPassphraseOrCorrupt {
            phase = .failed(Copy.importWrongPassphrase)
        } catch {
            phase = .failed(Copy.importFailed)
        }
    }

    /// Applies the additive union-by-id policy (tested in PrivacyKit) and writes
    /// the new entries back, returning how many were added.
    private func merge(_ payload: ExportPayload) async throws -> Int {
        let existing = try await Set(store.allEntries().map(\.id))
        let additions = JournalImporter.additions(from: payload, existingIDs: existing)
        for addition in additions {
            try await store.save(entry: addition.entry, transcription: addition.transcription)
        }
        return additions.count
    }

    /// Files chosen through the picker live outside the sandbox; access must be
    /// claimed for the read and released after.
    private func readSecurityScoped(_ url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try Data(contentsOf: url)
    }
}

/// File pick + passphrase, then a merge that reports how many entries were added.
/// Importing is never paywalled — restoring your own words is always free
/// (invariant #8), mirroring export.
struct ImportView: View {
    @State private var model: ImportModel
    @Environment(\.dismiss) private var dismiss

    @State private var passphrase = ""
    @State private var pickedFile: URL?
    @State private var isChoosingFile = false

    init(store: any JournalStoring) {
        _model = State(initialValue: ImportModel(store: store))
    }

    /// Test/preview seam.
    init(model: ImportModel) {
        _model = State(initialValue: model)
    }

    private var canImport: Bool {
        pickedFile != nil && !passphrase.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.block) {
                    Text(Copy.importHint)
                        .font(.lamplight(.caption))
                        .foregroundStyle(Color.inwardSage)
                        .fixedSize(horizontal: false, vertical: true)

                    PaperCard {
                        VStack(alignment: .leading, spacing: Lamplight.Spacing.element) {
                            Button {
                                isChoosingFile = true
                            } label: {
                                Text(pickedFile?.lastPathComponent ?? Copy.importChooseFile)
                                    .font(.lamplight(.entryProse))
                                    .foregroundStyle(pickedFile == nil ? Color.inwardSage : Color.inwardInk)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(Color.inwardSage.opacity(0.3))
                            SecureField(Copy.importPassphrasePrompt, text: $passphrase)
                                .font(.lamplight(.entryProse))
                                .foregroundStyle(Color.inwardInk)
                        }
                    }

                    statusArea
                }
                .padding(Lamplight.Spacing.block)
            }
            .background(Color.inwardPaper.ignoresSafeArea())
            .navigationTitle(Copy.importTitle)
            .inwardInlineTitle()
            .toolbar {
                ToolbarItem(placement: .inwardTrailing) {
                    Button(Copy.settingsDone) { dismiss() }
                        .font(.lamplight(.chrome))
                }
            }
            .fileImporter(
                isPresented: $isChoosingFile,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                if case let .success(urls) = result, let url = urls.first {
                    pickedFile = url
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
            importButton
        case .working:
            HStack(spacing: Lamplight.Spacing.element) {
                ProgressView().tint(.inwardClay)
                Text(Copy.importWorking)
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardSage)
            }
        case let .done(added):
            Text(Copy.importDone(added: added))
                .font(.lamplight(.entryProse))
                .foregroundStyle(Color.inwardInk)
        }
    }

    private var importButton: some View {
        Button {
            guard let url = pickedFile else { return }
            Task { await model.restore(from: url, passphrase: passphrase) }
        } label: {
            Text(Copy.importAction)
                .font(.lamplight(.chrome))
                .foregroundStyle(Color.inwardPaper)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Lamplight.Spacing.element)
                .background(Capsule().fill(canImport ? Color.inwardClay : Color.inwardSage))
        }
        .buttonStyle(.plain)
        .disabled(!canImport)
    }
}
