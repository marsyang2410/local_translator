import Foundation
import SwiftUI
import AVFoundation
import Translation

@MainActor
class WhisperState: NSObject, ObservableObject, AVAudioRecorderDelegate, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    @Published var isModelLoaded = false
    @Published var messageLog = ""
    @Published var canTranscribe = false
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var isPlayingTTS = false
    @Published var isPlayingAudio = false
    
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
    
    private var builtInModelUrl: URL? {
        Bundle.main.url(forResource: "ggml-base", withExtension: "bin", subdirectory: "models")
    }
    
    private var sampleUrl: URL? {
        Bundle.main.url(forResource: "jfk", withExtension: "wav", subdirectory: "samples")
    }
    
    // Prompt hints to guide Whisper for Chinese variants
    private let languagePrompts: [String: String] = [
        "zh-CN": "简体",  // "Simplified" - shorter = faster
        "zh-TW": "繁體"   // "Traditional" - shorter = faster
    ]
    
    private enum LoadError: Error {
        case couldNotLocateModel
    }
    
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        loadModel()
    }
    
    func prepareForPlayback() {
        setupAudioSession(isRecording: false)
    }
    
    // Configure Audio Session for Loudspeaker
    private func setupAudioSession(isRecording: Bool = true) {
        let session = AVAudioSession.sharedInstance()
        let category: AVAudioSession.Category = isRecording ? .playAndRecord : .playback
        let options: AVAudioSession.CategoryOptions = isRecording ? [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay] : []
        
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
    
    func loadModel(path: URL? = nil, log: Bool = true) {
        do {
            whisperContext = nil
            if (log) { messageLog += "Loading model...\n" }
            let modelUrl = path ?? builtInModelUrl
            if let modelUrl {
                whisperContext = try WhisperContext.createContext(path: modelUrl.path())
                if (log) { messageLog += "Loaded model \(modelUrl.lastPathComponent)\n" }
            } else {
                if (log) { messageLog += "Could not locate model\n" }
            }
            canTranscribe = true
        } catch {
            print(error.localizedDescription)
            if (log) { messageLog += "\(error.localizedDescription)\n" }
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
        if (!canTranscribe) {
            return
        }
        guard let whisperContext else {
            return
        }
        
        do {
            canTranscribe = false
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
        
        canTranscribe = true
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
        
        prepareForPlayback()
        
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
        synthesizer.speak(utterance)
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
        
        setupAudioSession(isRecording: true) // Ensure microphone + loudspeaker
        
        // Update direction state
        self.currentSourceLanguage = source
        self.currentTargetLanguage = target
        
        requestRecordPermission { granted in
            if granted {
                Task {
                    do {
                        await self.stopPlayback()
                        let file = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                            .appending(path: "output.wav")
                        try await self.recorder.startRecording(toOutputFile: file, delegate: self)
                        self.isRecording = true
                        self.recordedFile = file
                    } catch {
                        print(error.localizedDescription)
                        self.messageLog += "\(error.localizedDescription)\n"
                        self.isRecording = false
                    }
                }
            }
        }
    }
    
    func stopRecording() async {
        if !isRecording { return }
        
        await recorder.stopRecording()
        isRecording = false
        isPaused = false
        
        // Prepare audio session for TTS early to avoid delay
        setupAudioSession(isRecording: false)
        
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
        setupAudioSession(isRecording: false)
        try? startPlayback(url)
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
    
    private func requestRecordPermission(response: @escaping (Bool) -> Void) {
#if os(macOS)
        response(true)
#else
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            response(granted)
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
