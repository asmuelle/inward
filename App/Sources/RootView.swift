import CaptureKit
import DesignSystem
import JournalStore
import SwiftUI

/// Home: the timeline of kept entries under warm paper, with the record button
/// as the strongest element. Composition only — the loop itself lives in CaptureKit.
struct RootView: View {
    private let store: any JournalStoring
    private let engine: (any TranscriptionEngine)?

    @State private var model: TimelineModel
    @State private var isCapturing = false
    @State private var isWriting = false

    init(store: any JournalStoring, engine: (any TranscriptionEngine)?) {
        self.store = store
        self.engine = engine
        _model = State(initialValue: TimelineModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.inwardPaper.ignoresSafeArea()
                timeline
                captureBar
            }
            .navigationTitle(Copy.timelineTitle)
            .navigationDestination(for: Entry.self) { entry in
                EntryDetailView(entry: entry)
            }
        }
        .tint(.inwardClay)
        .task { await model.refresh() }
        .sheet(isPresented: $isCapturing, onDismiss: { Task { await model.refresh() } }) {
            CaptureView(coordinator: makeCoordinator()) {
                isCapturing = false
            }
        }
        .sheet(isPresented: $isWriting, onDismiss: { Task { await model.refresh() } }) {
            WriteEntryView(coordinator: makeCoordinator()) {
                isWriting = false
            }
        }
    }

    @ViewBuilder private var timeline: some View {
        if model.entries.isEmpty {
            VStack(spacing: Lamplight.Spacing.block) {
                Spacer()
                Text(Copy.timelineEmpty)
                    .font(.lamplight(.entryProse))
                    .foregroundStyle(Color.inwardSage)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Lamplight.Spacing.stage)
                Spacer()
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: Lamplight.Spacing.block) {
                    ForEach(model.entries) { entry in
                        NavigationLink(value: entry) {
                            TimelineRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Lamplight.Spacing.block)
                .padding(.top, Lamplight.Spacing.element)
                .padding(.bottom, 160)
            }
        }
    }

    private var captureBar: some View {
        VStack(spacing: Lamplight.Spacing.tight) {
            RecordButton(isRecording: false) {
                isCapturing = true
            }
            Button(Copy.writeInstead) {
                isWriting = true
            }
            .font(.lamplight(.caption))
            .foregroundStyle(Color.inwardSage)
        }
        .padding(.bottom, Lamplight.Spacing.block)
    }

    private func makeCoordinator() -> CaptureCoordinator {
        CaptureCoordinator(engine: engine, store: store)
    }
}

/// Loads and exposes the timeline. Read-only over the store.
@MainActor
@Observable
final class TimelineModel {
    private(set) var entries: [Entry] = []
    private let store: any JournalStoring

    init(store: any JournalStoring) {
        self.store = store
    }

    func refresh() async {
        do {
            entries = try await store.allEntries()
        } catch {
            // Reading must never crash the shell; an empty timeline with the
            // quiet empty-state line is the degraded surface.
            entries = []
        }
    }
}
