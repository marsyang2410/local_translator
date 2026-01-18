import SwiftUI
import AVFoundation
import Translation // <--- CRITICAL IMPORT

struct ContentView: View {
    @StateObject var whisperState = WhisperState()
    @State private var showModels = false
    
    // Language selections
    @State private var topLanguage = "es" // Person A (e.g. Spanish)
    @State private var bottomLanguage = "en" // Person B (e.g. English)
    
    
    
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
                        .rotationEffect(.degrees(180))
                        
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
                        .rotationEffect(.degrees(180))
                        
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
                             .rotationEffect(.degrees(180))
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
                ModelsView(whisperState: whisperState)
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

struct ModelsView: View {
    @ObservedObject var whisperState: WhisperState
    @Environment(\.dismiss) var dismiss
    
    // Model definitions
    private static let models: [WhisperModelDescriptor] = [
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
struct DownloadButton: View {
    let model: WhisperModelDescriptor
    @ObservedObject var whisperState: WhisperState
    var onLoad: ((WhisperModelDescriptor) -> Void)?
    
    @State private var status: DownloadStatus = .unknown
    @State private var progress: Double = 0.0
    @State private var downloadTask: URLSessionDownloadTask?
    
    enum DownloadStatus {
        case unknown
        case downloading
        case downloaded
        case error
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(model.name)
                    .font(.headline)
                Text(model.info)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            switch status {
            case .downloading:
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 100)
            case .downloaded:
                Button("Load") {
                    onLoad?(model)
                }
                .buttonStyle(.borderedProminent)
            case .unknown, .error:
                Button("Download") {
                    downloadModel()
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            checkStatus()
        }
    }
    
    private func checkStatus() {
        if FileManager.default.fileExists(atPath: model.fileURL.path) {
            status = .downloaded
        } else {
            status = .unknown
        }
    }
    
    private func downloadModel() {
        guard let url = URL(string: model.url) else { return }
        
        status = .downloading
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: model.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        _ = downloadTask?.progress.observe(\.fractionCompleted) { observation, _ in
            DispatchQueue.main.async {
                progress = observation.fractionCompleted
            }
        }
        
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            if let localURL = localURL {
                try? FileManager.default.moveItem(at: localURL, to: model.fileURL)
                DispatchQueue.main.async {
                    status = .downloaded
                }
            } else {
                DispatchQueue.main.async {
                    status = .error
                }
            }
        }
        
        downloadTask = task
        task.resume()
    }
}

// Helper extension for closure binding
extension View {
    func onLoad(perform action: @escaping (WhisperModelDescriptor) -> Void) -> some View {
        return self
    }
}
