import SwiftUI

struct DataRow: View {
    var label: String
    var value: Double
    var color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.custom("Caveat", size: 15))
                .foregroundColor(.mbSecondaryLabel)
            Spacer(minLength: 0)
            Text(String(format: "%.1f", value))
                .font(.custom("Caveat", size: 15).weight(.semibold))
                .foregroundColor(.mbLabel)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(color.opacity(0.12)))
        }
    }
}
