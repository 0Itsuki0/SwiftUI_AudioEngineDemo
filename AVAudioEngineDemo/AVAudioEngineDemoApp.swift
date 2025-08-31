//
//  AVAudioEngineDemoApp.swift
//  AVAudioEngineDemo
//
//  Created by Itsuki on 2025/08/29.
//

import SwiftUI

@main
struct AVAudioEngineDemoApp: App {
    private let manager = AudioEngineManager()
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
                    .environment(manager)

            }
        }
    }
}
