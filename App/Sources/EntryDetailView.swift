import DesignSystem
import JournalStore
import SwiftUI

/// Reopen and read a kept entry — always available, never paywalled. Supports
/// post-hoc editing (the raw transcript stays untouched as provenance) and
/// deletion (the actual delete + undo is owned by the root, via `onRequestDelete`).
struct EntryDetailView: View {
    @State private var entry: Entry
    private let store: (any JournalStoring)?
    private let onEdited: (Entry) -> Void
    private let onRequestDelete: (Entry) -> Void

    @State private var isEditing = false
    @State private var draft = ""
    @State private var confirmingDelete = false

    init(
        entry: Entry,
        store: (any JournalStoring)? = nil,
        onEdited: @escaping (Entry) -> Void = { _ in },
        onRequestDelete: @escaping (Entry) -> Void = { _ in }
    ) {
        _entry = State(initialValue: entry)
        self.store = store
        self.onEdited = onEdited
        self.onRequestDelete = onRequestDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.block) {
                metadata
                if isEditing {
                    editor
                } else {
                    Text(entry.textEdited)
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                        .lineSpacing(Lamplight.TypeRole.entryProse
                            .pointSize * (Lamplight.TypeRole.entryProse.lineSpacingMultiplier - 1))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Lamplight.Spacing.block)
        }
        .background(Color.inwardPaper.ignoresSafeArea())
        .inwardInlineTitle()
        .toolbar {
            if store != nil, !isEditing {
                ToolbarItem(placement: .inwardTrailing) {
                    Menu {
                        Button(Copy.entryEdit, systemImage: "pencil") {
                            draft = entry.textEdited
                            isEditing = true
                        }
                        Button(Copy.entryDelete, systemImage: "trash", role: .destructive) {
                            confirmingDelete = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .font(.lamplight(.chrome))
                }
            }
        }
        .confirmationDialog(
            Copy.entryDeleteConfirmTitle,
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button(Copy.entryDeleteConfirmAction, role: .destructive) { onRequestDelete(entry) }
            Button(Copy.entryEditCancel, role: .cancel) {}
        }
    }

    private var metadata: some View {
        HStack(spacing: Lamplight.Spacing.tight) {
            Text(entry.createdAt, format: .dateTime.weekday(.wide).day().month().year())
            Text("·")
            Text(entry.source == .voice ? Copy.spokenLabel : Copy.writtenLabel)
            if entry.updatedAt > entry.createdAt {
                Text("·")
                Text(Copy.entryEditedMarker)
            }
        }
        .font(.lamplight(.caption))
        .foregroundStyle(Color.inwardSage)
    }

    @ViewBuilder private var editor: some View {
        TextEditor(text: $draft)
            .font(.lamplight(.entryProse))
            .foregroundStyle(Color.inwardInk)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 220)
            .padding(Lamplight.Spacing.element)
            .background(
                RoundedRectangle(cornerRadius: Lamplight.Surface.cardRadius, style: .continuous)
                    .stroke(Color.inwardSage.opacity(0.4), lineWidth: 1)
            )

        HStack {
            Button(Copy.entryEditCancel) { isEditing = false }
                .foregroundStyle(Color.inwardSage)
            Spacer()
            Button(Copy.entryEditSave) { save() }
                .foregroundStyle(Color.inwardClay)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .font(.lamplight(.chrome))
    }

    private func save() {
        guard let store else { return }
        let text = draft
        Task {
            if let updated = try? await store.updateEditedText(entryID: entry.id, textEdited: text) {
                entry = updated
                onEdited(updated)
            }
            isEditing = false
        }
    }
}
