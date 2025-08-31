//
//  Error.swift
//  AudioRecordingDemo
//
//  Created by Itsuki on 2025/08/25.
//


import SwiftUI
import AVFAudio

extension Error {
    var message: String {
        if let error = self as? AudioEngineManager._Error {
            return error.message
        }
        let code = (self as NSError).code
        
        // AVAudioSession.ErrorCode: https://developer.apple.com/documentation/coreaudiotypes/avaudiosession/errorcode
        return switch code {
            // AVAudioSession.ErrorCode: https://developer.apple.com/documentation/coreaudiotypes/avaudiosession/errorcode
        case AVAudioSession.ErrorCode.cannotInterruptOthers.rawValue:
            "Please try again while the app is in the foreground."
        
        case AVAudioSession.ErrorCode.cannotStartPlaying.rawValue:
            "Start audio playback is not allowed."
        
        case AVAudioSession.ErrorCode.cannotStartRecording.rawValue:
            "Start audio recording failed."
        
        case AVAudioSession.ErrorCode.expiredSession.rawValue:
            "Audio Session expired."
        
        case AVAudioSession.ErrorCode.resourceNotAvailable.rawValue:
            "Hardware resources is insufficient."

        case AVAudioSession.ErrorCode.sessionNotActive.rawValue:
            "Session is not active."

        case AVAudioSession.ErrorCode.siriIsRecording.rawValue:
            "Action not allowed due to Siri is recording."

        case AVAudioSession.ErrorCode.insufficientPriority.rawValue:
            "Same audio category is used by other apps. Please terminate those and try again."

        default:
            self.localizedDescription
        }
    }
}
