#if canImport(SwiftUI)
    import DesignSystem
    import SwiftUI

    /// The capture surface: one breathing record button, the live transcript in
    /// serif as it lands, then the read-it-back editor before keeping the entry.
    public struct CaptureView: View {
        @Bindable private var coordinator: CaptureCoordinator
        private let onFinished: () -> Void
        private let autoStart: Bool
        @State private var isPreparing = false

        public init(
            coordinator: CaptureCoordinator,
            autoStart: Bool = false,
            onFinished: @escaping () -> Void = {}
        ) {
            self.coordinator = coordinator
            self.autoStart = autoStart
            self.onFinished = onFinished
        }

        public var body: some View {
            VStack(spacing: Lamplight.Spacing.section) {
                content
            }
            .padding(Lamplight.Spacing.block)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.inwardPaper.ignoresSafeArea())
            .animation(.easeOut(duration: Lamplight.Motion.standard), value: coordinator.state)
            .task {
                // Quick-capture entry points (Siri, Back Tap, widget, …) open
                // straight into recording instead of waiting for a button tap.
                if autoStart, case .idle = coordinator.state {
                    await coordinator.startRecording()
                }
            }
        }

        @ViewBuilder private var content: some View {
            switch coordinator.state {
            case .idle:
                recordStage(isRecording: false, transcript: "")
            case let .recording(liveTranscript):
                recordStage(isRecording: true, transcript: liveTranscript)
            case let .reviewing(draft):
                TranscriptEditorView(
                    draft: draft,
                    onChange: { coordinator.updateDraft($0) },
                    onKeep: { Task { await coordinator.saveVoiceEntry() } },
                    onDiscard: {
                        coordinator.reset()
                        onFinished()
                    }
                )
            case .summarizing:
                thinkingStage(label: Copy.summarizingLabel)
            case let .confirming(_, summary):
                confirmStage(summary: summary)
            case let .clarifying(_, question):
                clarifyingStage(question: question)
            case .saving:
                ProgressView()
                    .tint(.inwardClay)
            case .saved:
                savedStage
            case .failed(.voiceNeedsPreparation):
                preparationStage
            case let .failed(failure):
                failureStage(failure)
            }
        }

        /// One-time, consented model download. The only place the app reaches the
        /// network — spelled out plainly — with text entry always one tap away.
        private var preparationStage: some View {
            VStack(spacing: Lamplight.Spacing.block) {
                Text(Copy.voicePrepareTitle)
                    .font(.lamplight(.chrome))
                    .foregroundStyle(Color.inwardInk)
                Text(isPreparing ? Copy.voicePreparing : Copy.voicePrepareBody)
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardSage)
                if isPreparing {
                    ProgressView().tint(.inwardClay)
                } else {
                    Button(Copy.voicePrepareAction) {
                        Task {
                            isPreparing = true
                            let ready = await coordinator.prepareVoice()
                            isPreparing = false
                            if ready { await coordinator.startRecording() }
                        }
                    }
                    .font(.lamplight(.chrome))
                    .foregroundStyle(Color.inwardClay)
                    Button(Copy.writeInstead) {
                        coordinator.reset()
                        onFinished()
                    }
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardSage)
                }
            }
            .multilineTextAlignment(.center)
        }

        private func recordStage(isRecording: Bool, transcript: String) -> some View {
            VStack(spacing: Lamplight.Spacing.section) {
                if isRecording {
                    Text(transcript.isEmpty ? Copy.listening : transcript)
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(transcript.isEmpty ? Color.inwardSage : Color.inwardInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
                RecordButton(isRecording: isRecording) {
                    Task {
                        if isRecording {
                            await coordinator.stopRecording()
                        } else {
                            await coordinator.startRecording()
                        }
                    }
                }
                Text(Copy.stillness)
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardSage)
            }
        }

        /// Transient spinner while the recap is formed and read aloud.
        private func thinkingStage(label: String) -> some View {
            VStack(spacing: Lamplight.Spacing.block) {
                ProgressView().tint(.inwardClay)
                Text(label)
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardSage)
            }
            .multilineTextAlignment(.center)
        }

        /// The recap, read back, with the three quiet choices: keep it, say more,
        /// or let it go. No editor here — editing stays in the read-it-back path.
        private func confirmStage(summary: String) -> some View {
            VStack(spacing: Lamplight.Spacing.section) {
                Text(summary)
                    .font(.lamplight(.entryProse))
                    .foregroundStyle(Color.inwardInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                VStack(spacing: Lamplight.Spacing.block) {
                    Button(Copy.confirmKeep) {
                        Task { await coordinator.confirmKeep() }
                    }
                    .font(.lamplight(.chrome))
                    .foregroundStyle(Color.inwardClay)
                    Button(Copy.confirmAddMore) {
                        Task { await coordinator.requestClarification() }
                    }
                    .font(.lamplight(.chrome))
                    .foregroundStyle(Color.inwardInk)
                    Button(Copy.discardEntry) {
                        coordinator.reset()
                        onFinished()
                    }
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardSage)
                }
            }
        }

        /// The spoken clarification question on screen while it's read aloud; the
        /// mic re-arms the moment it finishes, so no button is needed here.
        private func clarifyingStage(question: String) -> some View {
            VStack(spacing: Lamplight.Spacing.section) {
                Text(question)
                    .font(.lamplight(.entryProse))
                    .foregroundStyle(Color.inwardInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                ProgressView().tint(.inwardClay)
            }
        }

        private var savedStage: some View {
            VStack(spacing: Lamplight.Spacing.element) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.inwardSage)
            }
            .task {
                try? await Task.sleep(for: .milliseconds(450))
                coordinator.reset()
                onFinished()
            }
        }

        private func failureStage(_ failure: CaptureFailure) -> some View {
            VStack(spacing: Lamplight.Spacing.block) {
                Text(failureMessage(failure))
                    .font(.lamplight(.chrome))
                    .foregroundStyle(Color.inwardInk)
                    .multilineTextAlignment(.center)
                Button(Copy.discardEntry) {
                    coordinator.reset()
                    onFinished()
                }
                .font(.lamplight(.chrome))
                .foregroundStyle(Color.inwardClay)
            }
        }

        private func failureMessage(_ failure: CaptureFailure) -> String {
            switch failure {
            case .voiceUnavailable: Copy.voiceUnavailable
            // Handled by `preparationStage`, not this generic failure view.
            case .voiceNeedsPreparation: Copy.voicePrepareTitle
            case .captureFailed: Copy.captureFailed
            case .saveFailed: Copy.saveFailed
            }
        }
    }
#endif
