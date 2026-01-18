//
//  AudioProcessor.swift
//  LocalTranslator
//
//  Critical component: Converts iPhone mic input (48kHz stereo) to Whisper format (16kHz mono Float32)
//

import AVFoundation

class AudioProcessor {
    
    /// Converts the incoming audio buffer from the microphone to Whisper-ready format
    /// - Parameter buffer: The raw audio buffer from AVAudioEngine (typically 48kHz stereo)
    /// - Returns: Float array in 16kHz mono format, or nil if conversion fails
    func convertToWhisperFormat(from buffer: AVAudioPCMBuffer) -> [Float]? {
        // 1. Define the Whisper format (16kHz, Mono, Float32)
        guard let format16k = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                            sampleRate: 16000,
                                            channels: 1,
                                            interleaved: false) else {
            print("❌ Failed to create 16kHz format")
            return nil
        }
        
        // 2. Create the converter
        guard let converter = AVAudioConverter(from: buffer.format, to: format16k) else {
            print("❌ Failed to create audio converter")
            return nil
        }
        
        // 3. Create the output buffer
        // Calculate capacity: (Original Frames / Original Rate) * New Rate
        let ratio = 16000 / buffer.format.sampleRate
        let capacity = UInt32(Double(buffer.frameCapacity) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format16k, frameCapacity: capacity) else {
            print("❌ Failed to create output buffer")
            return nil
        }
        
        // 4. Perform conversion
        var error: NSError? = nil
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("❌ Audio Conversion Error: \(error.localizedDescription)")
            return nil
        }
        
        // 5. Extract Float array
        if let channelData = outputBuffer.floatChannelData {
            let channelPointer = channelData.pointee
            // Convert UnsafeMutablePointer<Float> to [Float] array
            let floatArray = Array(UnsafeBufferPointer(start: channelPointer, count: Int(outputBuffer.frameLength)))
            print("✅ Converted \(buffer.frameLength) frames @ \(buffer.format.sampleRate)Hz → \(outputBuffer.frameLength) frames @ 16kHz")
            return floatArray
        }
        
        print("❌ Failed to extract channel data")
        return nil
    }
}
