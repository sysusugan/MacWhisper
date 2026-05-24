import SwiftUI

struct SoundSettingsView: View {
    @EnvironmentObject var appState: AppState

    @AppStorage("playStartSound") private var playStartSound = true
    @AppStorage("playStopSound") private var playStopSound = true
    @AppStorage("soundVolume") private var soundVolume: Double = 1.0

    var body: some View {
        Form {
            Section("录音提示音") {
                HStack {
                    Toggle("开始录音时播放提示音", isOn: $playStartSound)
                    Spacer()
                    Button("测试") {
                        playTestSound(named: "Tink")
                    }
                    .controlSize(.small)
                    .disabled(!playStartSound)
                }

                HStack {
                    Toggle("停止录音时播放提示音", isOn: $playStopSound)
                    Spacer()
                    Button("测试") {
                        playTestSound(named: "Pop")
                    }
                    .controlSize(.small)
                    .disabled(!playStopSound)
                }
            }

            Section("音量") {
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
