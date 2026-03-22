import SwiftUI

// MARK: - Concept C: "Glow Dots"
// 5 dots very close together with a soft bloom/glow. Cool blue-purple tint.
// Audio level affects scale AND glow radius. Idle state has a subtle breathing animation.

struct ConceptC_GlowDots: View {
    var audioLevel: Float  // 0...1
    var isProcessing: Bool

    private let dotCount = 5
    private let dotSize: CGFloat = 5
    private let dotSpacing: CGFloat = 3.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            dotsContent(time: t)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(pillBackground)
        }
    }

    // MARK: - Dots

    @ViewBuilder
    private func dotsContent(time: Double) -> some View {
        let level = CGFloat(audioLevel)
        let center = CGFloat(dotCount - 1) / 2.0
        let isIdle = level < 0.01 && !isProcessing

        HStack(spacing: dotSpacing) {
            ForEach(0..<dotCount, id: \.self) { index in
                let i = CGFloat(index)
                let distFromCenter = center > 0 ? abs(i - center) / center : 0

                // Center dots react more strongly
                let reactivity: CGFloat = 1.0 - distFromCenter * 0.4

                // Scale
                let scale: CGFloat
                if isProcessing {
                    // Gentle sequential pulse
                    let wave = sin(time * 2.8 - Double(index) * 0.55)
                    scale = 1.0 + CGFloat(wave + 1.0) * 0.15  // 1.0...1.3
                } else if isIdle {
                    // Subtle breathing — all dots together with slight phase offset
                    let breath = sin(time * 1.5 + Double(index) * 0.3)
                    scale = 1.0 + CGFloat(breath + 1.0) * 0.06  // 1.0...1.12
                } else {
                    let effectiveLevel = level * reactivity
                    scale = 1.0 + effectiveLevel * 1.4
                }

                // Glow radius
                let glowRadius: CGFloat
                if isProcessing {
                    let pulse = sin(time * 2.8 - Double(index) * 0.55)
                    glowRadius = 3 + CGFloat(pulse + 1.0) * 2.5
                } else if isIdle {
                    let breath = sin(time * 1.5 + Double(index) * 0.3)
                    glowRadius = 2 + CGFloat(breath + 1.0) * 1.0
                } else {
                    glowRadius = 2 + level * reactivity * 10
                }

                // Color: cool blue base, shifts toward purple-pink with higher levels
                let baseHue = 0.6  // blue
                let hue: Double
                if isProcessing {
                    // Slow hue cycling per dot
                    hue = (0.58 + (time * 0.12 + Double(index) * 0.06))
                        .truncatingRemainder(dividingBy: 1.0)
                } else {
                    hue = baseHue + Double(level) * 0.1 + Double(index) * 0.015
                }

                let saturation: Double = isProcessing
                    ? 0.55
                    : (isIdle ? 0.35 : 0.35 + Double(level) * 0.45)

                let brightness: Double = isProcessing
                    ? 0.85 + 0.1 * sin(time * 2.8 - Double(index) * 0.55)
                    : (isIdle ? 0.65 + 0.05 * sin(time * 1.5 + Double(index) * 0.3) : 0.7 + Double(level) * 0.3)

                let glowOpacity: Double = isProcessing
                    ? 0.35 + 0.2 * sin(time * 2.8 - Double(index) * 0.55)
                    : (isIdle ? 0.15 + 0.08 * sin(time * 1.5) : 0.2 + Double(level) * 0.55)

                let dotColor = Color(hue: hue, saturation: saturation, brightness: brightness)

                ZStack {
                    // Bloom / glow layer
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    dotColor.opacity(glowOpacity),
                                    dotColor.opacity(glowOpacity * 0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: dotSize * 0.5 + glowRadius
                            )
                        )
                        .frame(
                            width: dotSize + glowRadius * 2,
                            height: dotSize + glowRadius * 2
                        )

                    // Core dot
                    Circle()
                        .fill(dotColor)
                        .frame(width: dotSize, height: dotSize)
                        .scaleEffect(scale)
                }
                .frame(width: dotSize + 12, height: dotSize + 12)  // Fixed frame prevents layout jumps
            }
        }
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

struct ConceptC_Preview: View {
    @State private var audioLevel: Float = 0.0
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            ConceptC_GlowDots(audioLevel: audioLevel, isProcessing: isProcessing)

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

#Preview("Concept C: Glow Dots") {
    ConceptC_Preview()
}
