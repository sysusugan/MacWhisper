import SwiftUI

// MARK: - Concept B: "Fluid Wave"
// Tight horizontal bars that rise and fall with audio level. Center bars react most.
// Gradient-colored. When processing, bars pulse in a traveling wave pattern.

struct ConceptB_FluidWave: View {
    var audioLevel: Float  // 0...1
    var isProcessing: Bool

    private let barCount = 7
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2.5
    private let minBarHeight: CGFloat = 4
    private let maxBarHeight: CGFloat = 22

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            barsContent(time: t)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(pillBackground)
        }
    }

    // MARK: - Bars

    @ViewBuilder
    private func barsContent(time: Double) -> some View {
        let level = CGFloat(audioLevel)
        let center = CGFloat(barCount - 1) / 2.0

        HStack(alignment: .center, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                let i = CGFloat(index)
                let distFromCenter = abs(i - center) / center  // 0 at center, 1 at edges

                // Center bars react more (reactivity: 1.0 at center, 0.45 at edges)
                let reactivity: CGFloat = 1.0 - distFromCenter * 0.55

                let barHeight: CGFloat
                if isProcessing {
                    // Traveling sine wave when processing
                    let wave = sin(time * 3.5 - Double(index) * 0.7)
                    let normalized = (wave + 1.0) / 2.0  // 0...1
                    barHeight = minBarHeight + CGFloat(normalized) * (maxBarHeight * 0.45 - minBarHeight)
                } else {
                    let effectiveLevel = level * reactivity
                    // Add slight per-bar variation based on time for organic feel
                    let jitter = CGFloat(sin(time * 8.0 + Double(index) * 2.1)) * level * 1.5
                    barHeight = minBarHeight + effectiveLevel * (maxBarHeight - minBarHeight) + jitter
                }

                let clampedHeight = max(minBarHeight, min(maxBarHeight, barHeight))

                // Color: gradient across bars from cyan-blue through purple
                let hue = 0.52 + Double(index) / Double(barCount - 1) * 0.22  // ~0.52 to ~0.74
                let saturation = isProcessing ? 0.5 : 0.4 + Double(level) * 0.45
                let brightness = isProcessing
                    ? 0.8 + 0.15 * sin(time * 2.5 + Double(index) * 0.5)
                    : 0.65 + Double(level) * 0.35

                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hue: hue, saturation: saturation * 0.6, brightness: min(1.0, brightness + 0.2)),
                                Color(hue: hue, saturation: saturation, brightness: brightness)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: barWidth, height: clampedHeight)
                    // Soft glow behind each bar
                    .shadow(
                        color: Color(hue: hue, saturation: saturation, brightness: 1.0)
                            .opacity(isProcessing ? 0.25 : Double(level) * 0.4),
                        radius: isProcessing ? 3 : 2 + level * 4,
                        y: 0
                    )
            }
        }
        .frame(height: maxBarHeight + 4)  // Fixed frame so pill doesn't resize
        .animation(.easeOut(duration: 0.07), value: audioLevel)
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

struct ConceptB_Preview: View {
    @State private var audioLevel: Float = 0.0
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            ConceptB_FluidWave(audioLevel: audioLevel, isProcessing: isProcessing)

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

#Preview("Concept B: Fluid Wave") {
    ConceptB_Preview()
}
