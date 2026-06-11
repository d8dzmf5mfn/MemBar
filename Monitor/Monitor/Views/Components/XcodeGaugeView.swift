import SwiftUI

struct XcodeGaugeView: View {
    var value: Double
    var maxValue: Double = 100
    var unit: String
    var color: Color
    var lowThreshold: Double = 30
    var midThreshold: Double = 70

    private var ratio: CGFloat { CGFloat(min(max(value / maxValue, 0), 1)) }

    var body: some View {
        VStack(spacing: 2) {
            Text(unit)
                .font(.custom("Caveat", size: 16).weight(.bold))
                .foregroundColor(.mbSecondaryLabel)
            GeometryReader { geo in
                let w = geo.size.width
                let r = w * 0.42
                let lw = max(8, r * 0.18)
                let arcBottom = geo.size.height - 4
                let center = CGPoint(x: w / 2, y: arcBottom)
                let fontSize = min(r * 0.48, 48)

                ZStack {
                    Arc(center: center, radius: r,
                        ratio: 1, color: color.opacity(0.08),
                        lineWidth: lw)

                    Arc(center: center, radius: r,
                        ratio: ratio, color: gaugeColor,
                        lineWidth: lw)
                        .shadow(color: gaugeShadow, radius: 3, y: 1)

                    Text(String(format: "%.1f", value))
                        .font(.custom("Palatino", size: fontSize).bold())
                        .foregroundColor(.mbLabel)
                        .overlay(
                            PaperTexture.image()
                                .resizable(resizingMode: .tile)
                                .blendMode(.screen)
                                .opacity(0.25)
                        )
                        .position(x: w / 2, y: arcBottom - r * 0.4)
                }
            }
        }
    }

    private var gaugeColor: Color {
        if value < lowThreshold { return color.opacity(0.55) }
        if value < midThreshold { return color }
        return color
    }

    private var gaugeShadow: Color {
        if value < lowThreshold { return .mbGaugeLow.opacity(0.3) }
        if value < midThreshold { return color.opacity(0.3) }
        return .mbGaugeHigh.opacity(0.3)
    }
}

private struct Arc: View {
    var center: CGPoint
    var radius: CGFloat
    var ratio: CGFloat
    var color: Color
    var lineWidth: CGFloat

    var body: some View {
        Path { path in
            path.addArc(center: center, radius: radius,
                        startAngle: .degrees(180),
                        endAngle: .degrees(180 + 180 * ratio),
                        clockwise: false)
        }
        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
}
