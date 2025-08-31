//
//  EffectMixingView.swift
//  AVAudioEngineDemo
//
//  Created by Itsuki on 2025/08/30.
//

import SwiftUI

struct EffectMixingView: View {
    @Environment(AudioEngineManager.self) private var manager

    var body: some View {
        @Bindable var manager = manager
        List {
            Section {
                Text("- Capture the input \n- Add delay and reverb \n- Adjusting the volume \n- Output!")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.leading, 8)
                
            }
            .listSectionMargins(.bottom, 0)

            
            Section {
                HStack {
                    Text("Delay Time (sec)")
                    
                    Spacer()
                    
                    TextField("", value: $manager.delayTime, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
               

               
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("Reverb Wet Dry Mix")

                        Spacer()
                        
                        Text("\(manager.wetDryMix.string(precision: 1))%")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $manager.wetDryMix,
                        in: 0...100.0,
                        label: { },
                        minimumValueLabel: {
                            Text("0%").font(.subheadline).foregroundStyle(.secondary)
                        },
                        maximumValueLabel: {
                            Text("100%").font(.subheadline).foregroundStyle(.secondary)
                        })
                    
         
                }


                
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("Output Volume")

                        Spacer()
                        
                        Text(manager.outputVolume.string(precision: 1))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $manager.outputVolume,
                        in: 0...1.0,
                        label: { },
                        minimumValueLabel: {
                            Text("0.0").font(.subheadline).foregroundStyle(.secondary)
                        },
                        maximumValueLabel: {
                            Text("1.0").font(.subheadline).foregroundStyle(.secondary)
                        })
         
                }
            } header: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configurations")
                    Text("Can be modified during Capture")
                        .font(.subheadline)
                }
            }
            .listSectionMargins(.top, 0)
            
            
            Section {
                Button(action: {
                    if manager.effectMixerState != .stopped {
                        manager.stopCaptureWithEffect()
                        return
                    }
                    Task {
                        
                        do {
                            try await manager.startCaptureWithEffect()
                        } catch (let error) {
                            manager.error = error
                        }
                    }
                }, label: {
                    Text(manager.effectMixerState == .stopped ? "Start Capture" : "Stop Capture")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(ConcentricRectangle())
                })
                .buttonStyle(.borderless)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .listRowInsets(.all, 0)
                .listRowBackground(manager.effectMixerState == .stopped ? Color.blue : Color.red.mix(with: .gray, by: 0.1))
            }
            
            
            if manager.effectMixerState != .stopped {
                Section {
                    if let inputEvent = manager.effectMixerInputEvent {
                        Text("Input Event")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        AudioMetricsView(powerLevels: inputEvent.0, elapsedTime: inputEvent.1)
                    }
                }
                
                Section {
                    if let outputEvent = manager.effectMixerOutputEvent {
                        Text("Output Event")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        AudioMetricsView(powerLevels: outputEvent.0, elapsedTime: outputEvent.1)
                    }
                }
            }
            
        }
        .navigationTitle("Effect & Mixing")
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
