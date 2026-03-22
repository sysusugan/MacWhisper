import SwiftUI

struct SoundSettingsView: View {
    @EnvironmentObject var appState: AppState

    @AppStorage("playStartSound") private var playStartSound = true
    @AppStorage("playStopSound") private var playStopSound = true
    @AppStorage("soundVolume") private var soundVolume: Double = 1.0

    var body: some View {
        Form {
            Section("Recording Sounds") {
                HStack {
                    Toggle("Play sound when recording starts", isOn: $playStartSound)
                    Spacer()
                    Button("Test") {
                        playTestSound(named: "Tink")
                    }
                    .controlSize(.small)
                    .disabled(!playStartSound)
                }

                HStack {
                    Toggle("Play sound when recording stops", isOn: $playStopSound)
                    Spacer()
                    Button("Test") {
                        playTestSound(named: "Pop")
                    }
                    .controlSize(.small)
                    .disabled(!playStopSound)
                }
            }

            Section("Volume") {
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(.secondary)
                    Slider(value: $soundVolume, in: 0...1.0, step: 0.01)
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.secondary)
                    Text("\(Int(soundVolume * 100))%")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func playTestSound(named name: String) {
        if let sound = NSSound(named: .init(name)) {
            sound.volume = Float(soundVolume)
            sound.play()
        }
    }
}
