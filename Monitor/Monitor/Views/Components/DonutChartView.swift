import SwiftUI

struct DonutChartView: View {
    var segments: [DonutSegment]
    var title: String = ""
    var donutSize: CGFloat = 100
    var showLabels: Bool = true

    var body: some View {
        VStack(spacing: 4) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            ZStack {
                DonutSlice(startAngle: 0, endAngle: 360,
                           color: .mbCardAccent,
                           donutSize: donutSize)

                ForEach(segments.indices, id: \.self) { i in
                    DonutSlice(startAngle: segments[i].startAngle,
                               endAngle: segments[i].endAngle,
                               color: segments[i].color,
                               donutSize: donutSize)
                }
            }
            .frame(width: donutSize, height: donutSize)

            if showLabels {
                ForEach(segments) { s in
                    HStack(spacing: 4) {
                        Circle().fill(s.color).frame(width: 5, height: 5)
                        Text(s.label).font(.custom("Caveat", size: 12)).foregroundColor(.mbSecondaryLabel)
                        Spacer(minLength: 0)
                        Text(String(format: "%.1f%%", s.percentage))
                            .font(.custom("Caveat", size: 12).weight(.semibold))
                            .foregroundColor(.mbLabel)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(s.color.opacity(0.12)))
                    }
                }
            }
        }
    }
}

struct DonutSegment: Identifiable {
    let id = UUID()
    var label: String
    var value: Double
    var color: Color
    var startAngle: Double
    var endAngle: Double
    var percentage: Double
}

struct DonutSlice: View {
    var startAngle: Double
    var endAngle: Double
    var color: Color
    var donutSize: CGFloat = 100

    var body: some View {
        let half = donutSize / 2
        let radius = half - 4
        let lw = max(12, radius * 0.3)
        Path { path in
            path.addArc(center: CGPoint(x: half, y: half), radius: radius,
                        startAngle: .degrees(startAngle - 90),
                        endAngle: .degrees(endAngle - 90),
                        clockwise: false)
        }
        .stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .butt))
    }
}
