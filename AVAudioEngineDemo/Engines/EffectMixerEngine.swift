//
//  EffectMixerEngine.swift
//  AVAudioEngineDemo
//
//  Created by Itsuki on 2025/08/30.
//

import SwiftUI
// @preconcurrency required for sending AVAudioPCMBuffer, AVAudioTime
@preconcurrency import AVFAudio


// `nonisolated` required because
// `installTap(onBus:bufferSize:format:block:)`: https://developer.apple.com/documentation/avfaudio/avaudionode/installtap(onbus:buffersize:format:block:) will crash if called from the main thread
@Observable
nonisolated final class EffectMixerEngine {
    var delayTime: TimeInterval = 2.0 {
        didSet {
            self.delay.delayTime = delayTime
        }
    }
    var wetDryMix: Float = 40 {
        didSet {
            self.reverb.wetDryMix = self.wetDryMix
        }
    }
    
    // The range of valid values is 0.0 to 1.0.
    var outputVolume: Float = 1.0 {
        didSet {
            self.audioEngine.mainMixerNode.outputVolume = outputVolume
        }
    }
    
    let inputTapEvents: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>
    private let inputTapEventsContinuation: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>.Continuation
    
    let outputTapEvents: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>
    private let outputTapEventsContinuation: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>.Continuation

    private let audioEngine = AVAudioEngine()
    
    private let delay = AVAudioUnitDelay()
    private let reverb = AVAudioUnitReverb()
    

    init() throws {
        (self.inputTapEvents, self.inputTapEventsContinuation) = AsyncStream.makeStream(of: (AVAudioPCMBuffer, AVAudioTime).self)
        (self.outputTapEvents, self.outputTapEventsContinuation) = AsyncStream.makeStream(of: (AVAudioPCMBuffer, AVAudioTime).self)
        try self.setupEngine()
    }
    
    deinit {
        self.audioEngine.detach(delay)
        self.audioEngine.detach(reverb)
    }
    
    // IMPORTANT:
    //
    // input node has to be initialize (ie: access the `inputNode` property) after AVAudioSession set up.
    //
    // otherwise, the app will crash due to the following error.
    // Terminating app due to uncaught exception 'com.apple.coreaudio.avfaudio', reason: 'required condition is false: IsFormatSampleRateAndChannelCountValid(format)'
    private func setupEngine() throws {
        self.audioEngine.attach(delay)
        self.audioEngine.attach(reverb)
        
        reverb.loadFactoryPreset(.largeHall)
        delay.delayTime = self.delayTime
        reverb.wetDryMix = self.wetDryMix
        audioEngine.mainMixerNode.outputVolume = outputVolume


        let inputNode = audioEngine.inputNode
        if !inputNode.isEnabled {
            throw AudioEngineManager._Error.inputNotEnabled
        }
        let mixerNode = audioEngine.mainMixerNode
        
        // specify format is required.
        // Otherwise, we will get the following error.
        // Error Domain=com.apple.coreaudio.avfaudio Code=-10868 "(null)" UserInfo={failed call=err = AUGraphParser::InitializeActiveNodesInOutputChain(ThisGraph, kOutputChainOptimizedTraversal, *GetOutputNode(), isOutputChainActive)}
        let format = inputNode.outputFormat(forBus: 0)

        self.installTapOnInputNode()
        self.installTapOnMixerNode()

        // To add effect to a sound track played from a file,
        // - use playerNode instead of inputNode and call `scheduleFile` after connections like we had in `playRecording` function.
        // - for `format`, same as what we had in the `playRecording` function, that obtained from `AVAudioFile`
        self.audioEngine.connect(inputNode, to: delay, format: format)
        self.audioEngine.connect(delay, to: reverb, format: format)
        
        // we can also connect the effect node directly to the `outputNode` here instead of the `mainMixerNode`
        //
        // The audio engine constructs a singleton main mixer and connects it to the outputNode when first accessing this property.
        // ie: ie: we don't have to (we could) add the following line
        // self.audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: format)
        //
        // However, do note that If the we never sets the connection format between the mainMixerNode and the outputNode, the engine always updates the format to track the format of the outputNode on startup or restart, even after an AVAudioEngineConfigurationChangeNotification.
        // Otherwise, we are responsibility to update the connection format after an AVAudioEngineConfigurationChangeNotification.
        //
        self.audioEngine.connect(reverb, to: mixerNode, format: format)

    }
    
    
    // Capture input, add effect and connect to output
    //
    // To apply effect to an existing audio file,
    // - use playerNode instead of inputNode and call `scheduleFile` after connections like we had in `playRecording` function.
    // - for `format`, same as what we had in the `playRecording` function, that obtained from `AVAudioFile`
    func startCapture() throws {
        self.audioEngine.reset()

        audioEngine.prepare()
        // This method calls the prepare() method if you don’t call it after invoking stop().
        try audioEngine.start()
    }

    func stopCapture() {
        audioEngine.stop()
        // resets all audio nodes in the audio engine.
        // ie: same as calling AVAudioNode.reset() on all the individual nodes.
        // For example, use it to silence reverb and delay tails.
        //
        // this function will not detach/disconnect any nodes, nor set any parameters back to the default value
        self.audioEngine.reset()
    }

    
    private func installTapOnInputNode() {
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: AudioEngineManager.bufferSize, format: inputNode.outputFormat(forBus: 0)) { (buffer: AVAudioPCMBuffer, time: AVAudioTime) in
            self.inputTapEventsContinuation.yield((buffer, time))
        }
    }
    
    
    // `installTap` on the last input node before the outputNode to get the actual event (buffer and time).
    // If attached directly to the outputNode, the block will not be called.
    // In this scenario, attach to the playerNode will also work
    private func installTapOnMixerNode() {
        let mixerNode = audioEngine.mainMixerNode

        mixerNode.removeTap(onBus: 0)
        mixerNode.installTap(onBus: 0, bufferSize: AudioEngineManager.bufferSize, format: mixerNode.outputFormat(forBus: 0), block: { (buffer: AVAudioPCMBuffer, time: AVAudioTime) in
            self.outputTapEventsContinuation.yield((buffer, time))
        })

    }
}

