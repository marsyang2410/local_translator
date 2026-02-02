import SwiftUI
import AVFoundation
import Translation // <--- CRITICAL IMPORT

struct ContentView: View {
    @StateObject var whisperState = WhisperState()
    @State private var showModels = false
    
    // Language selections
    @State private var topLanguage = "es" // Person A (e.g. Spanish)
    @State private var bottomLanguage = "en" // Person B (e.g. English)
    
    // Mode selection
    @State private var isSoloMode = false // true = Solo mode (normal orientation), false = Duo mode (face-to-face)
    
    // Interaction state
    @State private var isRecordingTop = false
    @State private var isRecordingBottom = false
    
    // UI Colors (Dynamic)
    @State private var topColor: Color = .orange
    @State private var bottomColor: Color = .blue
    
    // Translation Logic State
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var isTopSpeech = false // Track who spoke for the translation task
    
    // Track unique translations to force the task to refresh
    @State private var translationID = UUID()
    
    let languages = [
        ("English", "en"),
        ("Spanish", "es"),
        ("French", "fr"),
        ("German", "de"),
        ("Chinese", "zh"),
        ("Japanese", "ja"),
        ("Portuguese", "pt"),
        ("Italian", "it")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Top Section (Person A)
                ZStack {
                    topColor.opacity(0.1).edgesIgnoringSafeArea(.top)
                    
                    VStack(spacing: 20) {
                        // Language Picker (Rotated for Face-to-Face)
                        Picker("Language", selection: $topLanguage) {
                            ForEach(languages, id: \.1) { name, code in
                                Text(name).tag(code)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .rotationEffect(.degrees(isSoloMode ? 0 : 180))
                        
                        // Action Controls (Rotated)
                        PersonControls(
                            isRecording: isRecordingTop,
                            isPaused: whisperState.isPaused,
                            color: topColor,
                            languageName: languageName(for: topLanguage),
                            onStart: {
                                isRecordingTop = true
                                isTopSpeech = true
                                Task { await whisperState.startRecording(source: topLanguage, target: bottomLanguage) }
                            },
                            onStop: {
                                isRecordingTop = false
                                Task { await whisperState.stopRecording() }
                            },
                            onPause: {
                                Task { await whisperState.pauseRecording() }
                            },
                            onResume: {
                                Task { await whisperState.resumeRecording() }
                            },
                            onCancel: {
                                isRecordingTop = false
                                Task { await whisperState.cancelRecording() }
                            }
                        )
                        .rotationEffect(.degrees(isSoloMode ? 0 : 180))
                        
                        // Result Display (Rotated)
                        // Shows what Bottom person said (translated to Top language)
                        // Result Display (Rotated)
                        // Shows what Bottom person said (translated to Top language)
                        // Result Display (Rotated)
                        // Shows what was said on this side (Transcription if A spoke, Translation if B spoke)
                        let topOutput = isTopSpeech ? whisperState.transcribedText : whisperState.translatedText
                        
                        if !topOutput.isEmpty && !isRecordingBottom {
                             HStack {
                                 // 1. TTS Button (Pronunciation)
                                 Button(action: { whisperState.speak(text: topOutput, language: topLanguage) }) {
                                     Image(systemName: whisperState.isPlayingTTS ? "stop.circle.fill" : "speaker.wave.2.circle.fill")
                                         .font(.title)
                                         .foregroundColor(topColor)
                                 }
                                 .padding(.trailing, 8)
                                 
                                 // 2. User Recording Button (Original Voice)
                                 Button(action: { whisperState.playLastRecording() }) {
                                     Image(systemName: whisperState.isPlayingAudio ? "stop.circle.fill" : "waveform.circle.fill")
                                         .font(.title)
                                         .foregroundColor(isTopSpeech ? topColor : .gray)
                                 }
                                 .disabled(!isTopSpeech)
                                 
                                 Text(topOutput)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(topColor)
                                    .padding()
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(12)
                             }
                             .rotationEffect(.degrees(isSoloMode ? 0 : 180))
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: .infinity)
                
                // MARK: - Center Controls
                HStack {
                    if !whisperState.canTranscribe {
                        Text("Loading Model...")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Button(action: {
                            // Swap Languages
                            let tempLang = topLanguage
                            topLanguage = bottomLanguage
                            bottomLanguage = tempLang
                            
                            // Swap Colors
                            let tempColor = topColor
                            topColor = bottomColor
                            bottomColor = tempColor
                            
                            // Swap Message Content
                            let tempText = whisperState.transcribedText
                            whisperState.transcribedText = whisperState.translatedText
                            whisperState.translatedText = tempText
                        }) {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    // Solo/Duo Mode Toggle
                    Button(action: {
                        withAnimation {
                            isSoloMode.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isSoloMode ? "person.fill" : "person.2.fill")
                            Text(isSoloMode ? "Solo" : "Duo")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(isSoloMode ? .green : .purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSoloMode ? Color.green.opacity(0.1) : Color.purple.opacity(0.1))
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    Button(action: { showModels = true }) {
                        Image(systemName: "gear")
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                
                // MARK: - Bottom Section (Person B)
                ZStack {
                    bottomColor.opacity(0.1).edgesIgnoringSafeArea(.bottom)
                    
                    VStack(spacing: 20) {
                        // Result Display
                        // Shows what was said on this side (Transcription if B spoke, Translation if A spoke)
                        let bottomOutput = isTopSpeech ? whisperState.translatedText : whisperState.transcribedText
                        
                        if !bottomOutput.isEmpty && !isRecordingTop {
                             HStack {
                                 Text(bottomOutput)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(bottomColor)
                                    .padding()
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(12)
                                 
                                 // 1. User Recording Button (Original Voice)
                                 Button(action: { whisperState.playLastRecording() }) {
                                     Image(systemName: whisperState.isPlayingAudio ? "stop.circle.fill" : "waveform.circle.fill")
                                         .font(.title)
                                         .foregroundColor(!isTopSpeech ? bottomColor : .gray)
                                 }
                                 .disabled(isTopSpeech)
                                 .padding(.trailing, 8)

                                 // 2. TTS Button (Pronunciation)
                                 Button(action: { whisperState.speak(text: bottomOutput, language: bottomLanguage) }) {
                                     Image(systemName: whisperState.isPlayingTTS ? "stop.circle.fill" : "speaker.wave.2.circle.fill")
                                         .font(.title)
                                         .foregroundColor(bottomColor)
                                 }
                             }
                        }
                        
                        Spacer()
                        
                        // Action Controls
                        PersonControls(
                            isRecording: isRecordingBottom,
                            isPaused: whisperState.isPaused,
                            color: bottomColor,
                            languageName: languageName(for: bottomLanguage),
                            onStart: {
                                isRecordingBottom = true
                                isTopSpeech = false
                                Task { await whisperState.startRecording(source: bottomLanguage, target: topLanguage) }
                            },
                            onStop: {
                                isRecordingBottom = false
                                Task { await whisperState.stopRecording() }
                            },
                            onPause: {
                                Task { await whisperState.pauseRecording() }
                            },
                            onResume: {
                                Task { await whisperState.resumeRecording() }
                            },
                            onCancel: {
                                isRecordingBottom = false
                                Task { await whisperState.cancelRecording() }
                            }
                        )
                        
                        // Language Picker
                        Picker("Language", selection: $bottomLanguage) {
                            ForEach(languages, id: \.1) { name, code in
                                Text(name).tag(code)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    .padding()
                }
                .frame(maxHeight: .infinity)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showModels) {
                SettingsView(whisperState: whisperState)
            }
            // MARK: - Translation Logic
            // When transcription completes, translate using stored session OR trigger a new one
            .onChange(of: whisperState.transcribedText) { newText in
                guard !newText.isEmpty else { return }
                
                let source = isTopSpeech ? topLanguage : bottomLanguage
                let target = isTopSpeech ? bottomLanguage : topLanguage
                
                // Update target language state
                whisperState.currentTargetLanguage = target
                
                // Skip if same language
                guard source != target else {
                    whisperState.translatedText = newText
                    whisperState.speak(text: newText, language: target)
                    return
                }
                
                // If config is already set to this target, we reuse the session manually
                if let currentConfig = translationConfig, 
                   currentConfig.target == Locale.Language(identifier: target) {
                    Task {
                        await whisperState.translateCurrentText()
                    }
                } else {
                    // Change config to trigger a new session via .translationTask
                    translationConfig = TranslationSession.Configuration(
                        source: nil,
                        target: Locale.Language(identifier: target)
                    )
                }
            }
            // This captures the session and performs the translation
            .translationTask(translationConfig) { session in
                // Store session reference for next time
                whisperState.translationSession = session
                
                // Perform the translation for the current text
                await whisperState.translateWithSession(session)
            }
        }

        .onAppear {
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { _ in }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { _ in }
            }
        }
    }

    private func languageName(for code: String) -> String {
        languages.first { $0.1 == code }?.0 ?? code
    }
}

// MARK: - New Control Components

struct PersonControls: View {
    var isRecording: Bool
    var isPaused: Bool
    var color: Color
    var languageName: String
    
    var onStart: () -> Void
    var onStop: () -> Void
    var onPause: () -> Void
    var onResume: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            if isRecording {
                HStack(spacing: 30) {
                    // Cancel Button
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                    }
                    
                    // Stop/Finish Button
                    Button(action: onStop) {
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 80, height: 80)
                            Image(systemName: "stop.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    .shadow(radius: 5)
                    
                    // Pause/Resume Button
                    Button(action: isPaused ? onResume : onPause) {
                        Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(color)
                    }
                }
                .transition(.scale.combined(with: .opacity))
                
                Text(isPaused ? "Paused" : "Listening for \(languageName)...")
                    .font(.subheadline)
                    .foregroundColor(color)
                    .italic()
            } else {
                // Initial Record Button
                Button(action: onStart) {
                    VStack {
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 80, height: 80)
                            Image(systemName: "mic.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        .shadow(radius: 5)
                        
                        Text("Tap to Speak \(languageName)")
                            .font(.headline)
                            .foregroundColor(color)
                            .padding(.top, 5)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(), value: isRecording)
        .animation(.spring(), value: isPaused)
    }
}

struct SettingsView: View {
    @ObservedObject var whisperState: WhisperState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Model Management")) {
                    NavigationLink(destination: ModelsView(whisperState: whisperState)) {
                        Label("Whisper Models (STT)", systemImage: "waveform")
                    }
                    
                    NavigationLink(destination: LanguageSettingsView(whisperState: whisperState)) {
                        Label("Translation Languages", systemImage: "translate")
                    }
                    
                    NavigationLink(destination: VoiceSettingsView(whisperState: whisperState)) {
                        Label("Text-to-Speech Voices", systemImage: "speaker.wave.2")
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct VoiceSettingsView: View {
    @ObservedObject var whisperState: WhisperState
    @State private var voices: [String: [AVSpeechSynthesisVoice]] = [:]
    @State private var playingVoiceId: String?
    private let synthesizer = AVSpeechSynthesizer()
    
    // Map language codes to sample text
    private let sampleTexts: [String: String] = [
        "en": "Hello, how are you today?",
        "es": "Hola, ¿cómo estás hoy?",
        "fr": "Bonjour, comment allez-vous?",
        "de": "Hallo, wie geht es dir?",
        "zh": "你好，你今天好吗？",
        "ja": "こんにちは、お元気ですか？",
        "it": "Ciao, come stai oggi?",
        "pt": "Olá, como você está hoje?"
    ]
    
    // We'll filter for the languages we support in the app
    private let supportedLanguageCodes = ["en", "es", "fr", "de", "zh", "ja", "it", "pt"]
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Improve Voice Quality")
                            .font(.headline)
                    }
                    Text("Tap ▶️ to preview voices. Select Premium/Enhanced for more natural sound. To add more voices, go to iOS Settings → Accessibility → Spoken Content → Voices.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            ForEach(supportedLanguageCodes, id: \.self) { langCode in
                Section(header: Text(languageName(for: langCode))) {
                    if let languageVoices = voices[langCode], !languageVoices.isEmpty {
                        ForEach(languageVoices, id: \.identifier) { voice in
                            VoiceRow(
                                voice: voice,
                                langCode: langCode,
                                isSelected: whisperState.getVoiceHeight(for: langCode) == voice.identifier,
                                isPlaying: playingVoiceId == voice.identifier,
                                onSelect: {
                                    whisperState.setVoice(voice.identifier, for: langCode)
                                },
                                onPreview: {
                                    playingVoiceId = voice.identifier
                                    playSample(voice: voice, langCode: langCode)
                                }
                            )
                        }
                    } else {
                        Text("No voices available for this language")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            
            Section(footer: VStack(alignment: .leading, spacing: 12) {
                Text("💡 To download more high-quality voices:")
                    .font(.footnote)
                    .fontWeight(.semibold)
                Text("1. Open iOS Settings\n2. Go to Accessibility > Spoken Content (or 'Speak Selection')\n3. Tap 'Voices'\n4. Select a language (e.g., English, Spanish)\n5. Download voices marked with ⬇️ icon\n6. Return here to select them")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                    .padding(.vertical, 8)
                
                Text("Alternative: Settings > Siri & Search > Siri Voice")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }) {
                EmptyView()
            }
        }
        .navigationTitle("Voices")
        .onAppear {
            loadVoices()
        }
    }
    
    private func languageName(for code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }
    
    private func loadVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        var groupedVoices: [String: [AVSpeechSynthesisVoice]] = [:]
        
        for code in supportedLanguageCodes {
            // Get all voices for this language
            let matches = allVoices.filter { $0.language.lowercased().starts(with: code.lowercased()) }
            
            // Sort by quality (Premium > Enhanced > Default) and then by name
            let sorted = matches.sorted { voice1, voice2 in
                if voice1.quality != voice2.quality {
                    return voice1.quality.rawValue > voice2.quality.rawValue
                }
                return voice1.name < voice2.name
            }
            
            groupedVoices[code] = sorted
        }
        
        voices = groupedVoices
    }
    
    private func playSample(voice: AVSpeechSynthesisVoice, langCode: String) {
        let text = sampleTexts[langCode] ?? "Hello, this is a test."
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.5
        
        // Setup audio session for playback
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        synthesizer.speak(utterance)
        
        // Reset playing state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(text.count) * 0.1) {
            playingVoiceId = nil
        }
    }
}

// Voice selection row component
struct VoiceRow: View {
    let voice: AVSpeechSynthesisVoice
    let langCode: String
    let isSelected: Bool
    let isPlaying: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    
    var qualityBadge: (String, Color) {
        switch voice.quality {
        case .premium:
            return ("Premium", .purple)
        case .enhanced:
            return ("Enhanced", .blue)
        default:
            return ("Default", .gray)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Preview button
            Button(action: onPreview) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(isPlaying ? .red : .blue)
            }
            .buttonStyle(.plain)
            
            // Voice info
            VStack(alignment: .leading, spacing: 4) {
                Text(voice.name)
                    .font(.body)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    // Quality badge
                    Text(qualityBadge.0)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(qualityBadge.1.opacity(0.15))
                        .foregroundColor(qualityBadge.1)
                        .cornerRadius(4)
                    
                    // Language variant
                    Text(voice.language)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Selection indicator
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

@available(iOS 17.4, *)
struct LanguageSettingsView: View {
    @ObservedObject var whisperState: WhisperState
    @State private var supportedLanguages: [Locale.Language] = []
    @State private var installedLanguages: Set<String> = []
    @State private var isLoading = true
    
    // Config to trigger the system download popup
    @State private var downloadConfig: TranslationSession.Configuration?
    
    // We'll use a standard list of languages to check against
    private let commonLanguageCodes = ["en", "es", "fr", "de", "zh", "ja", "it", "pt", "ko", "ru"]
    
    var body: some View {
        List {
            Section(header: Text("On-Device Models")) {
                if isLoading {
                    ProgressView("Checking availability...")
                } else {
                    ForEach(commonLanguageCodes, id: \.self) { code in
                        LanguageRowButton(code: code, isInstalled: installedLanguages.contains(code)) {
                             // Trigger system download by initiating a dummy session
                             downloadConfig = TranslationSession.Configuration(
                                 source: Locale.Language(identifier: "en"),
                                 target: Locale.Language(identifier: code)
                             )
                        }
                    }
                }
            }
            
            Section(footer: Text("Tap a language to download it for offline use using the system dialog.")) {
                EmptyView()
            }
        }
        .navigationTitle("Translation")
        .task {
            await checkLanguageStatus()
        }
        // This task triggers the system UI for downloading models if they are missing
        .translationTask(downloadConfig) { session in
            do {
                try await session.prepareTranslation()
                // Refresh status after interaction
                await checkLanguageStatus()
            } catch {
                print("Download cancelled or failed: \(error)")
            }
        }
    }
    
    private func checkLanguageStatus() async {
        isLoading = true
        let availability = LanguageAvailability()
        
        var installed = Set<String>()
        
        for code in commonLanguageCodes {
            let target = Locale.Language(identifier: code)
            // Check if it's installed for translation from/to English as a baseline
            let status = await availability.status(from: .init(identifier: "en"), to: target)
            
            if status == .installed || code == "en" {
                installed.insert(code)
            }
        }
        
        installedLanguages = installed
        isLoading = false
    }
}

struct LanguageRowButton: View {
    let code: String
    let isInstalled: Bool
    let action: () -> Void
    
    var name: String {
        Locale.current.localizedString(forLanguageCode: code) ?? code.uppercased()
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(name)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isInstalled {
                    Text("Downloaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Text("Download")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Image(systemName: "icloud.and.arrow.down")
                        .foregroundColor(.blue)
                }
            }
        }
        .disabled(isInstalled) // Don't click if already downloaded
    }
}

struct ModelsView: View {
    @ObservedObject var whisperState: WhisperState
    @Environment(\.dismiss) var dismiss
    
    // Model definitions
    private static let models: [WhisperModelDescriptor] = [
        // Quantized Models (Fastest) - Best for "VOSK-like" speed
        WhisperModelDescriptor(name: "Tiny (Fast) ⚡️", info: "English (Q5_1, ~31 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q5_1.bin", filename: "tiny.en-q5_1.bin"),
        WhisperModelDescriptor(name: "Base (Fast) ⚡️", info: "English (Q5_1, ~57 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q5_1.bin", filename: "base.en-q5_1.bin"),
        WhisperModelDescriptor(name: "Small (Fast) ⚡️", info: "English (Q5_1, ~180 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-q5_1.bin", filename: "small.en-q5_1.bin"),
        
        // Standard Models (Higher Precision)
        WhisperModelDescriptor(name: "tiny", info: "(F16, 75 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin", filename: "tiny.bin"),
        WhisperModelDescriptor(name: "tiny.en", info: "(F16, 75 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin", filename: "tiny.en.bin"),
        WhisperModelDescriptor(name: "base", info: "(F16, 142 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin", filename: "base.bin"),
        WhisperModelDescriptor(name: "base.en", info: "(F16, 142 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin", filename: "base.en.bin"),
        WhisperModelDescriptor(name: "small", info: "(F16, 466 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin", filename: "small.bin"),
        WhisperModelDescriptor(name: "small.en", info: "(F16, 466 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin", filename: "small.en.bin"),
        WhisperModelDescriptor(name: "medium", info: "(F16, 1.5 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin", filename: "medium.bin"),
    ]

    var body: some View {
        List {
            Section(header: Text("Models")) {
                ForEach(ModelsView.models) { model in
                    DownloadButton(model: model, whisperState: whisperState)
                        .onLoad { model in
                            whisperState.loadModel(path: model.fileURL)
                            dismiss()
                        }
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationTitle("Select Model")
    }
}

// Helper struct for Whisper model descriptor
struct WhisperModelDescriptor: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let info: String
    let url: String
    let filename: String
    
    var fileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("models").appendingPathComponent(filename)
    }
}

// Download Button Component
// Download Button Component
struct DownloadButton: View {
    let model: WhisperModelDescriptor
    @ObservedObject var whisperState: WhisperState
    var onLoad: ((WhisperModelDescriptor) -> Void)?
    
    @State private var status: DownloadStatus = .cloud
    @State private var progress: Double = 0.0
    @State private var downloadTask: URLSessionDownloadTask?
    @State private var progressObservation: NSKeyValueObservation?
    
    enum DownloadStatus {
        case cloud
        case downloading
        case downloaded
        case error
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                Text(model.info)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ZStack {
                switch status {
                case .cloud, .error:
                    Button(action: downloadModel) {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                case .downloading:
                    Button(action: cancelDownload) {
                        ZStack {
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 3)
                                .frame(width: 32, height: 32)
                            
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 32, height: 32)
                                .rotationEffect(.degrees(-90))
                            
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 10, height: 10)
                                .cornerRadius(2)
                        }
                    }
                    .buttonStyle(.plain)
                    
                case .downloaded:
                    Button(action: { onLoad?(model) }) {
                        Text("LOAD")
                            .font(.caption.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                }
            }
            .frame(minWidth: 70)
            .contentShape(Rectangle())
        }
        .padding(.vertical, 8)
        .onAppear {
            checkStatus()
        }
        .onDisappear {
            progressObservation?.invalidate()
        }
    }
    
    private func checkStatus() {
        if FileManager.default.fileExists(atPath: model.fileURL.path) {
            status = .downloaded
        } else {
            status = .cloud
        }
    }
    
    private func downloadModel() {
        guard let url = URL(string: model.url) else { return }
        
        status = .downloading
        progress = 0.0
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: model.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            if let localURL = localURL {
                // Success
                try? FileManager.default.removeItem(at: model.fileURL) // Clean old if exists
                try? FileManager.default.moveItem(at: localURL, to: model.fileURL)
                DispatchQueue.main.async {
                    self.status = .downloaded
                    self.progressObservation?.invalidate()
                }
            } else if let error = (error as NSError?), error.code == NSURLErrorCancelled {
                // Cancelled
                DispatchQueue.main.async {
                    self.status = .cloud
                    self.progress = 0.0
                }
            } else {
                // Error
                DispatchQueue.main.async {
                    self.status = .error
                    self.progressObservation?.invalidate()
                }
            }
        }
        
        // Setup Progress Observation
        progressObservation = task.progress.observe(\.fractionCompleted) { obs, _ in
            DispatchQueue.main.async {
                self.progress = obs.fractionCompleted
            }
        }
        
        downloadTask = task
        task.resume()
    }
    
    private func cancelDownload() {
        downloadTask?.cancel()
        progressObservation?.invalidate()
        downloadTask = nil
        status = .cloud
        progress = 0.0
    }
}

// Helper extension for closure binding
extension View {
    func onLoad(perform action: @escaping (WhisperModelDescriptor) -> Void) -> some View {
        return self
    }
}
