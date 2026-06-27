#if (os(iOS) || os(macOS)) && canImport(AVFoundation)
    import AVFoundation
    import Foundation

    /// On-device text-to-speech via `AVSpeechSynthesizer`. Audio is synthesized
    /// locally and never leaves the device, so spoken summaries keep the
    /// airplane-mode promise. This type also owns the one tricky seam in the
    /// feature — the audio session must flip from the recorder's `.record`
    /// category to `.playback` before speaking — so the coordinator stays
    /// audio-agnostic and the only device-validated code lives here.
    @available(iOS 26.0, macOS 26.0, *)
    public actor AVSpeechSynthesisEngine: SpeechSynthesisEngine {
        private let synthesizer = AVSpeechSynthesizer()
        private let delegate = SpeechCompletionDelegate()

        public init() {
            synthesizer.delegate = delegate
        }

        public func availability() async -> SpeechSynthesisAvailability {
            // No installed voices means nothing can be spoken (rare, but possible
            // on a freshly provisioned device). Report unavailable so the loop
            // degrades to the silent editor rather than appearing to hang.
            AVSpeechSynthesisVoice.speechVoices().isEmpty
                ? .unavailable(reason: "no installed speech voices")
                : .available
        }

        public func speak(_ text: String, locale: String) async {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            configureSessionForPlayback()

            let utterance = AVSpeechUtterance(string: trimmed)
            utterance.voice = Self.voice(for: locale)

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                // didFinish and didCancel are mutually exclusive for one utterance;
                // clearing the handler before resuming guarantees a single resume
                // even if the framework were ever to call back twice.
                delegate.onCompletion = { [delegate] in
                    delegate.onCompletion = nil
                    continuation.resume()
                }
                synthesizer.speak(utterance)
            }
        }

        public func stop() async {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // MARK: - Internals

        /// Maps a `Locale.identifier` (`en_US`) to a BCP-47 voice (`en-US`),
        /// falling back to the system default voice when the language has none.
        private static func voice(for locale: String) -> AVSpeechSynthesisVoice? {
            let bcp47 = locale.replacingOccurrences(of: "_", with: "-")
            if let exact = AVSpeechSynthesisVoice(language: bcp47) {
                return exact
            }
            // Try the bare language code (en-US → en) before giving up to default.
            if let language = bcp47.split(separator: "-").first,
               let fallback = AVSpeechSynthesisVoice(language: String(language))
            {
                return fallback
            }
            return nil
        }

        private func configureSessionForPlayback() {
            #if os(iOS)
                // The recorder left the session in `.record`; spoken audio needs a
                // playback route. `.spokenAudio` mode is tuned for voice prompts,
                // and `.duckOthers` keeps any background audio quietly present.
                // The coordinator re-arms `.record` on the next recording, so this
                // engine only ever has to assert the playback side.
                let session = AVAudioSession.sharedInstance()
                try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                try? session.setActive(true, options: [])
            #endif
            // macOS has no AVAudioSession — AVSpeechSynthesizer routes to the
            // default output device directly, so there is nothing to configure.
        }
    }

    /// Bridges `AVSpeechSynthesizer`'s delegate callbacks to the async `speak`
    /// continuation. The framework invokes these on the main thread serially, and
    /// the handler is set/cleared around a single `speak` call, so the unchecked
    /// Sendable conformance is sound.
    @available(iOS 26.0, macOS 26.0, *)
    private final class SpeechCompletionDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
        var onCompletion: (@Sendable () -> Void)?

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            onCompletion?()
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            onCompletion?()
        }
    }
#endif
