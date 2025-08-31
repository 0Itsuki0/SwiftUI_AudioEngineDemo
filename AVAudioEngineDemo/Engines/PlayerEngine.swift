//
//  PlayerEngine.swift
//  AVAudioEngineDemo
//
//  Created by Itsuki on 2025/08/30.
//

import SwiftUI
// @preconcurrency required for sending AVAudioPCMBuffer, AVAudioTime
@preconcurrency import AVFAudio


// `nonisolated` required because
// `installTap(onBus:bufferSize:format:block:)`: https://developer.apple.com/documentation/avfaudio/avaudionode/installtap(onbus:buffersize:format:block:) will crash if called from the main thread
nonisolated final class PlayerEngine {

    let outputTapEvents: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>
    private let outputTapEventsContinuation: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>.Continuation

    private let audioEngine = AVAudioEngine()
    
    private let playerNode = AVAudioPlayerNode()

    private let bufferSize: UInt32 = 1024
    
    // Keep a reference to the audio file so that we can close it
    //
    // It’s normally unnecessary to close a file opened for reading because it’s automatically closed when released. It’s only necessary to close a file opened for writing in order to achieve specific control over when the file’s header is updated.
    private var audioFile: AVAudioFile?


    init() {
        (self.outputTapEvents, self.outputTapEventsContinuation) = AsyncStream.makeStream(of: (AVAudioPCMBuffer, AVAudioTime).self)
        
        self.setupEngine()
    }
    
    deinit {
        self.audioEngine.detach(playerNode)
    }

    
    private func setupEngine() {
        self.audioEngine.attach(playerNode)

        // `installTap` on the last input node before the outputNode to get the actual event (buffer and time).
        // If attached directly to the outputNode, the block will not be called.
        // In this scenario, attach to the playerNode will also work
        //
        let mixerNode = self.audioEngine.mainMixerNode

        mixerNode.removeTap(onBus: 0)
        mixerNode.installTap(onBus: 0, bufferSize: bufferSize, format: mixerNode.outputFormat(forBus: 0), block: { (buffer: AVAudioPCMBuffer, time: AVAudioTime) in
            // `self.playerNode.playerTime(forNodeTime: time)` gives the exact same `AVAudioTime` as the `time`
            self.outputTapEventsContinuation.yield((buffer, time))
        })

    }


    // start player to play a file for a given fileURL
    func startPlaying(_ fileURL: URL, onFinish:  @escaping @Sendable () -> Void) throws {
        print(#function)

        self.audioEngine.reset()
        
        let audioFile = try AVAudioFile(forReading: fileURL)
        self.audioFile = audioFile
        
        // If we have connected to the output node here and then created the mainMixerNode afterward (by accessing it for the first time),
        // The app will crash due to player started when in a disconnected state
        //
        // configure the node’s output format with the same number of channels as in the files and buffers. Otherwise, the node drops or adds channels as necessary
        self.audioEngine.connect(self.playerNode, to: self.audioEngine.mainMixerNode, format: audioFile.processingFormat)


        // The callback notifies your app when playback completes.
        self.playerNode.scheduleFile(audioFile, at: nil, completionCallbackType: .dataPlayedBack, completionHandler: { _ in
            print("play finished")
            onFinish()
        })
                
        self.audioEngine.prepare()
        try audioEngine.start()
        
        // start player after audio engine start
        self.playerNode.play()
    }

    
    func pausePlaying() {
        self.playerNode.pause()
        self.audioEngine.pause()
    }
    
    func resumePlaying() throws {
        try self.audioEngine.start()
        self.playerNode.play()
    }
    
    
    func stopPlaying() {
        // stop player before stopping audio engine
        playerNode.stop()
        
        self.audioFile?.close()
        self.audioFile = nil
        
        self.audioEngine.stop()
        
        // resets all audio nodes in the audio engine.
        // ie: same as calling AVAudioNode.reset() on all the individual nodes.
        // For example, use it to silence reverb and delay tails.
        //
        // this function will not detach/disconnect any nodes, nor set any parameters back to the default value
        self.audioEngine.reset()
        
        self.audioEngine.disconnectNodeOutput(self.playerNode)
    }
}


