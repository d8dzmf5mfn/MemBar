import SwiftUI

struct LabelledChartView: View {
    var data: [Double]
    var color: Color
    var yLabel: String = ""

    private let maxPoints = 30

    private var chartData: [Double] {
        data.suffix(maxPoints)
    }

    private var maxVal: Double {
        guard let m = chartData.max(), m > 0 else { return 1 }
        return m * 1.2
    }

    private var yTicks: [Double] {
        let raw = maxVal
        let rawStep = raw / 4
        let mag = pow(10, floor(log10(rawStep)))
        let res = rawStep / mag
        let niceStep: Double
        if res <= 1.5 { niceStep = 1 * mag }
        else if res <= 3.5 { niceStep = 2 * mag }
        else if res <= 7.5 { niceStep = 5 * mag }
        else { niceStep = 10 * mag }
        var ticks: [Double] = []
        var v = 0.0
        while v <= raw {
            ticks.append(v)
            v += niceStep
        }
        return ticks
    }

    private func fmt(_ v: Double) -> String {
        if v == 0 { return "0" }
        if v >= 100 { return String(format: "%.0f", v) }
        if v >= 1 { return String(format: "%.1f", v) }
        return String(format: "%.2f", v)
    }

    var body: some View {
        let points = chartData
        let maxV = maxVal
        let ticks = yTicks

        Canvas { context, size in
            guard points.count > 1, maxV > 0 else { return }
            let bottomMargin: CGFloat = 16
            let stepX = size.width / CGFloat(points.count - 1)
            let chartH = size.height - bottomMargin
            let chartW = size.width - 44
            let ox: CGFloat = 44
            let oy: CGFloat = 2

            func yPos(_ v: Double) -> CGFloat {
                oy + (chartH - oy) * CGFloat(1 - min(v / maxV, 1))
            }

            for tick in ticks {
                let y = yPos(tick)
                var line = Path()
                line.move(to: CGPoint(x: ox, y: y))
                line.addLine(to: CGPoint(x: ox + chartW, y: y))
                context.stroke(line, with: .color(.mbChartLine.opacity(0.15)), lineWidth: 0.5)
                let txt = Text(fmt(tick)).font(.system(size: 8)).foregroundColor(.mbSecondaryLabel)
                context.draw(txt, at: CGPoint(x: ox - 4, y: y), anchor: .trailing)
            }

            if !yLabel.isEmpty {
                let lbl = Text(yLabel).font(.system(size: 8)).foregroundColor(.mbSecondaryLabel)
                context.draw(lbl, at: CGPoint(x: 6, y: oy), anchor: .topLeading)
            }

            let n = points.count
            let xTickCount = max(2, min(5, n))
            let xStep = max(1, n / xTickCount)
            for i in 0..<xTickCount {
                let idx = min(i * xStep, n - 1)
                let x = ox + CGFloat(idx) * stepX
                let sec = (n - 1 - idx) * 2
                let lbl = Text("\(sec)s").font(.system(size: 8)).foregroundColor(.mbSecondaryLabel)
                context.draw(lbl, at: CGPoint(x: x, y: size.height - 2), anchor: .top)
            }

            let area = Path { path in
                path.move(to: CGPoint(x: ox, y: chartH))
                for i in 0..<n {
                    let x = ox + CGFloat(i) * stepX
                    let y = yPos(points[i])
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: ox + CGFloat(n - 1) * stepX, y: chartH))
                path.closeSubpath()
            }
            context.fill(area, with: .color(color.opacity(0.12)))

            let line = Path { path in
                for i in 0..<n {
                    let x = ox + CGFloat(i) * stepX
                    let y = yPos(points[i])
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            context.stroke(line, with: .color(color), lineWidth: 1.5)
        }
        .frame(height: 120)
    }
}
