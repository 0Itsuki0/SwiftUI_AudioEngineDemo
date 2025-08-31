//
//  RecordPlaybackView.swift
//  AVAudioEngineDemo
//
//  Created by Itsuki on 2025/08/30.
//

import SwiftUI

struct RecordPlaybackView: View {
    @Environment(AudioEngineManager.self) private var manager

    var body: some View {
        @Bindable var manager = manager
        List {
            Section {
                Text("- Record the Input and Save to File \n- Playback after finish recording")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.leading, 8)
                
            }
            .listSectionMargins(.bottom, 0)

            
            Section {
                switch manager.recorderState {
                case .stopped:
                    Button(action: {
                        Task {
                            do {
                                try await manager.startRecording()
                            } catch (let error) {
                                manager.error = error
                            }
                        }
                    }, label: {
                        Text(manager.recordedContentsDuration != nil ? "Start New Recording" : "Start Recording")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(ConcentricRectangle())
                    })
                    .buttonStyle(.borderless)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .listRowInsets(.all, 0)
                    .listRowBackground(Color.blue)
                    
                case .paused:
                    
                    VStack(spacing: 24) {
                        HStack {
                            Text("Recording paused")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Spacer()
                            HStack(spacing: 16) {
                                button(imageName: "stop.circle", action: {
                                    manager.stopRecording()
                                })
                                
                                button(imageName: "play.circle", action: {
                                    do {
                                        try manager.resumeRecording()
                                    } catch (let error) {
                                        manager.error = error
                                    }
                                })
                                
                            }
                        }
                        
                    }

                case .started:
                    
                    VStack(spacing: 24) {
                        HStack {
                            Text("Recording")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Spacer()
                            HStack(spacing: 16) {
                                button(imageName: "stop.circle", action: {
                                    manager.stopRecording()
                                })

                                button(imageName: "pause.circle", action: {
                                    manager.pauseRecording()
                                })

                            }
                        }
                        
                    }
                    
                }


                if manager.recorderState != .stopped, let event = manager.recorderEvent {
                    AudioMetricsView(powerLevels: event.0, elapsedTime: event.1)
                }

            }
            .listSectionMargins(.bottom, 24)

            
            
            if let recordedContentsDuration = manager.recordedContentsDuration {
                
                Section("Recording Playback") {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Recording Finished")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        
                        HStack {
                            
                            Text("Total Duration: \(recordedContentsDuration.secondString)")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Group {
                                
                                switch self.manager.playerState {
                                case .started:
                                    button(imageName: "pause.circle", action: {
                                        manager.pausePlaying()
                                    })
                                case .paused:
                                    button(imageName: "play.circle", action: {
                                        do {
                                            try manager.resumePlaying()
                                        } catch (let error) {
                                            manager.error = error
                                        }
                                    })
                                case .stopped:
                                    button(imageName: "play.circle", action: {
                                        do {
                                            try manager.playRecording()
                                        } catch (let error) {
                                            manager.error = error
                                        }
                                    })
                                }
                            }
                        }
                    }
                    
                    if manager.playerState != .stopped, let event = manager.playerEvent {
                        AudioMetricsView(powerLevels: event.0, elapsedTime: event.1)
                    }

                }
            }
            
        }
        .navigationTitle("Record & Playback")
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
    
    private func button(imageName: String, action: @escaping () -> Void) -> some View {
        Button(action: action, label: {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .contentShape(.circle)
                .frame(width: 32)
        })
        .buttonStyle(.borderless)
    }

}

