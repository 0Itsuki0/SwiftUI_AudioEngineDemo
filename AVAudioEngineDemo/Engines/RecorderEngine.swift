//
//  Recorder.swift
//  AVAudioEngineDemo
//
//  Created by Itsuki on 2025/08/30.
//

import SwiftUI
// @preconcurrency required for sending AVAudioPCMBuffer, AVAudioTime
@preconcurrency import AVFAudio

// `nonisolated` required because
// `installTap(onBus:bufferSize:format:block:)`: https://developer.apple.com/documentation/avfaudio/avaudionode/installtap(onbus:buffersize:format:block:) will crash if called from the main thread
nonisolated final class RecorderEngine {
    
    let inputTapEvents: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>
    private let inputTapEventsContinuation: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>.Continuation
    
    private let audioEngine = AVAudioEngine()

    // Keep a reference to the audio file so that we can close it
    //
    // It’s normally unnecessary to close a file opened for reading because it’s automatically closed when released. It’s only necessary to close a file opened for writing in order to achieve specific control over when the file’s header is updated.
    private var audioFile: AVAudioFile?

    
    init() {
        (self.inputTapEvents, self.inputTapEventsContinuation) = AsyncStream.makeStream(of: (AVAudioPCMBuffer, AVAudioTime).self)
    }


    // MARK: Recording
    // Capture input without connecting output.
    //
    // Can be Used for recording, perform direct processing on the buffer (for example, perform speech recognition), and etc
    func startRecording(to fileURL: URL, onError: @escaping @Sendable (Error) -> Void) throws {
        print(#function)
        self.audioEngine.reset()

        let inputNode = audioEngine.inputNode
        
        if !inputNode.isEnabled {
            throw AudioEngineManager._Error.inputNotEnabled
        }


        let format = inputNode.outputFormat(forBus: 0)
        let audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
        
        self.audioFile = audioFile

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: AudioEngineManager.bufferSize, format: format) { (buffer: AVAudioPCMBuffer, time: AVAudioTime) in
            self.inputTapEventsContinuation.yield((buffer, time))
            do {
                try audioFile.write(from: buffer)
            } catch (let error) {
                onError(error)
            }
        }
        
        audioEngine.prepare()
        // This method calls the prepare() method if you don’t call it after invoking stop().
        try audioEngine.start()
    }
    
    func pauseRecording() {
        self.audioEngine.pause()
    }
    
    func resumeRecording() throws {
        try self.audioEngine.start()
    }

    func stopRecording() {
        self.audioFile?.close()
        self.audioFile = nil

        audioEngine.stop()
        
        audioEngine.inputNode.removeTap(onBus: 0)

        // resets all audio nodes in the audio engine.
        // ie: same as calling AVAudioNode.reset() on all the individual nodes.
        // For example, use it to silence reverb and delay tails.
        //
        // this function will not detach/disconnect any nodes, nor set any parameters back to the default value
        self.audioEngine.reset()
    }
}
