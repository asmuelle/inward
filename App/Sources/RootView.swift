import CaptureKit
import DesignSystem
import JournalStore
import PaywallKit
import PrivacyKit
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
    private func beginCapture() {
        if paywall.isLocked { isShowingPaywall = true } else { isCapturing = true }
    }

    private func beginWriting() {
        if paywall.isLocked { isShowingPaywall = true } else { isWriting = true }
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
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(model: paywall)
            }
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
            EntryDetailView(entry: entry)
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
                        Button {
                            selection = .entry(entry)
                        } label: {
                            TimelineRow(entry: entry, isSelected: isSelectedEntry(entry))
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
