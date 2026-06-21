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

            // SpeechAnalyzer requires audio in its own format; handing it raw mic
            // buffers traps inside the framework (preRunRecognition). Resolve the
            // format it wants and convert every buffer to it before delivery.
            guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                throw TranscriptionError.audioSetupFailed("no compatible on-device audio format")
            }

            let (inputStream, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
            self.inputContinuation = inputContinuation

            let (outputStream, outputContinuation) = AsyncThrowingStream<TranscriptSegment, Error>.makeStream()
            self.outputContinuation = outputContinuation

            try configureAudioSession()
            try await installTap(continuation: inputContinuation, analyzerFormat: analyzerFormat)
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
            analyzerFormat: AVAudioFormat
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
            let converter = BufferConverter(to: analyzerFormat)
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buffer, _ in
                guard let converted = try? converter.convert(buffer) else { return }
                continuation.yield(AnalyzerInput(buffer: converted))
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

    /// Resamples microphone buffers into the analyzer's required format.
    /// SpeechAnalyzer traps on mismatched input, so every buffer is converted to
    /// `targetFormat` before delivery. The tap calls this serially on the audio
    /// thread, so the cached converter needs no extra locking — hence the
    /// justified `@unchecked Sendable`.
    @available(iOS 26.0, macOS 26.0, *)
    private final class BufferConverter: @unchecked Sendable {
        private let targetFormat: AVAudioFormat
        private var converter: AVAudioConverter?
        /// The buffer the converter's pull block should hand back next. The block
        /// runs synchronously inside `convert(to:error:withInputFrom:)`, so keeping
        /// this as instance state (rather than a captured local) is safe and keeps
        /// the block's only capture `self`.
        private var pendingBuffer: AVAudioPCMBuffer?

        init(to targetFormat: AVAudioFormat) {
            self.targetFormat = targetFormat
        }

        func convert(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
            let inputFormat = buffer.format
            guard inputFormat != targetFormat else { return buffer }

            if converter == nil || converter?.inputFormat != inputFormat {
                converter = AVAudioConverter(from: inputFormat, to: targetFormat)
                converter?.primeMethod = .none
            }
            guard let converter else {
                throw TranscriptionError.audioSetupFailed("could not create audio converter")
            }

            let ratio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
            let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
            guard capacity > 0,
                  let output = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity)
            else {
                throw TranscriptionError.audioSetupFailed("could not allocate conversion buffer")
            }

            pendingBuffer = buffer
            var nsError: NSError?
            let status = converter.convert(to: output, error: &nsError) { [self] _, inputStatus in
                if let next = pendingBuffer {
                    pendingBuffer = nil
                    inputStatus.pointee = .haveData
                    return next
                }
                inputStatus.pointee = .noDataNow
                return nil
            }
            if status == .error {
                throw TranscriptionError.audioSetupFailed(nsError?.localizedDescription ?? "audio conversion failed")
            }
            return output
        }
    }
#endif
