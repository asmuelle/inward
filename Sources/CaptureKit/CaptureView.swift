#if canImport(SwiftUI)
    import DesignSystem
    import SwiftUI

    /// The capture surface: one breathing record button, the live transcript in
    /// serif as it lands, then the read-it-back editor before keeping the entry.
    public struct CaptureView: View {
        @Bindable private var coordinator: CaptureCoordinator
        private let onFinished: () -> Void
        private let autoStart: Bool

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
            case .saving:
                ProgressView()
                    .tint(.inwardClay)
            case .saved:
                savedStage
            case let .failed(failure):
                failureStage(failure)
            }
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
            case .captureFailed: Copy.captureFailed
            case .saveFailed: Copy.saveFailed
            }
        }
    }
#endif
