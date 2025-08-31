//
//  AudioEngineManager.swift
//  AVAudioEngineDemo
//
//  Created by Itsuki on 2025/08/29.
//

import SwiftUI
// @preconcurrency required for sending AVAudioPCMBuffer, AVAudioTime
@preconcurrency import AVFAudio
import UniformTypeIdentifiers


// MARK: Common Audio Engine Configuration
extension AudioEngineManager {
    nonisolated static let bufferSize: UInt32 = 1024
}

// MARK: Manager specific models
extension AudioEngineManager {
    enum EngineState {
        case started
        case paused
        case stopped
    }
    
    enum _Error: Error {
        
        case permissionDenied
        case unknownPermission
        
        case builtinMicNotFound
        
        case failToGetDestinationURL
        
        case sessionFailToConfigure
        
        case inputNotEnabled

        
        var message: String {
            switch self  {
                
            case .permissionDenied:
                "Recording Permission Denied."
            case .unknownPermission:
                "Unknown Recording Permission."
                
            case .builtinMicNotFound:
                "Built in Mic is not found."
                
            case .failToGetDestinationURL:
                "Failed to get DestinationURL."
           
            case .sessionFailToConfigure:
                "Failed to configure AVAudioSession."
                
                
            // When the engine renders to and from an audio device, the AVAudioSession category and the availability of hardware determines whether an app performs input (for example, input hardware isn't available in tvOS).
            // Check the input node's input format (specifically, the hardware format) for a nonzero sample rate and channel count to see if input is in an enabled state.
            case .inputNotEnabled:
                "Input node is not available to use"
            }
        }
        
    }
}

@Observable
class AudioEngineManager {
    
    // MARK: Recorder Properties
    private(set) var recorderState: EngineState = .stopped {
        didSet {
            if self.recorderState == .started {
                self.recordedContentsDuration = nil
                self.recorderStartTime = AVAudioTime.machineTimeSeconds
                return
            }
            if self.recorderState == .stopped {
                self.recordedContentsDuration = self.recorderEvent?.1 ?? 0
                self.recorderStartTime = nil
                self.recorderEvent = nil
                return
            }
        }
    }
    private(set) var recorderEvent: ([PowerLevel], ElapsedTime)? = nil
    private(set) var recordedContentsDuration: TimeInterval?
    private var recorderStartTime: TimeInterval? = nil
    var destinationURL: URL? {
        let directoryPath = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: .documentsDirectory, create: true)
        // other file format such as caf will also work, AVAudioFile will resolve to those format automatically
        let fileURL = directoryPath?.appendingPathComponent("recording", conformingTo: .mpeg4Audio)
        return fileURL
    }
    
    
    // MARK: Player Properties
    private(set) var playerState: EngineState = .stopped {
        didSet {
            if self.playerState == .started {
                self.playerStartTime = AVAudioTime.machineTimeSeconds
                return
            }
            if self.playerState == .stopped {
                self.playerStartTime = nil
                self.playerEvent = nil
                return
            }
        }
    }
    private(set) var playerEvent: ([PowerLevel], ElapsedTime)? = nil
    private var playerStartTime: TimeInterval? = nil

    
    // MARK: EffectMixer Properties
    private(set) var effectMixerState: EngineState = .stopped {
        didSet {
            if self.effectMixerState == .started {
                self.effectMixerStartTime = AVAudioTime.machineTimeSeconds
                return
            }
            if self.effectMixerState == .stopped {
                self.effectMixerStartTime = nil
                self.effectMixerInputEvent = nil
                self.effectMixerOutputEvent = nil
                return
            }
        }
    }
    private(set) var effectMixerInputEvent: ([PowerLevel], ElapsedTime)? = nil
    private(set) var effectMixerOutputEvent: ([PowerLevel], ElapsedTime)? = nil
    private var effectMixerStartTime: TimeInterval? = nil

    var delayTime: TimeInterval {
        get {
            self.effectMixer?.delayTime ?? 0
        }
        set {
            self.effectMixer?.delayTime = newValue
        }
    }
    
    // The range of valid values is 0.0% to 100.0%.
    var wetDryMix: Float {
        get {
            self.effectMixer?.wetDryMix ?? 40
        }
        set {
            self.effectMixer?.wetDryMix = newValue
        }
    }
    
    // The range of valid values is 0.0 to 1.0.
    var outputVolume: Float {
        get {
            self.effectMixer?.outputVolume ?? 1.0
        }
        set {
            self.effectMixer?.outputVolume = newValue
        }
    }

    
    // MARK: Error
    var error: Error? {
        didSet {
            if let error = self.error {
                print(error)
                self.showError = true
            }
        }
    }

    var showError: Bool = false {
        didSet {
            if !showError {
                self.error = nil
            }
        }
    }
    

    // MARK: private configurations
    private let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var recorder: RecorderEngine? = nil
    private var player: PlayerEngine? = nil
    private var effectMixer: EffectMixerEngine? = nil

    @ObservationIgnored
    private var recordingTask: Task<Void, Error>?
    
    @ObservationIgnored
    private var playerTask: Task<Void, Error>?
    
    @ObservationIgnored
    private var effectMixerTask: (Task<Void, Error>, Task<Void, Error>)?

    
    // MARK: init & deInit
    init() {
        
        do {
            try self.configureAudioSession()
            
            // creating the engines here AFTER configuring audio session
            //
            // reason: input node has to be initialize (ie: by accessing the `inputNode` property) after AVAudioSession set up.
            // otherwise, the app will crash due to the following error.
            // Terminating app due to uncaught exception 'com.apple.coreaudio.avfaudio', reason: 'required condition is false: IsFormatSampleRateAndChannelCountValid(format)'
            self.player = PlayerEngine()
            self.recorder = RecorderEngine()
            self.effectMixer = try EffectMixerEngine()
            
            
            // set up event tasks on initialization instead of every time starting the individual engine
            //
            // reason: when trying to set up a new task every time and cancel the previous, the task will only be set up correctly on the first time and failed for the rest which ended up causing corrupted file in the case of recording
            self.setupRecorderEvent()
            self.setupPlayerEvent()
            self.setupEffectMixerEvent()
            
        } catch(let error) {
            self.error = error
        }

    }
    
    deinit {
        self.recordingTask?.cancel()
        self.recordingTask = nil
        
        self.playerTask?.cancel()
        self.playerTask = nil
        
        self.effectMixerTask?.0.cancel()
        self.effectMixerTask?.1.cancel()
        self.effectMixerTask = nil
        
        try? self.audioSession.setActive(false)
    }
    
}

 
// MARK: Recorder related functions
extension AudioEngineManager {
    
    func startRecording() async throws  {
        print(#function)
        
        guard self.recorderState == .stopped else { return }
        
        guard let recorder = recorder else {
            throw _Error.sessionFailToConfigure
        }

        self.stopPlaying()
        
        try await self.checkRecordingPermission()
        
        guard let fileURL = self.destinationURL else {
            throw _Error.failToGetDestinationURL
        }
        
        if FileManager.default.fileExists(atPath: fileURL.path()) {
            try? FileManager.default.removeItem(at: fileURL)
        }
   
        try recorder.startRecording(to: fileURL, onError: { error in
            DispatchQueue.main.async(execute: {
                self.error = error
                self.stopRecording()
            })
        })
        
        self.recorderState = .started
        
    }
    
    func pauseRecording() {
        recorderState = .paused
        recorder?.pauseRecording()
    }
    
    func resumeRecording() throws {
        guard let recorder = recorder else {
            throw _Error.sessionFailToConfigure
        }

        try recorder.resumeRecording()
        self.recorderState = .started
    }
    
    
    func stopRecording() {
        self.recorderState = .stopped
        recorder?.stopRecording()
    }
}



// MARK: Player related functions
extension AudioEngineManager {
    
    func playRecording() throws {
        print(#function)
        guard let fileURL = self.destinationURL else {
            throw _Error.failToGetDestinationURL
        }
        
        guard let player = player else {
            throw _Error.sessionFailToConfigure
        }

        try player.startPlaying(fileURL, onFinish: {
            DispatchQueue.main.async {
                self.stopPlaying()
            }
        })
        self.playerState = .started
    }

    
    func pausePlaying() {
        self.playerState = .paused
        player?.pausePlaying()
    }
    
    func resumePlaying() throws {
        guard let player = player else {
            throw _Error.sessionFailToConfigure
        }
        try player.resumePlaying()
        self.playerState = .started
        
    }
    
    func stopPlaying() {
        self.playerState = .stopped
        player?.stopPlaying()
    }
}

// MARK: EffectMixer related functions
extension AudioEngineManager {
    
    func startCaptureWithEffect() async throws {
        print(#function)

        guard self.effectMixerState == .stopped else {
            return
        }
        
        guard let effectMixer = effectMixer else {
            throw _Error.sessionFailToConfigure
        }

        
        try await self.checkRecordingPermission()

        try effectMixer.startCapture()
        self.effectMixerState = .started

    }
    
    func stopCaptureWithEffect() {
        self.effectMixerState = .stopped
        self.effectMixer?.stopCapture()
    }
}



// MARK: Helper functions for configuring session / permission
extension AudioEngineManager {
    
    private func checkRecordingPermission() async throws {
        let permission = AVAudioApplication.shared.recordPermission
        switch permission {
            
        case .undetermined:
            let result = await AVAudioApplication.requestRecordPermission()
            if !result {
                throw _Error.permissionDenied
            }
            return
            
        case .denied:
            throw _Error.permissionDenied
            
        case .granted:
            return
            
        @unknown default:
            throw _Error.unknownPermission
        }
    }

    private func configureAudioSession() throws {
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // not required, only for retrieving the input source a little easier
        // when configuring for stereo
        guard let availableInputs = audioSession.availableInputs,
              let builtInMicInput = availableInputs.first(where: { $0.portType == .builtInMic }) else {
            throw _Error.builtinMicNotFound
        }
        try audioSession.setPreferredInput(builtInMicInput)
    }

}



// MARK: Helper functions for setting up event handlers
extension AudioEngineManager {
    
    private func setupRecorderEvent() {
        self.recordingTask = Task {
            guard let recorder = recorder else {
                return
            }
            for await (buffer, time) in recorder.inputTapEvents {
                if self.recorderState == .started, let startTime = self.recorderStartTime {
                    self.recorderEvent = (buffer.powerLevel, time.seconds - startTime)
                }
            }
        }
    }
    
    private func setupPlayerEvent() {
        self.playerTask = Task {
            guard let player = player else {
                return
            }

            for await (buffer, time) in player.outputTapEvents {
                if self.playerState == .started, let startTime = self.playerStartTime {
                    self.playerEvent = (buffer.powerLevel, time.seconds - startTime)
                }
            }
        }
        
    }
    
    private func setupEffectMixerEvent() {
        self.effectMixerTask = (
            // input task
            Task {
                guard let effectMixer = effectMixer else {
                    return
                }
                
                for await (buffer, time) in effectMixer.inputTapEvents {
                    if self.effectMixerState == .started, let startTime = self.effectMixerStartTime {
                        self.effectMixerInputEvent = (buffer.powerLevel, time.seconds - startTime)
                    }
                }
            },
            // output task
            Task {
                guard let effectMixer = effectMixer else {
                    return
                }

                for await (buffer, time) in effectMixer.outputTapEvents {
                    if self.effectMixerState == .started, let startTime = self.effectMixerStartTime {
                        self.effectMixerOutputEvent = (buffer.powerLevel, time.seconds - startTime)
                    }
                }
            }
        )
    }
    
}
