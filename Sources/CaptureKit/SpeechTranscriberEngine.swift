#if (os(iOS) || os(macOS)) && canImport(Speech) && canImport(AVFoundation)
    import AVFoundation
    import Foundation
    import Speech

    /// On-device ASR via the iOS 26 / macOS 26 SpeechAnalyzer/SpeechTranscriber
    /// pipeline. Audio never leaves the device. Any setup failure degrades to text
    /// entry — voice is an enhancement, never a requirement. The capture core
    /// (AVAudioEngine + SpeechAnalyzer) is shared; only microphone permission and
    /// audio-session setup differ by platform.
    @available(iOS 26.0, macOS 26.0, *)
    public actor SpeechTranscriberEngine: TranscriptionEngine {
        public nonisolated let engineKind: TranscriptionEngineKind = .speechTranscriber

        private let audioEngine = AVAudioEngine()
        private var analyzer: SpeechAnalyzer?
        private var transcriber: SpeechTranscriber?
        private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
        private var resultTask: Task<Void, Never>?
        private var outputContinuation: AsyncThrowingStream<TranscriptSegment, Error>.Continuation?

        public init() {}

        public func availability() async -> TranscriptionAvailability {
            let supported = await SpeechTranscriber.supportedLocales
            guard TranscriptionLocale.bestMatch(for: .current, among: supported) != nil else {
                return .unavailable(reason: "locale not supported for on-device transcription")
            }
            let granted = await Self.requestMicrophoneAccess()
            guard granted else {
                return .unavailable(reason: "microphone permission not granted")
            }
            return .available
        }

        /// Microphone authorization differs by platform: iOS gates through
        /// AVAudioApplication, macOS through AVCaptureDevice. Both surface the
        /// shared NSMicrophoneUsageDescription and resolve to a simple Bool.
        private static func requestMicrophoneAccess() async -> Bool {
            #if os(iOS)
                return await AVAudioApplication.requestRecordPermission()
            #else
                return await AVCaptureDevice.requestAccess(for: .audio)
            #endif
        }

        public func start() async throws -> AsyncThrowingStream<TranscriptSegment, Error> {
            // Use a locale the model actually supports — Locale.current may be a
            // region the transcriber doesn't enumerate (e.g. en-DE), which would
            // otherwise fail at install/recognition time.
            let supported = await SpeechTranscriber.supportedLocales
            let locale = TranscriptionLocale.bestMatch(for: .current, among: supported) ?? Locale.current
            let transcriber = SpeechTranscriber(
                locale: locale,
                transcriptionOptions: [],
                reportingOptions: [.volatileResults],
                attributeOptions: []
            )
            self.transcriber = transcriber

            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }

            let analyzer = SpeechAnalyzer(modules: [transcriber])
            self.analyzer = analyzer

            let (inputStream, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
            self.inputContinuation = inputContinuation

            let (outputStream, outputContinuation) = AsyncThrowingStream<TranscriptSegment, Error>.makeStream()
            self.outputContinuation = outputContinuation

            try configureAudioSession()
            try await installTap(continuation: inputContinuation, transcriber: transcriber)
            try await analyzer.start(inputSequence: inputStream)

            resultTask = Task { [weak self] in
                await self?.pumpResults(from: transcriber, into: outputContinuation)
            }
            return outputStream
        }

        public func stop() async {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            inputContinuation?.finish()
            inputContinuation = nil
            try? await analyzer?.finalizeAndFinishThroughEndOfInput()
            await resultTask?.value
            resultTask = nil
            outputContinuation?.finish()
            outputContinuation = nil
            analyzer = nil
            transcriber = nil
        }

        // MARK: - Internals

        private func pumpResults(
            from transcriber: SpeechTranscriber,
            into continuation: AsyncThrowingStream<TranscriptSegment, Error>.Continuation
        ) async {
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    continuation.yield(TranscriptSegment(text: text, isFinal: result.isFinal, confidence: 1.0))
                }
            } catch {
                continuation.finish(throwing: TranscriptionError.engineFailed(error.localizedDescription))
            }
        }

        private func configureAudioSession() throws {
            #if os(iOS)
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
                    try session.setActive(true, options: .notifyOthersOnDeactivation)
                } catch {
                    throw TranscriptionError.audioSetupFailed(error.localizedDescription)
                }
            #endif
            // macOS has no AVAudioSession: AVAudioEngine reads the system default
            // input device directly, so there is nothing to configure here.
        }

        /// Maximum waits for the input device format to become valid after a
        /// microphone grant, at `tapReadyPollInterval` apart.
        private static let tapReadyAttempts = 8
        private static let tapReadyPollInterval = Duration.milliseconds(120)

        private func installTap(
            continuation: AsyncStream<AnalyzerInput>.Continuation,
            transcriber: SpeechTranscriber
        ) async throws {
            let inputNode = audioEngine.inputNode
            // Engage the input node before reading its format. Right after a
            // microphone grant — especially on macOS — the device format is
            // briefly 0ch/0Hz until the audio HAL exposes it to the now-authorized
            // process; prepare() nudges that along, then we poll until it's ready.
            audioEngine.prepare()
            var tapFormat = inputNode.outputFormat(forBus: 0)
            var attempt = 0
            while !Self.isValid(tapFormat), attempt < Self.tapReadyAttempts {
                try? await Task.sleep(for: Self.tapReadyPollInterval)
                tapFormat = inputNode.outputFormat(forBus: 0)
                attempt += 1
            }
            // installTap validates the format and throws an Obj-C exception on an
            // invalid one, which Swift can't catch — it would abort the process.
            // Fail into the text path instead (invariant #9) if it never settles.
            guard Self.isValid(tapFormat) else {
                throw TranscriptionError.audioSetupFailed("microphone input is not ready")
            }
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buffer, _ in
                continuation.yield(AnalyzerInput(buffer: buffer))
            }
            do {
                try audioEngine.start()
            } catch {
                inputNode.removeTap(onBus: 0)
                throw TranscriptionError.audioSetupFailed(error.localizedDescription)
            }
        }

        private static func isValid(_ format: AVAudioFormat) -> Bool {
            format.channelCount > 0 && format.sampleRate > 0
        }
    }
#endif
