import SwiftUI

// MARK: - Concept A: "Siri Orb"
// A single glowing orb that pulses, scales, and shifts colors based on audio level.
// When processing, the orb gently cycles through hues.

struct ConceptA_SiriOrb: View {
    var audioLevel: Float  // 0...1
    var isProcessing: Bool

    private let orbSize: CGFloat = 28

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let level = CGFloat(audioLevel)

            let content = orbContent(time: t, level: level)
            content
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(pillBackground)
        }
    }

    // MARK: - Orb

    @ViewBuilder
    private func orbContent(time: Double, level: CGFloat) -> some View {
        let baseScale: CGFloat = isProcessing
            ? 1.0 + 0.08 * CGFloat(sin(time * 2.5))
            : 1.0 + level * 0.45

        // Hue: recording anchors around blue-purple, processing cycles smoothly
        let hue: Double = isProcessing
            ? (time * 0.15).truncatingRemainder(dividingBy: 1.0)
            : 0.62 + Double(level) * 0.12  // blue → purple shift with loudness

        let saturation: Double = isProcessing ? 0.6 : 0.55 + Double(level) * 0.35
        let brightness: Double = isProcessing
            ? 0.85 + 0.1 * sin(time * 3.0)
            : 0.7 + Double(level) * 0.3

        let glowRadius: CGFloat = isProcessing
            ? 8 + 4 * CGFloat(sin(time * 2.0))
            : 6 + level * 18

        let glowOpacity: Double = isProcessing
            ? 0.4 + 0.15 * sin(time * 2.0)
            : 0.3 + Double(level) * 0.5

        // Secondary hue offset for the gradient edge
        let hue2 = (hue + 0.15).truncatingRemainder(dividingBy: 1.0)

        ZStack {
            // Outer glow layer
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hue: hue, saturation: saturation * 0.7, brightness: 1.0)
                                .opacity(glowOpacity * 0.5),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: orbSize * 0.3,
                        endRadius: orbSize * 0.5 + glowRadius
                    )
                )
                .frame(width: orbSize + glowRadius * 2, height: orbSize + glowRadius * 2)

            // Main orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hue: hue2, saturation: saturation * 0.5, brightness: 1.0),
                            Color(hue: hue, saturation: saturation, brightness: brightness),
                            Color(hue: hue, saturation: saturation * 1.1, brightness: brightness * 0.6)
                        ],
                        center: UnitPoint(x: 0.38, y: 0.35),
                        startRadius: 0,
                        endRadius: orbSize * 0.55
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .scaleEffect(baseScale)

            // Specular highlight
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.45),
                            .white.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: orbSize * 0.22
                    )
                )
                .frame(width: orbSize * 0.4, height: orbSize * 0.25)
                .offset(x: -orbSize * 0.08, y: -orbSize * 0.14)
                .scaleEffect(baseScale)
        }
        .frame(width: 70, height: 36)
        .animation(.easeOut(duration: 0.08), value: audioLevel)
    }

    // MARK: - Background

    private var pillBackground: some View {
        Capsule()
            .fill(Color(white: 0.11))
            .overlay(
                Capsule()
                    .strokeBorder(Color(white: 0.24), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
    }
}

// MARK: - Interactive Preview

struct ConceptA_Preview: View {
    @State private var audioLevel: Float = 0.0
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            ConceptA_SiriOrb(audioLevel: audioLevel, isProcessing: isProcessing)

            VStack(spacing: 12) {
                HStack {
                    Text("Audio Level: \(String(format: "%.2f", audioLevel))")
                        .monospacedDigit()
                    Spacer()
                }
                Slider(value: $audioLevel, in: 0...1)

                Toggle("Processing Mode", isOn: $isProcessing)
            }
            .padding()
            .frame(width: 260)

            Spacer()
        }
        .frame(width: 320, height: 280)
        .background(Color(white: 0.15))
    }
}

#Preview("Concept A: Siri Orb") {
    ConceptA_Preview()
}
