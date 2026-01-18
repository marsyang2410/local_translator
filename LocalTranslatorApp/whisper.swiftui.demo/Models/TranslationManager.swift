//
//  TranslationManager.swift
//  LocalTranslator
//
//  Manages text translation using Apple's Translation framework (iOS 15+)
//  and text-to-speech using AVSpeechSynthesizer
//

import Foundation
import Translation
import AVFoundation

@MainActor
class TranslationManager: ObservableObject {
    
    @Published var translatedText: String = ""
    @Published var isTranslating: Bool = false
    @Published var detectedLanguage: String = ""
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    /// Translates text from source language to target language
    /// - Parameters:
    ///   - text: The source text to translate
    ///   - sourceLanguage: Source language code (e.g., "es" for Spanish)
    ///   - targetLanguage: Target language code (e.g., "en" for English)
    /// - Returns: Translated text or nil if translation fails
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String) async -> String? {
        guard !text.isEmpty else { return nil }
        
        isTranslating = true
        defer { isTranslating = false }
        
        do {
            // Create translation configuration
            let configuration = TranslationSession.Configuration(
                source: Locale.Language(identifier: sourceLanguage),
                target: Locale.Language(identifier: targetLanguage)
            )
            
            let session = TranslationSession(configuration: configuration)
            
            // Perform translation
            let response = try await session.translate(text)
            translatedText = response.targetText
            
            print("✅ Translation: '\(text)' → '\(response.targetText)'")
            return response.targetText
            
        } catch {
            print("❌ Translation error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Auto-detect language and translate to English
    /// - Parameter text: The source text to translate
    /// - Returns: Translated English text or nil if translation fails
    func translateToEnglish(text: String) async -> String? {
        // Detect language first
        let detectedLang = detectLanguage(text: text)
        detectedLanguage = detectedLang
        
        // If already English, return as-is
        if detectedLang == "en" {
            print("ℹ️ Text is already in English")
            return text
        }
        
        // Translate to English
        return await translate(text: text, from: detectedLang, to: "en")
    }
    
    /// Detect the language of the given text
    /// - Parameter text: Text to analyze
    /// - Returns: Language code (e.g., "es", "en", "fr")
    func detectLanguage(text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        if let language = recognizer.dominantLanguage {
            let langCode = language.rawValue
            print("🔍 Detected language: \(langCode)")
            return langCode
        }
        
        print("⚠️ Could not detect language, defaulting to 'en'")
        return "en"
    }
    
    /// Speak the given text using text-to-speech
    /// - Parameters:
    ///   - text: Text to speak
    ///   - language: Language code for voice selection (e.g., "en-US", "es-ES")
    func speak(text: String, language: String = "en-US") {
        guard !text.isEmpty else { return }
        
        // Stop any ongoing speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        print("🔊 Requesting speech for: '\(text)' in \(language)")
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Find best quality voice
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let languageVoices = voices.filter { $0.language == language }
        
        // prioritize premium > enhanced > default
        var selectedVoice: AVSpeechSynthesisVoice?
        
        if let premium = languageVoices.first(where: { $0.quality == .premium }) {
            selectedVoice = premium
            print("✨ Using Premium Voice: \(premium.name)")
        } else if let enhanced = languageVoices.first(where: { $0.quality == .enhanced }) {
            selectedVoice = enhanced
            print("✨ Using Enhanced Voice: \(enhanced.name)")
        } else {
            selectedVoice = languageVoices.first
            print("🔹 Using Default Voice: \(selectedVoice?.name ?? "Unknown")")
        }
        
        utterance.voice = selectedVoice
        utterance.rate = 0.5 // Standard rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
    }
    
    /// Stop any ongoing speech
    func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }
}

// MARK: - Language Code Helpers

extension TranslationManager {
    
    /// Convert language code to speech synthesis locale
    /// - Parameter languageCode: Language code (e.g., "es", "en", "fr")
    /// - Returns: Speech synthesis locale (e.g., "es-ES", "en-US")
    func speechLocale(for languageCode: String) -> String {
        switch languageCode {
        case "es": return "es-ES"
        case "en": return "en-US"
        case "fr": return "fr-FR"
        case "de": return "de-DE"
        case "zh": return "zh-CN"
        case "ja": return "ja-JP"
        case "it": return "it-IT"
        case "pt": return "pt-BR"
        default: return "en-US"
        }
    }
}
