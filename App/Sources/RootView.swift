import CaptureKit
import DesignSystem
import JournalStore
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
    @State private var isCapturing = false
    @State private var isWriting = false
    @State private var isShowingSettings = false

    @AppStorage(Prefs.hasOnboarded) private var hasOnboarded = false
    @Environment(\.scenePhase) private var scenePhase

    init(
        store: any JournalStoring,
        engine: (any TranscriptionEngine)?,
        reviewProvider: any WeeklyReviewProviding,
        authenticator: any BiometricAuthenticating
    ) {
        self.store = store
        self.engine = engine
        self.reviewProvider = reviewProvider
        _model = State(initialValue: TimelineModel(store: store))
        _lock = State(initialValue: LockGateModel(
            authenticator: authenticator,
            isEnabled: { UserDefaults.standard.bool(forKey: Prefs.lockEnabled) }
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.inwardPaper.ignoresSafeArea()
                timeline
                captureBar
            }
            .navigationTitle(Copy.timelineTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { isShowingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(Copy.settingsTitle)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: WeeklyReviewRoute()) {
                        Text(Copy.weeklyReviewLink)
                    }
                    .font(.lamplight(.chrome))
                    .disabled(model.entries.isEmpty)
                }
            }
            .navigationDestination(for: Entry.self) { entry in
                EntryDetailView(entry: entry)
            }
            .navigationDestination(for: WeeklyReviewRoute.self) { _ in
                WeeklyReviewView(model: WeeklyReviewModel(store: store, provider: reviewProvider))
            }
        }
        .tint(.inwardClay)
        .overlay {
            if lock.state == .locked {
                LockView { Task { await lock.attemptUnlock() } }
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: Lamplight.Motion.standard), value: lock.state)
        .fullScreenCover(isPresented: onboardingBinding) {
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
