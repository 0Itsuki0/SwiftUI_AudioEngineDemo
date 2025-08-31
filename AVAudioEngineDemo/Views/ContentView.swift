//
//  ContentView.swift
//  AVAudioEngineDemo
//
//  Created by Itsuki on 2025/08/29.
//

import SwiftUI

struct ContentView: View {
    @Environment(AudioEngineManager.self) private var manager

    var body: some View {
        @Bindable var manager = manager
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: {
                        RecordPlaybackView()
                            .environment(self.manager)
                    }, label: {
                        Text("Demo")
                    })
                } header: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Basic Recording & Playback")
                        Text("Capture the input audio, record to a file, and play the recording.")
                            .font(.subheadline)
                    }
                }
                .listSectionMargins(.top, 24)

                
                Section {
                    NavigationLink(destination: {
                        EffectMixingView()
                            .environment(self.manager)

                    }, label: {
                        Text("Demo")
                    })
                } header: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Effect & Mixing")
                        Text("Add effect (delay, reverb) and mixing (controlling output volume) to input voice in real time.")
                            .font(.subheadline)
                    }
                }
                .listSectionMargins(.top, 24)

            }
            .navigationTitle("AVAudioEngine")
            .navigationBarTitleDisplayMode(.large)
            .alert("Oops!", isPresented: $manager.showError, actions: {
                Button(action: {
                    manager.showError = false
                }, label: {
                    Text("OK")
                })
            }, message: {
                    Text("\(manager.error?.message ?? "Unknown Error")")
            })

        }
    }
}

#Preview {
    ContentView()
        .environment(AudioEngineManager())
}
