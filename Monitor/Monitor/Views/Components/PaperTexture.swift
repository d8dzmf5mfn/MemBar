import SwiftUI
import CoreImage
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Programmatic Crumpled Paper Texture

enum PaperTexture {
    private static var cached: Image?

    static func image() -> Image {
        if let cached { return cached }
        let img = generate()
        cached = img
        return img
    }

    private static func generate() -> Image {
        let w = 200, h = 200
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        let ctx = CIContext(options: [.highQualityDownsample: false])

        // 1. Random noise → CIRandomGenerator produces infinite colored noise
        guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage else {
            return fallback()
        }

        // 2. Chain filters for fiber + crumple + warm tone
        guard let result = noise
            .applyingFilter("CIColorMonochrome", parameters: [
                kCIInputColorKey: CIColor(red: 1, green: 1, blue: 1),
                kCIInputIntensityKey: 1.0
            ])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 2.2,
                kCIInputBrightnessKey: 0.03
            ])
            .applyingFilter("CIMotionBlur", parameters: [
                kCIInputRadiusKey: 1.8,
                kCIInputAngleKey: 0.4
            ])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.90, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0.86, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0.80, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.32),
                "inputBiasVector": CIVector(x: 0.12, y: 0.09, z: 0.06, w: 0)
            ]) as? CIImage else {
            return fallback()
        }

        guard let cgImg = ctx.createCGImage(result, from: rect) else { return fallback() }
        let nsImg = NSImage(cgImage: cgImg, size: NSSize(width: w, height: h))
        return Image(nsImage: nsImg)
    }

    private static func fallback() -> Image {
        Image(systemName: "memorychip.fill")
    }
}

// MARK: - Torn Paper Edge Shape (continuous path)

struct TornRectangle: Shape {
    var tornEdges: Edge.Set = .all
    var depth: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        Path { path in
            let (l, t, r, b) = (rect.minX, rect.minY, rect.maxX, rect.maxY)
            let n = 28
            var x = l, y = t
            path.move(to: CGPoint(x: x, y: y))

            // top → right
            for i in 1...n {
                x = l + CGFloat(i) / CGFloat(n) * rect.width
                let j = hash(0, i)
                let dy = tornEdges.contains(.top) ? (j - 0.5) * depth * 2 : 0
                path.addLine(to: CGPoint(x: x, y: t + dy))
            }
            // right → bottom
            let rightEnd = path.currentPoint ?? CGPoint(x: r, y: t)
            x = rightEnd.x; y = rightEnd.y
            for i in 1...n {
                let targetY = t + CGFloat(i) / CGFloat(n) * rect.height
                let j = hash(1, i)
                let dx = tornEdges.contains(.trailing) ? (j - 0.5) * depth * 2 : 0
                path.addLine(to: CGPoint(x: r + dx, y: targetY))
            }
            // bottom → left
            let bottomEnd = path.currentPoint ?? CGPoint(x: r, y: b)
            x = bottomEnd.x; y = bottomEnd.y
            for i in 1...n {
                let targetX = r - CGFloat(i) / CGFloat(n) * rect.width
                let j = hash(2, i)
                let dy = tornEdges.contains(.bottom) ? (j - 0.5) * depth * 2 : 0
                path.addLine(to: CGPoint(x: targetX, y: b + dy))
            }
            // left → top
            let leftEnd = path.currentPoint ?? CGPoint(x: l, y: b)
            x = leftEnd.x; y = leftEnd.y
            for i in 1..<n {
                let targetY = b - CGFloat(i) / CGFloat(n) * rect.height
                let j = hash(3, i)
                let dx = tornEdges.contains(.leading) ? (j - 0.5) * depth * 2 : 0
                path.addLine(to: CGPoint(x: l + dx, y: targetY))
            }
            path.closeSubpath()
        }
    }

    /// Deterministic pseudo-random in [0, 1) from edge + index
    private func hash(_ edge: Int, _ i: Int) -> CGFloat {
        let x = sin(Double(edge * 137 + i * 73)) * 43758.5453
        return CGFloat(x - floor(x))
    }
}

// MARK: - View Modifiers

extension View {
    /// Warm parchment background with texture
    func paperBackground() -> some View {
        self.background(
            Color.mbBg
                .ignoresSafeArea()
                .overlay(
                    PaperTexture.image()
                        .resizable(resizingMode: .tile)
                        .blendMode(.multiply)
                        .opacity(0.22)
                )
                .allowsHitTesting(false)
        )
    }

    /// Torn paper edge card background with shadow
    func tornBackground() -> some View {
        background(
            ZStack {
                Color.mbCard
                    .clipShape(TornRectangle(tornEdges: .all, depth: 4))
                    .shadow(color: .mbLabel.opacity(0.08), radius: 4, x: 0, y: 2)
                PaperTexture.image()
                    .resizable(resizingMode: .tile)
                    .blendMode(.multiply)
                    .opacity(0.12)
                    .allowsHitTesting(false)
                    .clipShape(TornRectangle(tornEdges: .all, depth: 4))
            }
        )
    }
}
