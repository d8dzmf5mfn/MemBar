import SwiftUI

struct MiniBarChart: View {
    var data: [Double]
    var color: Color
    var barCount: Int = 20

    private var sampled: [Double] {
        guard data.count > 1 else { return data }
        let step = max(1, data.count / barCount)
        var result: [Double] = []
        for i in stride(from: 0, to: data.count, by: step) {
            result.append(data[i])
        }
        return result
    }

    var body: some View {
        GeometryReader { geo in
            let bars = sampled
            if let maxVal = bars.max(), maxVal > 0 {
                let barWidth = geo.size.width / CGFloat(bars.count)
                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(bars.indices, id: \.self) { i in
                        Rectangle()
                            .fill(color.opacity(0.3 + 0.7 * (bars[i] / maxVal)))
                            .frame(width: max(0, barWidth * 0.7), height: geo.size.height * CGFloat(bars[i] / maxVal))
                            .clipShape(RoundedRectangle(cornerRadius: 1))
                    }
                }
            }
        }
    }
}
