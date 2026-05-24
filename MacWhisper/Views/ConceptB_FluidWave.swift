import SwiftUI

// MARK: - Fluid Wave Recording Indicator

struct ConceptB_FluidWave: View {
    var audioLevel: Float  // 0...1
    var isProcessing: Bool
    var isToggleMode: Bool = false

    private let barCount = 7
    private let barSpacing: CGFloat = 2.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            HStack(alignment: .center, spacing: barSpacing) {
                WaveBar(index: 0, time: t, audioLevel: audioLevel, isProcessing: isProcessing, barCount: barCount)
                WaveBar(index: 1, time: t, audioLevel: audioLevel, isProcessing: isProcessing, barCount: barCount)
                WaveBar(index: 2, time: t, audioLevel: audioLevel, isProcessing: isProcessing, barCount: barCount)
                WaveBar(index: 3, time: t, audioLevel: audioLevel, isProcessing: isProcessing, barCount: barCount)
                WaveBar(index: 4, time: t, audioLevel: audioLevel, isProcessing: isProcessing, barCount: barCount)
                WaveBar(index: 5, time: t, audioLevel: audioLevel, isProcessing: isProcessing, barCount: barCount)
                WaveBar(index: 6, time: t, audioLevel: audioLevel, isProcessing: isProcessing, barCount: barCount)
            }
            .frame(height: 18)
            .animation(.easeOut(duration: 0.07), value: audioLevel)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(white: 0.11))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isToggleMode && !isProcessing
                                    ? Color.orange.opacity(0.8)
                                    : Color(white: 0.24),
                                lineWidth: isToggleMode && !isProcessing ? 2 : 1
                            )
                    )
            )
            .clipShape(Capsule())
        }
    }
}

private struct WaveBar: View {
    let index: Int
    let time: Double
    let audioLevel: Float
    let isProcessing: Bool
    let barCount: Int

    private let barWidth: CGFloat = 3
    private let minBarHeight: CGFloat = 3
    private let maxBarHeight: CGFloat = 16

    var body: some View {
        let level = CGFloat(audioLevel)
        let center = CGFloat(barCount - 1) / 2.0
        let distFromCenter = abs(CGFloat(index) - center) / center
        let reactivity: CGFloat = 1.0 - distFromCenter * 0.55

        let barHeight = computeHeight(level: level, reactivity: reactivity)
        // Red-orange gradient across bars: hue 0.0 (red) to 0.08 (orange)
        let hue = 0.0 + Double(index) / Double(barCount - 1) * 0.08
        let saturation = isProcessing ? 0.6 : 0.5 + Double(level) * 0.4
        let brightness = computeBrightness(level: level)

        RoundedRectangle(cornerRadius: barWidth / 2)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: hue, saturation: saturation * 0.7, brightness: min(1.0, brightness + 0.15)),
                        Color(hue: hue, saturation: saturation, brightness: brightness)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: barWidth, height: barHeight)
    }

    private func computeHeight(level: CGFloat, reactivity: CGFloat) -> CGFloat {
        let h: CGFloat
        if isProcessing {
            let wave = sin(time * 3.5 - Double(index) * 0.7)
            let normalized = (wave + 1.0) / 2.0
            h = minBarHeight + CGFloat(normalized) * (maxBarHeight * 0.45 - minBarHeight)
        } else {
            let effectiveLevel = level * reactivity
            let jitter = CGFloat(sin(time * 8.0 + Double(index) * 2.1)) * level * 1.5
            h = minBarHeight + effectiveLevel * (maxBarHeight - minBarHeight) + jitter
        }
        return max(minBarHeight, min(maxBarHeight, h))
    }

    private func computeBrightness(level: CGFloat) -> Double {
        if isProcessing {
            return 0.8 + 0.15 * sin(time * 2.5 + Double(index) * 0.5)
        }
        return 0.65 + Double(level) * 0.35
    }
}
