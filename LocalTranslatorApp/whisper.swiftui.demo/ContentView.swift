import SwiftUI
import AVFoundation
import Translation // <--- CRITICAL IMPORT

struct ContentView: View {
    @StateObject var whisperState = WhisperState()
    @State private var showModels = false
    
    // Theme preference: "light", "dark", or "system"
    @AppStorage("themePreference") private var themePreference: String = "system"
    @Environment(\.colorScheme) var systemColorScheme
    
    // Computed property for current color scheme
    private var currentColorScheme: ColorScheme? {
        switch themePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil // Use system
        }
    }
    
    // Language selections - Persisted across app restarts
    @AppStorage("topLanguage") private var topLanguage = "es" // Person A (e.g. Spanish)
    @AppStorage("bottomLanguage") private var bottomLanguage = "en" // Person B (e.g. English)
    
    // Mode selection
    @State private var isSoloMode = false // true = Solo mode (normal orientation), false = Duo mode (face-to-face)
    
    // Text editing
    @State private var showEditSheet = false
    @State private var editingText = ""
    
    // Custom picker sheets
    @State private var showTopLanguagePicker = false
    @State private var showBottomLanguagePicker = false
    
    // Interaction state
    @State private var isRecordingTop = false
    @State private var isRecordingBottom = false
    
    // Copy feedback states
    @State private var topCopied = false
    @State private var bottomCopied = false
    
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
        ("Chinese (Simplified)", "zh-CN"),
        ("Chinese (Traditional)", "zh-TW"),
        ("Japanese", "ja"),
        ("Korean", "ko"),
        ("Portuguese", "pt"),
        ("Italian", "it")
    ]
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack(spacing: 0) {
                    // MARK: - Top Section (Person A)
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [topColor.opacity(0.05), topColor.opacity(0.15)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .edgesIgnoringSafeArea(.top)
                    
                    VStack(spacing: 15) {
                        // Language Picker beside Record Button (when not recording)
                        if !isRecordingTop {
                            HStack(spacing: 15) {
                                // Swap order for duo mode - button on right side for facing person
                                if isSoloMode {
                                    // Solo mode: Picker left, Button right
                                    Button(action: { showTopLanguagePicker = true }) {
                                        HStack {
                                            Text(languageName(for: topLanguage))
                                                .foregroundColor(.primary)
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(8)
                                    }
                                    
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
                                } else {
                                    // Duo mode: Button left, Picker right (so after 180° rotation, button appears on right for facing person)
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
                                    
                                    Button(action: { showTopLanguagePicker = true }) {
                                        HStack {
                                            Text(languageName(for: topLanguage))
                                                .foregroundColor(.primary)
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(.thinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
                                    }
                                    .rotationEffect(.degrees(180))
                                }
                            }
                        } else {
                            // Show only controls when recording
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
                        }
                        
                        Spacer()
                        
                        // Result Display (Rotated)
                        // Shows what Bottom person said (translated to Top language)
                        // Result Display (Rotated)
                        // Shows what Bottom person said (translated to Top language)
                        // Result Display (Rotated)
                        // Shows what was said on this side (Transcription if A spoke, Translation if B spoke)
                        let topOutput = isTopSpeech ? whisperState.transcribedText : whisperState.translatedText
                        
                        if !topOutput.isEmpty && !isRecordingBottom {
                             VStack(spacing: 8) {
                                 HStack(spacing: 4) {
                                     // 1. TTS Button (Pronunciation)
                                     Button(action: { whisperState.speak(text: topOutput, language: topLanguage) }) {
                                         Image(systemName: whisperState.isPlayingTTS ? "stop.circle.fill" : "speaker.wave.2.circle.fill")
                                             .font(.title2)
                                             .foregroundColor(topColor)
                                     }
                                     
                                     // 2. User Recording Button (Original Voice)
                                     Button(action: { whisperState.playLastRecording() }) {
                                         Image(systemName: whisperState.isPlayingAudio ? "stop.circle.fill" : "waveform.circle.fill")
                                             .font(.title2)
                                             .foregroundColor(isTopSpeech ? topColor : .gray)
                                     }
                                     .disabled(!isTopSpeech)
                                     
                                     ScrollView {
                                         Text(topOutput)
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(topColor)
                                            .padding(16)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                     }
                                     .frame(maxHeight: 180)
                                     .background(.ultraThinMaterial)
                                     .clipShape(RoundedRectangle(cornerRadius: 16))
                                     .overlay(
                                         RoundedRectangle(cornerRadius: 16)
                                             .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                     )
                                     .overlay(
                                         // "Copied!" toast
                                         Group {
                                             if topCopied {
                                                 VStack {
                                                     HStack(spacing: 6) {
                                                         Image(systemName: "checkmark.circle.fill")
                                                             .foregroundColor(.white)
                                                         Text("Copied!")
                                                             .fontWeight(.semibold)
                                                             .foregroundColor(.white)
                                                     }
                                                     .font(.caption)
                                                     .padding(.horizontal, 16)
                                                     .padding(.vertical, 8)
                                                     .background(
                                                         Capsule()
                                                             .fill(topColor)
                                                             .shadow(color: topColor.opacity(0.5), radius: 8, x: 0, y: 4)
                                                     )
                                                 }
                                                 .transition(.scale.combined(with: .opacity))
                                             }
                                         }
                                     )
                                     .shadow(color: topColor.opacity(0.15), radius: 10, x: 0, y: 5)
                                     .scaleEffect(topCopied ? 0.98 : 1.0)
                                     .onTapGesture {
                                         UIPasteboard.general.string = topOutput
                                         let impact = UIImpactFeedbackGenerator(style: .medium)
                                         impact.impactOccurred()
                                         
                                         withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                             topCopied = true
                                         }
                                         
                                         DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                             withAnimation {
                                                 topCopied = false
                                             }
                                         }
                                     }
                                     .animation(.spring(response: 0.3, dampingFraction: 0.6), value: topCopied)
                                 }
                                 
                                 // Edit button (only show for transcribed text, not translation)
                                 if isTopSpeech {
                                     Button(action: {
                                         editingText = whisperState.transcribedText
                                         showEditSheet = true
                                     }) {
                                         HStack(spacing: 4) {
                                             Image(systemName: "pencil.circle.fill")
                                             Text("Edit")
                                         }
                                         .font(.caption)
                                         .foregroundColor(topColor)
                                         .padding(.horizontal, 12)
                                         .padding(.vertical, 6)
                                         .background(.thinMaterial)
                                         .clipShape(Capsule())
                                         .overlay(
                                             Capsule()
                                                 .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                         )
                                         .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                                     }
                                 }
                             }
                             .rotationEffect(.degrees(isSoloMode ? 0 : 180))
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
                .frame(maxHeight: .infinity)
                
                // MARK: - Center Controls
                ZStack {
                    // Background layer with left/right buttons
                    HStack {
                        if !whisperState.canTranscribe {
                            Text("Loading Model...")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            HStack(spacing: 12) {
                                // Swap Languages Button
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
                                
                                // Re-translate Button
                                Button(action: {
                                    guard !whisperState.transcribedText.isEmpty else { return }
                                    
                                    let source = isTopSpeech ? topLanguage : bottomLanguage
                                    let target = isTopSpeech ? bottomLanguage : topLanguage
                                    
                                    whisperState.currentTargetLanguage = target
                                    
                                    // Skip if same language
                                    guard source != target else {
                                        whisperState.translatedText = whisperState.transcribedText
                                        whisperState.speak(text: whisperState.transcribedText, language: target)
                                        return
                                    }
                                    
                                    // Trigger new translation
                                    translationConfig = TranslationSession.Configuration(
                                        source: Locale.Language(identifier: source),
                                        target: Locale.Language(identifier: target)
                                    )
                                }) {
                                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                }
                                .disabled(whisperState.transcribedText.isEmpty)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { showModels = true }) {
                            Image(systemName: "gear")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Centered Solo/Duo Mode Toggle - Overlay in absolute center
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
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke((isSoloMode ? Color.green : Color.purple).opacity(0.4), lineWidth: 1.5)
                        )
                        .shadow(color: (isSoloMode ? Color.green : Color.purple).opacity(0.2), radius: 6, x: 0, y: 3)
                    }
                }
                .padding()
                .background(.thinMaterial)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 1),
                    alignment: .top
                )
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0), Color.white.opacity(0.2)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 1),
                    alignment: .bottom
                )
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                
                // MARK: - Bottom Section (Person B)
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [bottomColor.opacity(0.05), bottomColor.opacity(0.15)]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .edgesIgnoringSafeArea(.bottom)
                    
                    VStack(spacing: 15) {
                        Spacer()
                        
                        // Result Display
                        // Shows what was said on this side (Transcription if B spoke, Translation if A spoke)
                        let bottomOutput = isTopSpeech ? whisperState.translatedText : whisperState.transcribedText
                        
                        if !bottomOutput.isEmpty && !isRecordingTop {
                             VStack(spacing: 8) {
                                 HStack(spacing: 4) {
                                     ScrollView {
                                         Text(bottomOutput)
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(bottomColor)
                                            .padding(16)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                     }
                                     .frame(maxHeight: 150)
                                     .background(.ultraThinMaterial)
                                     .clipShape(RoundedRectangle(cornerRadius: 16))
                                     .overlay(
                                         RoundedRectangle(cornerRadius: 16)
                                             .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                     )
                                     .overlay(
                                         // "Copied!" toast
                                         Group {
                                             if bottomCopied {
                                                 VStack {
                                                     HStack(spacing: 6) {
                                                         Image(systemName: "checkmark.circle.fill")
                                                             .foregroundColor(.white)
                                                         Text("Copied!")
                                                             .fontWeight(.semibold)
                                                             .foregroundColor(.white)
                                                     }
                                                     .font(.caption)
                                                     .padding(.horizontal, 16)
                                                     .padding(.vertical, 8)
                                                     .background(
                                                         Capsule()
                                                             .fill(bottomColor)
                                                             .shadow(color: bottomColor.opacity(0.5), radius: 8, x: 0, y: 4)
                                                     )
                                                 }
                                                 .transition(.scale.combined(with: .opacity))
                                             }
                                         }
                                     )
                                     .shadow(color: bottomColor.opacity(0.15), radius: 10, x: 0, y: 5)
                                     .scaleEffect(bottomCopied ? 0.98 : 1.0)
                                     .onTapGesture {
                                         UIPasteboard.general.string = bottomOutput
                                         let impact = UIImpactFeedbackGenerator(style: .medium)
                                         impact.impactOccurred()
                                         
                                         withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                             bottomCopied = true
                                         }
                                         
                                         DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                             withAnimation {
                                                 bottomCopied = false
                                             }
                                         }
                                     }
                                     .animation(.spring(response: 0.3, dampingFraction: 0.6), value: bottomCopied)
                                     
                                     // 1. User Recording Button (Original Voice)
                                     Button(action: { whisperState.playLastRecording() }) {
                                         Image(systemName: whisperState.isPlayingAudio ? "stop.circle.fill" : "waveform.circle.fill")
                                             .font(.title2)
                                             .foregroundColor(!isTopSpeech ? bottomColor : .gray)
                                     }
                                     .disabled(isTopSpeech)

                                     // 2. TTS Button (Pronunciation)
                                     Button(action: { whisperState.speak(text: bottomOutput, language: bottomLanguage) }) {
                                         Image(systemName: whisperState.isPlayingTTS ? "stop.circle.fill" : "speaker.wave.2.circle.fill")
                                             .font(.title2)
                                             .foregroundColor(bottomColor)
                                     }
                                 }
                                 
                                 // Edit button (only show for transcribed text, not translation)
                                 if !isTopSpeech {
                                     Button(action: {
                                         editingText = whisperState.transcribedText
                                         showEditSheet = true
                                     }) {
                                         HStack(spacing: 4) {
                                             Image(systemName: "pencil.circle.fill")
                                             Text("Edit")
                                         }
                                         .font(.caption)
                                         .foregroundColor(bottomColor)
                                         .padding(.horizontal, 12)
                                         .padding(.vertical, 6)
                                         .background(.thinMaterial)
                                         .clipShape(Capsule())
                                         .overlay(
                                             Capsule()
                                                 .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                         )
                                         .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                                     }
                                 }
                             }
                        }
                        
                        Spacer()
                        
                        // Language Picker beside Record Button (when not recording)
                        if !isRecordingBottom {
                            HStack(spacing: 15) {
                                Button(action: { showBottomLanguagePicker = true }) {
                                    HStack {
                                        Text(languageName(for: bottomLanguage))
                                            .foregroundColor(.primary)
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.thinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
                                }
                                
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
                            }
                        } else {
                            // Show only controls when recording
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
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: .infinity)
            }
            .navigationBarHidden(true)
            .preferredColorScheme(currentColorScheme)
            .sheet(isPresented: $showModels) {
                SettingsView(
                    whisperState: whisperState,
                    themePreference: $themePreference,
                    onModelActivated: {
                        showModels = false
                    }
                )
            }
            .sheet(isPresented: $showEditSheet) {
                TextEditorSheet(
                    text: $editingText,
                    isPresented: $showEditSheet,
                    onSave: {
                        whisperState.transcribedText = editingText
                        // Translation will auto-trigger via .onChange
                    }
                )
            }
            .sheet(isPresented: $showTopLanguagePicker) {
                CustomLanguagePicker(
                    selectedLanguage: $topLanguage,
                    languages: languages,
                    title: "Select Language",
                    color: topColor,
                    isRotated: !isSoloMode
                )
            }
            .sheet(isPresented: $showBottomLanguagePicker) {
                CustomLanguagePicker(
                    selectedLanguage: $bottomLanguage,
                    languages: languages,
                    title: "Select Language",
                    color: bottomColor,
                    isRotated: false
                )
            }
            // MARK: - Translation Logic
            // When transcription completes, translate using stored session OR trigger a new one
            .onChange(of: whisperState.transcribedText) { _, newText in
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
                
                // If config is already set to this source+target, we reuse the session manually
                if let currentConfig = translationConfig,
                   currentConfig.source == Locale.Language(identifier: source),
                   currentConfig.target == Locale.Language(identifier: target) {
                    Task {
                        await whisperState.translateCurrentText()
                    }
                } else {
                    // Change config to trigger a new session via .translationTask
                    translationConfig = TranslationSession.Configuration(
                        source: Locale.Language(identifier: source),
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
            
            // MARK: - Glass Design Loading Screen or No Model Prompt
            if whisperState.isLoadingModel || !whisperState.canTranscribe {
                ZStack {
                    // Gradient background
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.95, green: 0.97, blue: 1.0),
                            Color(red: 0.90, green: 0.94, blue: 0.98)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // Glass card container
                        VStack(spacing: 24) {
                            // Icon with glass effect
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 100, height: 100)
                                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                                
                                Image(systemName: whisperState.isLoadingModel ? "waveform.and.mic" : "gear.circle")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.blue, Color.purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .padding(.bottom, 16)
                            
                            // App name
                            Text("Local Translator")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            // Progress content in glass card
                            VStack(spacing: 16) {
                                if whisperState.isLoadingModel {
                                    // Glass progress bar
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            // Background track with glass
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(.ultraThinMaterial)
                                                .frame(height: 8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                                )
                                            
                                            // Gradient progress fill
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.blue, Color.purple],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: geometry.size.width * whisperState.loadingProgress, height: 8)
                                                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: whisperState.loadingProgress)
                                        }
                                    }
                                    .frame(height: 8)
                                    .frame(maxWidth: 280)
                                    
                                    // Status text
                                    Text(whisperState.loadingMessage)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    // Progress percentage
                                    Text("\(Int(whisperState.loadingProgress * 100))%")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.blue, Color.purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                } else {
                                    // No model loaded - show prompt
                                    VStack(spacing: 12) {
                                        Text("No Model Selected")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        Text("Please download a Whisper model to start transcribing.")
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                        
                                        Spacer()
                                            .frame(height: 8)
                                        
                                        Button {
                                            showModels = true
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: "icloud.and.arrow.down.fill")
                                                Text("Download Model")
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 12)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color.blue, Color.purple],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            .padding(32)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 30, x: 0, y: 15)
                        }
                        .padding(.horizontal, 40)
                        
                        Spacer()
                    }
                }
                .environment(\.colorScheme, .light)
                .transition(.opacity)
                .animation(.spring(response: 0.4, dampingFraction: 0.9), value: whisperState.isLoadingModel)
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
    
    private var themeIconName: String {
        switch themePreference {
        case "light": return "sun.max.fill"
        case "dark": return "moon.fill"
        default: return "circle.lefthalf.filled" // System
        }
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
        VStack(spacing: 10) {
            if isRecording {
                HStack(spacing: 25) {
                    // Cancel Button
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 35))
                            .foregroundColor(.red)
                    }
                    
                    // Stop/Finish Button
                    Button(action: onStop) {
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 70, height: 70)
                            Image(systemName: "stop.fill")
                                .font(.system(size: 25))
                                .foregroundColor(.white)
                        }
                    }
                    .shadow(radius: 5)
                    
                    // Pause/Resume Button
                    Button(action: isPaused ? onResume : onPause) {
                        Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 35))
                            .foregroundColor(color)
                    }
                }
                .transition(.scale.combined(with: .opacity))
                
                Text(isPaused ? "Paused" : "Listening for \(languageName)...")
                    .font(.subheadline)
                    .foregroundColor(color)
                    .italic()
            } else {
                // Initial Record Button - Smaller and pushed down
                VStack {
                    Spacer()
                        .frame(height: 20)
                    
                    Button(action: {
                        // Add small delay to prevent gesture timeout
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            onStart()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 60, height: 60)
                            Image(systemName: "mic.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    .shadow(radius: 5)
                    
                    Text("Tap to Speak")
                        .font(.caption)
                        .foregroundColor(color)
                        .padding(.top, 4)
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
    @Binding var themePreference: String
    var onModelActivated: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Appearance")) {
                    HStack {
                        Label("Theme", systemImage: "paintbrush")
                        Spacer()
                        Picker("", selection: $themePreference) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                }
                
                Section(header: Text("Model Management")) {
                    NavigationLink(destination: ModelsView(whisperState: whisperState, onModelActivated: onModelActivated)) {
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
        "ko": "안녕하세요, 오늘 어떻게 지내세요?",
        "it": "Ciao, come stai oggi?",
        "pt": "Olá, como você está hoje?"
    ]
    
    // We'll filter for the languages we support in the app
    private let supportedLanguageCodes = ["en", "es", "fr", "de", "zh", "ja", "ko", "it", "pt"]
    
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

// MARK: - Text Editor Sheet

struct TextEditorSheet: View {
    @Binding var text: String
    @Binding var isPresented: Bool
    var onSave: () -> Void
    
    @State private var editedText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Info banner
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.body)
                    Text("Edit the transcribed text to fix any errors")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(height: 1),
                    alignment: .bottom
                )
                
                // Text editor
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $editedText)
                        .focused($isFocused)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if editedText.isEmpty {
                        Text("Type your text here...")
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                
                Divider()
                
                // Character count
                HStack {
                    Text("\(editedText.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.thinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1),
                    alignment: .top
                )
            }
            .navigationTitle("Edit Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        text = editedText
                        onSave()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                editedText = text
                // Auto-focus the text editor
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isFocused = true
                }
            }
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
    var onModelActivated: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @AppStorage("selectedModelPath") private var selectedModelPath: String = ""
    @StateObject private var downloadManager = ModelDownloadManager()
    
    // Complete list of all Whisper models from Hugging Face
    private static let models: [WhisperModelDescriptor] = [
        // ========== TURBO MODELS (FASTEST - RECOMMENDED) ==========
        WhisperModelDescriptor(name: "🚀 Large v3 Turbo (Q5) - FASTEST", info: "574 MB, Multilingual", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin", filename: "ggml-large-v3-turbo-q5_0.bin"),
        WhisperModelDescriptor(name: "🚀 Large v3 Turbo (Q8) - BETTER", info: "874 MB, Multilingual", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin", filename: "ggml-large-v3-turbo-q8_0.bin"),
        WhisperModelDescriptor(name: "🚀 Large v3 Turbo (F16) - FULL", info: "1.62 GB, Multilingual", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin", filename: "ggml-large-v3-turbo.bin"),
        
        // ========== TINY MODELS ==========
        WhisperModelDescriptor(name: "Tiny (Q5) - Multilingual", info: "32 MB, Fast", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-q5_1.bin", filename: "ggml-tiny-q5_1.bin"),
        WhisperModelDescriptor(name: "Tiny (Q8) - Multilingual", info: "43 MB, Fast", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-q8_0.bin", filename: "ggml-tiny-q8_0.bin"),
        WhisperModelDescriptor(name: "Tiny (F16) - Multilingual", info: "77 MB, Fast", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin", filename: "ggml-tiny.bin"),
        WhisperModelDescriptor(name: "Tiny English (Q5)", info: "32 MB, Fast (English only)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q5_1.bin", filename: "ggml-tiny.en-q5_1.bin"),
        WhisperModelDescriptor(name: "Tiny English (Q8)", info: "43 MB, Fast (English only)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q8_0.bin", filename: "ggml-tiny.en-q8_0.bin"),
        WhisperModelDescriptor(name: "Tiny English (F16)", info: "77 MB, Fast (English only)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin", filename: "ggml-tiny.en.bin"),
        
        // ========== BASE MODELS ==========
        WhisperModelDescriptor(name: "Base (Q5) - Multilingual", info: "59 MB, Medium", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin", filename: "ggml-base-q5_1.bin"),
        WhisperModelDescriptor(name: "Base (Q8) - Multilingual", info: "81 MB, Medium", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q8_0.bin", filename: "ggml-base-q8_0.bin"),
        WhisperModelDescriptor(name: "Base (F16) - Multilingual", info: "142 MB, Medium", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin", filename: "ggml-base.bin"),
        WhisperModelDescriptor(name: "Base English (Q5)", info: "59 MB, Medium (English only)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q5_1.bin", filename: "ggml-base.en-q5_1.bin"),
        WhisperModelDescriptor(name: "Base English (Q8)", info: "81 MB, Medium (English only)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q8_0.bin", filename: "ggml-base.en-q8_0.bin"),
        WhisperModelDescriptor(name: "Base English (F16)", info: "142 MB, Medium (English only)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin", filename: "ggml-base.en.bin"),
        
        // ========== SMALL MODELS ==========
        WhisperModelDescriptor(name: "Small (Q5) - Multilingual", info: "190 MB, Better", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin", filename: "ggml-small-q5_1.bin"),
        WhisperModelDescriptor(name: "Small (Q8) - Multilingual", info: "264 MB, Better", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q8_0.bin", filename: "ggml-small-q8_0.bin"),
        WhisperModelDescriptor(name: "Small (F16) - Multilingual", info: "488 MB, Better", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin", filename: "ggml-small.bin"),
        WhisperModelDescriptor(name: "Small English (Q5)", info: "190 MB, Better (English only)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-q5_1.bin", filename: "ggml-small.en-q5_1.bin"),
        WhisperModelDescriptor(name: "Small English (Q8)", info: "264 MB, Better (English only)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-q8_0.bin", filename: "ggml-small.en-q8_0.bin"),
        WhisperModelDescriptor(name: "Small English (F16)", info: "488 MB, Better (English only)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin", filename: "ggml-small.en.bin"),
        
        // ========== MEDIUM MODELS ==========
        WhisperModelDescriptor(name: "Medium (Q5) - Multilingual", info: "539 MB, Accurate", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q5_0.bin", filename: "ggml-medium-q5_0.bin"),
        WhisperModelDescriptor(name: "Medium (Q8) - Multilingual", info: "823 MB, Accurate", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q8_0.bin", filename: "ggml-medium-q8_0.bin"),
        WhisperModelDescriptor(name: "Medium (F16) - Multilingual", info: "1.53 GB, Accurate", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin", filename: "ggml-medium.bin"),
        WhisperModelDescriptor(name: "Medium English (Q5)", info: "539 MB, Accurate (English only)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en-q5_0.bin", filename: "ggml-medium.en-q5_0.bin"),
        WhisperModelDescriptor(name: "Medium English (Q8)", info: "823 MB, Accurate (English only)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en-q8_0.bin", filename: "ggml-medium.en-q8_0.bin"),
        WhisperModelDescriptor(name: "Medium English (F16)", info: "1.53 GB, Accurate (English only)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin", filename: "ggml-medium.en.bin"),
        
        // ========== LARGE MODELS ==========
        WhisperModelDescriptor(name: "Large v3 (Q5) - Multilingual", info: "1.08 GB, Very Accurate", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q5_0.bin", filename: "ggml-large-v3-q5_0.bin"),
        WhisperModelDescriptor(name: "Large v3 (F16) - Multilingual", info: "3.1 GB, Very Accurate", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin", filename: "ggml-large-v3.bin"),
        
        WhisperModelDescriptor(name: "Large v2 (Q5) - Multilingual", info: "1.08 GB, Very Accurate", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2-q5_0.bin", filename: "ggml-large-v2-q5_0.bin"),
        WhisperModelDescriptor(name: "Large v2 (Q8) - Multilingual", info: "1.66 GB, Very Accurate", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2-q8_0.bin", filename: "ggml-large-v2-q8_0.bin"),
        WhisperModelDescriptor(name: "Large v2 (F16) - Multilingual", info: "3.09 GB, Very Accurate", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2.bin", filename: "ggml-large-v2.bin"),
        
        WhisperModelDescriptor(name: "Large v1 (F16) - Multilingual", info: "3.09 GB, Very Accurate", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v1.bin", filename: "ggml-large-v1.bin"),
    ]

    var body: some View {
        List {
            Section(header: Text("🚀 Recommended").foregroundColor(.orange)) {
                Text("For best balance of speed & accuracy on iOS, choose a Turbo model with Q5 quantization")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("📥 Download Models")) {
                ForEach(ModelsView.models) { model in
                    DownloadButton(
                        model: model,
                        whisperState: whisperState,
                        selectedModelPath: $selectedModelPath,
                        downloadManager: downloadManager,
                        onLoad: { model in
                            selectedModelPath = model.fileURL.path
                            whisperState.loadModel(path: model.fileURL)
                            onModelActivated?()
                            dismiss()
                        }
                    )
                }
            }
            
            Section(footer: Text("After downloading a model, tap LOAD to activate it. Downloaded models are saved in the app's storage.")) {
                EmptyView()
            }
        }
        .listStyle(GroupedListStyle())
        .navigationTitle("Whisper Models (STT)")
        .onAppear {
            downloadManager.syncStatuses(models: ModelsView.models)
        }
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

@MainActor
final class ModelDownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    enum DownloadStatus {
        case cloud
        case downloading
        case downloaded
        case error
    }

    @Published private var statuses: [String: DownloadStatus] = [:]
    @Published private var progresses: [String: Double] = [:]

    private var taskToFilename: [Int: String] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "local.translator.whisper.model.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    override init() {
        super.init()
        restoreRunningTasks()
    }

    func syncStatuses(models: [WhisperModelDescriptor]) {
        for model in models {
            if statuses[model.filename] == .downloading { continue }
            statuses[model.filename] = FileManager.default.fileExists(atPath: model.fileURL.path) ? .downloaded : .cloud
            if progresses[model.filename] == nil {
                progresses[model.filename] = 0.0
            }
        }
    }

    func status(for model: WhisperModelDescriptor) -> DownloadStatus {
        statuses[model.filename] ?? .cloud
    }

    func progress(for model: WhisperModelDescriptor) -> Double {
        progresses[model.filename] ?? 0.0
    }

    func startDownload(_ model: WhisperModelDescriptor) {
        guard let remoteURL = URL(string: model.url) else {
            statuses[model.filename] = .error
            return
        }

        if status(for: model) == .downloading { return }

        try? FileManager.default.createDirectory(
            at: model.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let task = session.downloadTask(with: remoteURL)
        task.taskDescription = model.filename
        taskToFilename[task.taskIdentifier] = model.filename

        statuses[model.filename] = .downloading
        progresses[model.filename] = 0.0
        task.resume()
    }

    func cancelDownload(_ model: WhisperModelDescriptor) {
        session.getAllTasks { tasks in
            let targetTasks = tasks.filter { $0.taskDescription == model.filename }
            for task in targetTasks {
                task.cancel()
            }
            Task { @MainActor in
                self.statuses[model.filename] = .cloud
                self.progresses[model.filename] = 0.0
            }
        }
    }

    private func restoreRunningTasks() {
        session.getAllTasks { tasks in
            Task { @MainActor in
                for task in tasks {
                    guard let filename = task.taskDescription else { continue }
                    self.taskToFilename[task.taskIdentifier] = filename
                    self.statuses[filename] = .downloading
                    self.progresses[filename] = task.progress.fractionCompleted
                }
            }
        }
    }

    nonisolated private func modelFileURL(filename: String) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("models").appendingPathComponent(filename)
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        guard let filename = downloadTask.taskDescription else { return }
        let value = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.statuses[filename] = .downloading
            self.progresses[filename] = value
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let filename = downloadTask.taskDescription else { return }
        let destination = modelFileURL(filename: filename)

        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            Task { @MainActor in
                self.statuses[filename] = .downloaded
                self.progresses[filename] = 1.0
            }
        } catch {
            Task { @MainActor in
                self.statuses[filename] = .error
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let filename = task.taskDescription else { return }
        guard let error = error as NSError? else { return }

        Task { @MainActor in
            if error.code == NSURLErrorCancelled {
                self.statuses[filename] = .cloud
                self.progresses[filename] = 0.0
            } else {
                self.statuses[filename] = .error
            }
        }
    }
}

// Download Button Component
struct DownloadButton: View {
    let model: WhisperModelDescriptor
    @ObservedObject var whisperState: WhisperState
    @Binding var selectedModelPath: String
    @ObservedObject var downloadManager: ModelDownloadManager
    var onLoad: ((WhisperModelDescriptor) -> Void)?

    private enum DisplayStatus {
        case cloud
        case downloading
        case downloaded
        case active
        case error
    }

    private var displayStatus: DisplayStatus {
        if selectedModelPath == model.fileURL.path {
            return .active
        }
        switch downloadManager.status(for: model) {
        case .cloud:
            return .cloud
        case .downloading:
            return .downloading
        case .downloaded:
            return .downloaded
        case .error:
            return .error
        }
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
                switch displayStatus {
                case .cloud, .error:
                    Button(action: { downloadManager.startDownload(model) }) {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                case .downloading:
                    Button(action: { downloadManager.cancelDownload(model) }) {
                        ZStack {
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 3)
                                .frame(width: 32, height: 32)
                            
                            Circle()
                                .trim(from: 0, to: downloadManager.progress(for: model))
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
                    
                case .active:
                    Text("✓ ACTIVE")
                        .font(.caption.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
            }
            .frame(minWidth: 70)
            .contentShape(Rectangle())
        }
        .padding(.vertical, 8)
        .onAppear {
            downloadManager.syncStatuses(models: [model])
        }
    }
}

// MARK: - Custom Language Picker

struct CustomLanguagePicker: View {
    @Binding var selectedLanguage: String
    @Environment(\.dismiss) var dismiss
    let languages: [(String, String)]
    let title: String
    let color: Color
    let isRotated: Bool
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(languages, id: \.1) { name, code in
                    Button(action: {
                        selectedLanguage = code
                        dismiss()
                    }) {
                        HStack {
                            Text(name)
                                .foregroundColor(.primary)
                                .font(.body)
                            Spacer()
                            if selectedLanguage == code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(color)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .rotationEffect(.degrees(isRotated ? 180 : 0))
    }
}
