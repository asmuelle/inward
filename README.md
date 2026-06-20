# Inward

[![CI](https://github.com/asmuelle/inward/actions/workflows/ci.yml/badge.svg)](https://github.com/asmuelle/inward/actions/workflows/ci.yml)

> A voice-first journaling and CBT-reframing companion that is verifiably airplane-mode functional — spoken thoughts are transcribed, reflected, and stored only on the phone.

**Category:** Edge AI / on-device inference (iOS + Android) 
## Concept

A voice-first journaling and CBT-reframing companion that is verifiably airplane-mode functional — spoken thoughts are transcribed, reflected, and stored only on the phone.

## Target User 

Therapy-curious 25-45s paying for Mindsera/Stoic/Day One today, plus users who abandoned chatbot-therapy apps after Meta began ad-targeting on chatbot conversations; the Android flank, where no Stoic-equivalent exists, is explicitly included.

## Why Edge AI Is Structural (not decoration)

On-device Whisper-class ASR for voice entries; AFM 3 Core with Dynamic Profiles running listener, CBT-reframe (cognitive distortions via @Generable structured output), and weekly-review modes; Spotlight local RAG retrieves past entries for longitudinal patterns; a LoRA adapter trained on reflective-questioning style as an uncopyable differentiator. Android: Gemini Nano Summarization/Rewriting/Prompt APIs on flagships, Gemma 3n E2B via LiteRT-LM elsewhere. Structural: 11 US states regulate AI mental health, the FTC issued 6(b) orders, and Woebot exited consumer therapy over exactly this exposure — a cloud version is a regulatory target; the local version makes 'your thoughts never leave your phone' both compliance posture and the entire brand.

## Why Now (2026 timing)

The mental health app market compounds ~17% toward $45B while cloud incumbents retreat under regulation; AFM 3's 8K context plus the WWDC26 Spotlight RAG tool finally make on-device longitudinal journal analysis good enough, and nobody has shipped it on Android.


## Tech Stack

iOS (primary, iOS 26.4+): Swift/SwiftUI; SpeechAnalyzer + SpeechTranscriber for on-device ASR (whisper.cpp small as fallback for older devices); FoundationModels AFM 3 Core via LanguageModelSession with @Generable structured output for distortion-tagging and reflection prompts, using the new context-size/token-count APIs to chunk under the 8K window with hierarchical entry summaries; Core Spotlight + NLContextualEmbedding (or a small Core ML embedding model) + sqlite-vec for local RAG over past entries; GRDB/SwiftData with SQLCipher and NSFileProtectionComplete; skip the custom LoRA adapter at launch (version-lock retraining tax) in favor of a prompt-engineered persona with few-shot exemplars; client-side-encrypted export to Files/iCloud Drive. Android (downscoped, flagships first): Kotlin/Jetpack Compose; ML Kit GenAI Summarization + Rewriting APIs on the AICore-supported device list, Prompt API only for short single-entry reflections (respect 4K-in/255-out limits); Gemma 3n E2B-it int4 via LiteRT-LM / MediaPipe LLM Inference as an opt-in download for non-AICore devices; on-device SpeechRecognizer or whisper.cpp for ASR; Room + SQLCipher; EmbeddingGemma-class embeddings via LiteRT + sqlite-vec for local retrieval. Both platforms: no analytics SDKs, no network calls in the journaling path (verifiable via iOS App Privacy Report), reframe all copy as wellness/reflective journaling — no CBT/therapy claims — with static (non-AI) crisis-resource surfacing on keyword match.
