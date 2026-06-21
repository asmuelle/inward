import CaptureKit
import DesignSystem
import JournalStore
import PaywallKit
import PrivacyKit
import QuickCaptureKit
import ReflectKit
import SwiftUI

/// Home: the timeline of kept entries under warm paper, with the record button
/// as the strongest element. Composition only — the loop itself lives in CaptureKit.
struct RootView: View {
    private let store: any JournalStoring
    private let engine: (any TranscriptionEngine)?
    private let reviewProvider: any WeeklyReviewProviding

    @State private var model: TimelineModel
    @State private var lock: LockGateModel
    @State private var paywall: PaywallModel
    @State private var isCapturing = false
    @State private var isWriting = false
    @State private var isShowingSettings = false
    @State private var isShowingPaywall = false
    @State private var selection: DetailRoute?

    /// Quick-capture (Siri/Back Tap/widget/Control Center) signals through this
    /// shared object; `autoStartCapture` opens straight into recording, and a
    /// request that arrives while locked waits in `pendingQuickCapture`.
    private let quickCapture = QuickCaptureSignal.shared
    @State private var autoStartCapture = false
    @State private var pendingQuickCapture = false
    @State private var lastQuickCaptureToken = 0

    /// The most recently deleted entry, held for a few seconds so the undo
    /// snackbar can re-insert it. Hard delete otherwise — no tombstone.
    @State private var pendingUndo: DeletedSnapshot?

    @AppStorage(Prefs.hasOnboarded) private var hasOnboarded = false
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    init(
        store: any JournalStoring,
        engine: (any TranscriptionEngine)?,
        reviewProvider: any WeeklyReviewProviding,
        authenticator: any BiometricAuthenticating,
        purchaseGateway: any PurchaseGateway,
        trialStartedAt: Date
    ) {
        self.store = store
        self.engine = engine
        self.reviewProvider = reviewProvider
        _model = State(initialValue: TimelineModel(store: store))
        _lock = State(initialValue: LockGateModel(
            authenticator: authenticator,
            isEnabled: { UserDefaults.standard.bool(forKey: Prefs.lockEnabled) }
        ))
        _paywall = State(initialValue: PaywallModel(gateway: purchaseGateway, trialStartedAt: trialStartedAt))
    }

    /// New writing is gated when the trial lapses without a purchase; reading,
    /// weekly review, and export stay free (invariant #8).
    private func beginCapture(autoStart: Bool = false) {
        if paywall.isLocked {
            isShowingPaywall = true
        } else {
            autoStartCapture = autoStart
            isCapturing = true
        }
    }

    private func beginWriting() {
        if paywall.isLocked { isShowingPaywall = true } else { isWriting = true }
    }

    /// A quick-capture trigger fired. Begin recording now if unlocked; otherwise
    /// hold it until the lock opens, so a shortcut can never bypass the lock.
    private func handleQuickCapture(token: Int) {
        guard token != lastQuickCaptureToken, token > 0 else { return }
        lastQuickCaptureToken = token
        if lock.state == .locked {
            pendingQuickCapture = true
        } else {
            beginCapture(autoStart: true)
        }
    }

    /// Snapshots the entry (and its transcription) for undo, deletes it, closes
    /// the detail if it was open, and refreshes the timeline.
    private func deleteEntry(_ entry: Entry) {
        Task {
            let transcription = try? await store.transcription(entryID: entry.id)
            do {
                try await store.delete(entryID: entry.id)
                if case let .entry(selected) = selection, selected.id == entry.id {
                    selection = nil
                }
                pendingUndo = DeletedSnapshot(entry: entry, transcription: transcription)
                await model.refresh()
            } catch {
                // A failed delete leaves the entry in place; nothing to undo.
            }
        }
    }

    private func undoDelete() {
        guard let snapshot = pendingUndo else { return }
        pendingUndo = nil
        Task {
            try? await store.save(entry: snapshot.entry, transcription: snapshot.transcription)
            await model.refresh()
        }
    }

    var body: some View {
        adaptiveLayout
            .tint(.inwardClay)
            .overlay {
                if lock.state == .locked {
                    LockView { Task { await lock.attemptUnlock() } }
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: Lamplight.Motion.standard), value: lock.state)
            .inwardFullCover(isPresented: onboardingBinding) {
                OnboardingView { hasOnboarded = true }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(store: store)
            }
            .task {
                await lock.engage()
                if lock.state == .locked { await lock.attemptUnlock() }
            }
            .onChange(of: scenePhase) { _, phase in
                Task {
                    switch phase {
                    case .background:
                        await lock.engage()
                    case .active:
                        if lock.state == .locked { await lock.attemptUnlock() }
                    default:
                        break
                    }
                }
            }
            .task { await model.refresh() }
            .task { await paywall.refresh() }
            .task { await paywall.observeUpdates() }
            // Quick-capture: handle a request already pending at launch, react to
            // new ones, and release a lock-deferred one once the lock opens.
            .task { handleQuickCapture(token: quickCapture.requestToken) }
            .onChange(of: quickCapture.requestToken) { _, token in
                handleQuickCapture(token: token)
            }
            .onChange(of: lock.state) { _, state in
                if state != .locked, pendingQuickCapture {
                    pendingQuickCapture = false
                    beginCapture(autoStart: true)
                }
            }
            .sheet(isPresented: $isCapturing, onDismiss: { autoStartCapture = false; Task { await model.refresh() } }) {
                CaptureView(coordinator: makeCoordinator(), autoStart: autoStartCapture) {
                    isCapturing = false
                }
            }
            .sheet(isPresented: $isWriting, onDismiss: { Task { await model.refresh() } }) {
                WriteEntryView(coordinator: makeCoordinator()) {
                    isWriting = false
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(model: paywall)
            }
            .overlay(alignment: .bottom) {
                if let pendingUndo {
                    UndoDeleteBar(onUndo: undoDelete)
                        .id(pendingUndo.id)
                        .padding(.bottom, Lamplight.Spacing.stage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task {
                            // Auto-dismiss after the undo window; the delete then stands.
                            try? await Task.sleep(for: .seconds(5))
                            self.pendingUndo = nil
                        }
                }
            }
            .animation(.easeOut(duration: Lamplight.Motion.standard), value: pendingUndo?.id)
    }

    /// iPhone (compact) pushes the detail over the timeline; iPad and macOS keep
    /// the timeline beside the open entry in a split. The detail is itself a stack
    /// so an entry or the weekly review carries its own native title/back chrome.
    @ViewBuilder private var adaptiveLayout: some View {
        if useSplit {
            NavigationSplitView {
                sidebar
            } detail: {
                NavigationStack { detailPane }
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationStack {
                sidebar
                    .navigationDestination(item: $selection) { route in
                        routeView(route)
                    }
            }
        }
    }

    /// The timeline column: shared by both layouts as either the whole screen
    /// (iPhone) or the split's leading pane (iPad/macOS).
    private var sidebar: some View {
        ZStack(alignment: .bottom) {
            Color.inwardPaper.ignoresSafeArea()
            timeline
            captureBar
        }
        .navigationTitle(Copy.timelineTitle)
        .toolbar { rootToolbar }
    }

    @ToolbarContentBuilder private var rootToolbar: some ToolbarContent {
        ToolbarItem(placement: .inwardLeading) {
            Button { isShowingSettings = true } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(Copy.settingsTitle)
        }
        ToolbarItem(placement: .inwardTrailing) {
            Button(Copy.weeklyReviewLink) { selection = .weeklyReview }
                .font(.lamplight(.chrome))
                .disabled(model.entries.isEmpty)
        }
    }

    /// The split layout's detail pane: the chosen route, or a quiet prompt before
    /// anything is picked.
    @ViewBuilder private var detailPane: some View {
        if let selection {
            routeView(selection)
        } else {
            ZStack {
                Color.inwardPaper.ignoresSafeArea()
                Text(Copy.detailPlaceholder)
                    .font(.lamplight(.entryProse))
                    .foregroundStyle(Color.inwardSage)
                    .multilineTextAlignment(.center)
                    .padding(Lamplight.Spacing.stage)
            }
        }
    }

    @ViewBuilder private func routeView(_ route: DetailRoute) -> some View {
        switch route {
        case let .entry(entry):
            EntryDetailView(
                entry: entry,
                store: store,
                onEdited: { _ in Task { await model.refresh() } },
                onRequestDelete: { deleteEntry($0) }
            )
        case .weeklyReview:
            WeeklyReviewView(model: WeeklyReviewModel(store: store, provider: reviewProvider))
        }
    }

    /// Split on iPad/macOS, push on iPhone. macOS has no size class, so it always
    /// splits; iOS decides by width (compact iPhone vs regular iPad/landscape).
    private var useSplit: Bool {
        #if os(macOS)
            return true
        #else
            return horizontalSizeClass == .regular
        #endif
    }

    /// Presents onboarding until it's done; dismissing marks it complete.
    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !hasOnboarded },
            set: { presented in if !presented { hasOnboarded = true } }
        )
    }

    private var timeline: some View {
        VStack(spacing: 0) {
            if !model.tags.isEmpty {
                tagFilterBar
            }
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Lamplight.Spacing.block) {
                        ForEach(model.entries) { entry in
                            Button {
                                selection = .entry(entry)
                            } label: {
                                TimelineRow(entry: entry, isSelected: isSelectedEntry(entry))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(Copy.entryDelete, systemImage: "trash", role: .destructive) {
                                    deleteEntry(entry)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Lamplight.Spacing.block)
                    .padding(.top, Lamplight.Spacing.element)
                    .padding(.bottom, 160)
                }
            }
        }
    }

    /// Horizontal chips of the journal's tags; tap to filter the timeline, tap the
    /// active one again to clear.
    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Lamplight.Spacing.tight) {
                ForEach(model.tags) { tag in
                    let isActive = model.activeTag?.id == tag.id
                    Button {
                        Task { await model.setFilter(isActive ? nil : tag) }
                    } label: {
                        Text(tag.name)
                            .font(.lamplight(.caption))
                            .foregroundStyle(isActive ? Color.inwardPaper : Color.inwardInk)
                            .padding(.horizontal, Lamplight.Spacing.element)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(isActive ? Color.inwardClay : Color.inwardSage.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Lamplight.Spacing.block)
            .padding(.vertical, Lamplight.Spacing.tight)
        }
    }

    private var captureBar: some View {
        VStack(spacing: Lamplight.Spacing.tight) {
            RecordButton(isRecording: false) {
                beginCapture()
            }
            Button(Copy.writeInstead) {
                beginWriting()
            }
            .font(.lamplight(.caption))
            .foregroundStyle(Color.inwardSage)
        }
        .padding(.bottom, Lamplight.Spacing.block)
    }

    private func makeCoordinator() -> CaptureCoordinator {
        CaptureCoordinator(engine: engine, store: store)
    }

    /// Highlights the open entry in the split layout; never true on iPhone, where
    /// the pushed detail covers the timeline.
    private func isSelectedEntry(_ entry: Entry) -> Bool {
        if case let .entry(selected) = selection { return selected == entry }
        return false
    }
}

/// What the detail surface shows: a kept entry, or the weekly review. Drives both
/// the iPhone push (`navigationDestination(item:)`) and the iPad/macOS split detail.
private enum DetailRoute: Hashable {
    case entry(Entry)
    case weeklyReview
}

/// A just-deleted entry held for the undo window. Carries the transcription too,
/// so undo restores the entry exactly as it was.
private struct DeletedSnapshot: Identifiable {
    let id = UUID()
    let entry: Entry
    let transcription: Transcription?
}

/// The transient "Entry deleted · Undo" bar shown after a delete.
private struct UndoDeleteBar: View {
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Lamplight.Spacing.element) {
            Text(Copy.entryDeleted)
                .font(.lamplight(.chrome))
                .foregroundStyle(Color.inwardPaper)
            Spacer(minLength: Lamplight.Spacing.block)
            Button(Copy.entryDeleteUndo, action: onUndo)
                .font(.lamplight(.chrome))
                .foregroundStyle(Color.inwardPaper)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, Lamplight.Spacing.block)
        .padding(.vertical, Lamplight.Spacing.element)
        .background(Capsule().fill(Color.inwardInk))
        .padding(.horizontal, Lamplight.Spacing.block)
        .shadow(color: Color.inwardInk.opacity(0.2), radius: 12, y: 4)
    }
}

/// Loads and exposes the timeline. Read-only over the store.
@MainActor
@Observable
final class TimelineModel {
    private(set) var entries: [Entry] = []
    private(set) var tags: [Tag] = []
    private(set) var activeTag: Tag?
    private let store: any JournalStoring

    init(store: any JournalStoring) {
        self.store = store
    }

    func refresh() async {
        do {
            tags = try await store.allTags()
            // A filter whose tag was pruned away (last entry removed/retagged)
            // silently falls back to the full timeline.
            if let active = activeTag, !tags.contains(where: { $0.id == active.id }) {
                activeTag = nil
            }
            if let active = activeTag {
                entries = try await store.entries(withTag: active.name)
            } else {
                entries = try await store.allEntries()
            }
        } catch {
            // Reading must never crash the shell; an empty timeline with the
            // quiet empty-state line is the degraded surface.
            entries = []
            tags = []
        }
    }

    func setFilter(_ tag: Tag?) async {
        activeTag = tag
        await refresh()
    }
}
