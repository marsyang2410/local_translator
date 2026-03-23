import Foundation
import SwiftUI
import AVFoundation
import Translation

@MainActor
class WhisperState: NSObject, ObservableObject, AVAudioRecorderDelegate, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    @Published var isModelLoaded = false
    @Published var isLoadingModel = false
    @Published var loadingMessage = ""
    @Published var loadingProgress: Double = 0.0
    @Published var messageLog = ""
    @Published var canTranscribe = false
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var isPlayingTTS = false
    @Published var isPlayingAudio = false
    @Published var isTranscribing = false
    
    // Translation properties
    @Published var transcribedText: String = ""
    @Published var translatedText: String = ""
    @Published var detectedLanguage: String = ""
    @Published var translationEnabled: Bool = true
    
    // Store session for reuse
    var translationSession: TranslationSession?
    
    // Directional Translation State
    var currentSourceLanguage: String = "en"
    var currentTargetLanguage: String = "es"
    
    private var whisperContext: WhisperContext?
    private let recorder = Recorder()
    private var recordedFile: URL? = nil
    private var audioPlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private let translationManager = TranslationManager()
    
    // Store user preferences for voice per language code
    @Published var preferredVoices: [String: String] = [:]
    
    // Track the selected model in UserDefaults
    @AppStorage("selectedModelPath") private var selectedModelPath: String = ""
    
    private var builtInModelUrl: URL? {
        // No longer using bundled model - models are downloaded on demand
        nil
    }
    
    private var sampleUrl: URL? {
        Bundle.main.url(forResource: "jfk", withExtension: "wav", subdirectory: "samples")
    }
    
    // Prompt hints to guide Whisper for better accuracy
    // Short prompts to minimize processing overhead
    private let languagePrompts: [String: String] = [
        "zh-CN": "以下是普通话的句子。",  // "The following is a Mandarin sentence." - More context
        "zh-TW": "以下是國語的句子。"   // "The following is a Mandarin sentence." (Traditional)
    ]
    
    private enum LoadError: Error {
        case couldNotLocateModel
    }
    
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        
        // Check if a model has been previously selected
        if !selectedModelPath.isEmpty && FileManager.default.fileExists(atPath: selectedModelPath) {
            isLoadingModel = true
            loadingMessage = "Loading selected model..."
            loadingProgress = 0.0
            loadModel(path: URL(fileURLWithPath: selectedModelPath))
        } else {
            // No model selected yet - user will need to select one from settings
            isLoadingModel = false
            canTranscribe = false
            loadingMessage = "Please select a model from Settings"
            messageLog += "No model loaded. Please go to Settings > Whisper Models to download one.\n"
        }
    }
    
    func prepareForPlayback() {
        Task.detached {
            await self.setupAudioSessionAsync(isRecording: false)
        }
    }
    
    // Configure Audio Session for Loudspeaker
    nonisolated private func setupAudioSessionAsync(isRecording: Bool = true) async {
        let session = AVAudioSession.sharedInstance()
        let category: AVAudioSession.Category = isRecording ? .playAndRecord : .playback
        let options: AVAudioSession.CategoryOptions = isRecording ? [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP, .allowAirPlay] : []
        
        // Only update if category or options changed to avoid audio engine flickers
        if session.category != category {
            do {
                try session.setCategory(category, mode: .default, options: options)
                try session.setActive(true)
            } catch {
                print("Failed to setup audio session: \(error.localizedDescription)")
            }
        }
    }
    
    // Synchronous version for init only
    nonisolated private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP, .allowAirPlay])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    func loadModel(path: URL? = nil, log: Bool = true) {
        isLoadingModel = true
        isModelLoaded = false
        canTranscribe = false
        loadingProgress = 0.0
        loadingMessage = "Loading model..."

        Task {
            do {
                loadingProgress = 0.1
                whisperContext = nil
                if (log) { messageLog += "Loading model...\n" }
                
                loadingProgress = 0.2
                await MainActor.run {
                    loadingMessage = "Preparing model files..."
                }
                
                let modelUrl = path ?? builtInModelUrl
                if let modelUrl {
                    loadingProgress = 0.3
                    await MainActor.run {
                        loadingMessage = "Initializing Neural Engine..."
                    }
                    
                    try await Task.sleep(nanoseconds: 300_000_000) // Small delay for UI update
                    loadingProgress = 0.5
                    
                    whisperContext = try WhisperContext.createContext(path: modelUrl.path())
                    
                    loadingProgress = 0.9
                    await MainActor.run {
                        loadingMessage = "Finalizing..."
                    }
                    
                    if (log) { messageLog += "Loaded model \(modelUrl.lastPathComponent)\n" }
                } else {
                    if (log) { messageLog += "Could not locate model\n" }
                }
                
                loadingProgress = 1.0
                canTranscribe = true
                isModelLoaded = true
                
                try await Task.sleep(nanoseconds: 200_000_000)
                isLoadingModel = false
            } catch {
                print(error.localizedDescription)
                if (log) { messageLog += "\(error.localizedDescription)\n" }
                canTranscribe = false
                isModelLoaded = false
                loadingMessage = "Failed to load model"
                isLoadingModel = false
            }
        }
    }

    func benchCurrentModel() async {
        if whisperContext == nil {
            messageLog += "Cannot bench without loaded model\n"
            return
        }
        messageLog += "Running benchmark for loaded model\n"
        let result = await whisperContext?.benchFull(modelName: "<current>", nThreads: Int32(min(4, cpuCount())))
        if (result != nil) { messageLog += result! + "\n" }
    }

    func bench(models: [WhisperModelDescriptor]) async {
        let nThreads = Int32(min(4, cpuCount()))

        messageLog += "Running benchmark for all downloaded models\n"
        messageLog += "| CPU | OS | Config | Model | Th | FA | Enc. | Dec. | Bch5 | PP | Commit |\n"
        messageLog += "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n"
        for model in models {
            loadModel(path: model.fileURL, log: false)
            if whisperContext == nil {
                messageLog += "Cannot bench without loaded model\n"
                break
            }
            let result = await whisperContext?.benchFull(modelName: model.name, nThreads: nThreads)
            if (result != nil) { messageLog += result! + "\n" }
        }
        messageLog += "Benchmarking completed\n"
    }
    
    func transcribeSample() async {
        if let sampleUrl {
            await transcribeAudio(sampleUrl)
        } else {
            messageLog += "Could not locate sample\n"
        }
    }
    
    private func transcribeAudio(_ url: URL) async {
        if (!canTranscribe || isTranscribing) {
            return
        }
        guard let whisperContext else {
            return
        }

        isTranscribing = true
        defer { isTranscribing = false }
        
        do {
            messageLog += "Reading wave samples...\n"
            let data = try readAudioSamples(url)
            messageLog += "Transcribing data...\n"
            
            // Get base language code for Whisper (zh for both Chinese variants)
            let whisperLangCode = currentSourceLanguage.hasPrefix("zh") ? "zh" : currentSourceLanguage
            
            // Get prompt hint for Chinese variants
            let prompt = languagePrompts[currentSourceLanguage]
            
            // Pass the source language hint and prompt to Whisper
            await whisperContext.fullTranscribe(samples: data, languageCode: whisperLangCode, prompt: prompt)
            
            let text = await whisperContext.getTranscription()
            
            transcribedText = text
            messageLog += "📝 Transcribed (\(currentSourceLanguage)): \(text)\n"
            
            // Translation pipeline
            //if translationEnabled && !text.isEmpty {
            //    await translateAndSpeak(text: text)
            //}
        } catch {
            print(error.localizedDescription)
            messageLog += "\(error.localizedDescription)\n"
        }
    }
    

    
    /// Repeats the last spoken translation
    func speakLastTranslation() {
        guard !translatedText.isEmpty else { return }
        speak(text: translatedText, language: currentTargetLanguage)
    }
    
    func speak(text: String, language: String) {
        guard !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else { return }
        
        if isPlayingTTS {
            stopTTS()
            return
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Check for user-selected voice preference first
        if let preferredVoiceId = preferredVoices[language],
           let voice = AVSpeechSynthesisVoice(identifier: preferredVoiceId) {
            utterance.voice = voice
        } else {
            // Auto-select best quality voice available
            let allVoices = AVSpeechSynthesisVoice.speechVoices()
            let languageVoices = allVoices.filter { $0.language.starts(with: language) }
            
            // Prioritize: Premium > Enhanced > Default
            if let premium = languageVoices.first(where: { $0.quality == .premium }) {
                utterance.voice = premium
            } else if let enhanced = languageVoices.first(where: { $0.quality == .enhanced }) {
                utterance.voice = enhanced
            } else if let defaultVoice = AVSpeechSynthesisVoice(language: language) {
                utterance.voice = defaultVoice
            }
        }
        
        utterance.rate = 0.52  // Slightly faster for quicker response
        utterance.preUtteranceDelay = 0.0  // No delay before speaking
        
        // Prepare audio session and speak after brief delay
        Task {
            await setupAudioSessionAsync(isRecording: false)
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms for session to stabilize
            synthesizer.speak(utterance)
        }
    }
    
    func setVoice(_ identifier: String, for languageCode: String) {
        preferredVoices[languageCode] = identifier
    }
    
    func getVoiceHeight(for languageCode: String) -> String? {
        return preferredVoices[languageCode]
    }
    
    func stopTTS() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlayingTTS = false
    }
    
    /// Translate using a specific session
    func translateWithSession(_ session: TranslationSession) async {
        guard !transcribedText.isEmpty else { return }
        
        let target = currentTargetLanguage
        
        do {
            // Translate and speak immediately
            let response = try await session.translate(transcribedText)
            translatedText = response.targetText
            print("✅ Translated: \(response.targetText)")
            
            // Speak immediately without waiting
            Task { @MainActor in
                speak(text: response.targetText, language: target)
            }
        } catch {
            print("❌ Translation error: \(error)")
        }
    }
    
    /// Entry point for translation (called from ContentView)
    func translateCurrentText() async {
        guard let session = translationSession else {
            print("❌ No translation session available")
            return
        }
        await translateWithSession(session)
    }
    
    private func readAudioSamples(_ url: URL) throws -> [Float] {
        stopPlayback()
        return try decodeWaveFile(url)
    }
    
    func startRecording(source: String = "en", target: String = "es") async {
        if isRecording { return }

        // [NEW] Clear previous text so .onChange fires even for repeated phrases
        await MainActor.run {
            self.transcribedText = "" 
            self.translatedText = ""
        }
        
        // Check permission first (non-blocking on subsequent calls)
        let hasPermission = await requestRecordPermissionAsync()
        guard hasPermission else {
            print("Microphone permission denied")
            return
        }
        
        // Ensure microphone + loudspeaker
        await setupAudioSessionAsync(isRecording: true)
        
        // Update direction state
        self.currentSourceLanguage = source
        self.currentTargetLanguage = target
        
        do {
            stopPlayback()
            let file = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appending(path: "output.wav")
            try await self.recorder.startRecording(toOutputFile: file, delegate: self)
            await MainActor.run {
                self.isRecording = true
                self.recordedFile = file
            }
        } catch {
            print(error.localizedDescription)
            await MainActor.run {
                self.messageLog += "\(error.localizedDescription)\n"
                self.isRecording = false
            }
        }
    }
    
    func stopRecording() async {
        if !isRecording { return }
        
        await recorder.stopRecording()
        isRecording = false
        isPaused = false
        
        // Prepare audio session for TTS early to avoid delay
        await setupAudioSessionAsync(isRecording: false)
        
        if let recordedFile {
            await transcribeAudio(recordedFile)
            // Keep recordedFile for replay
        }
    }
    
    func playLastRecording() {
        guard let url = recordedFile else { return }
        
        if isPlayingAudio {
            stopPlayback()
            return
        }
        
        stopPlayback()
        
        Task {
            await setupAudioSessionAsync(isRecording: false)
            try? await MainActor.run {
                try startPlayback(url)
            }
        }
    }
    
    func pauseRecording() async {
        guard isRecording && !isPaused else { return }
        await recorder.pauseRecording()
        isPaused = true
    }
    
    func resumeRecording() async {
        guard isRecording && isPaused else { return }
        await recorder.resumeRecording()
        isPaused = false
    }
    
    func cancelRecording() async {
        guard isRecording else { return }
        await recorder.cancelRecording()
        isRecording = false
        isPaused = false
        recordedFile = nil
    }
    
    func toggleRecord() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }
    
    // Async version for modern Swift concurrency
    nonisolated private func requestRecordPermissionAsync() async -> Bool {
#if os(macOS)
        return true
#else
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
#endif
    }
    
    private func startPlayback(_ url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.play()
        isPlayingAudio = true
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlayingAudio = false
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlayingTTS = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlayingTTS = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlayingTTS = false
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlayingAudio = false
        }
    }
    
    // MARK: AVAudioRecorderDelegate
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error {
            Task {
                await handleRecError(error)
            }
        }
    }
    
    private func handleRecError(_ error: Error) {
        print(error.localizedDescription)
        messageLog += "\(error.localizedDescription)\n"
        isRecording = false
    }
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task {
            await onDidFinishRecording()
        }
    }
    
    private func onDidFinishRecording() {
        isRecording = false
    }
}


fileprivate func cpuCount() -> Int {
    ProcessInfo.processInfo.processorCount
}
