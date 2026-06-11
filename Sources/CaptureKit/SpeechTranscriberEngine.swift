#if os(iOS) && canImport(Speech) && canImport(AVFoundation)
    import AVFoundation
    import Foundation
    import Speech

    /// On-device ASR via the iOS 26 SpeechAnalyzer/SpeechTranscriber pipeline.
    /// Audio never leaves the device. Any setup failure degrades to text entry —
    /// voice is an enhancement, never a requirement.
    @available(iOS 26.0, *)
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
            let locale = Locale.current
            let supported = await SpeechTranscriber.supportedLocales
            guard supported.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else {
                return .unavailable(reason: "locale not supported for on-device transcription")
            }
            let granted = await AVAudioApplication.requestRecordPermission()
            guard granted else {
                return .unavailable(reason: "microphone permission not granted")
            }
            return .available
        }

        public func start() async throws -> AsyncThrowingStream<TranscriptSegment, Error> {
            let transcriber = SpeechTranscriber(
                locale: Locale.current,
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
            try installTap(continuation: inputContinuation, transcriber: transcriber)
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
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                throw TranscriptionError.audioSetupFailed(error.localizedDescription)
            }
        }

        private func installTap(
            continuation: AsyncStream<AnalyzerInput>.Continuation,
            transcriber: SpeechTranscriber
        ) throws {
            let inputNode = audioEngine.inputNode
            let tapFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buffer, _ in
                continuation.yield(AnalyzerInput(buffer: buffer))
            }
            audioEngine.prepare()
            do {
                try audioEngine.start()
            } catch {
                inputNode.removeTap(onBus: 0)
                throw TranscriptionError.audioSetupFailed(error.localizedDescription)
            }
        }
    }
#endif
