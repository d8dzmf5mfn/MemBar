import SwiftUI
import AppKit
import CoreText

@main
struct MemBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() { registerFonts() }

    var body: some Scene {
        Settings { EmptyView() }
    }

    private func registerFonts() {
        for name in ["RockSalt-Regular", "Caveat-Regular"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// MARK: - AppDelegate
// =====================================================
// Hosts the NSStatusItem, owns the renderer + icon view.
// Renders a horizontal progress bar + percentage (or network speeds) as a
// templated NSImage so the menu bar shows it in the system foreground color.
// =====================================================

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var monitor: SystemMonitor!
    private var renderer: MenuBarRenderer!
    private var iconView: StatusBarIconView!
    private var popover: NSPopover!
    /// Held strongly so the KVO token isn't deallocated mid-observation.
    /// Without this, `observe(...)` returns a token that the Swift runtime
    /// would deallocate at the end of the calling expression, killing
    /// the subscription immediately and triggering a "result unused" warning.
    private var themeObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor = SystemMonitor()
        monitor.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // macOS 27 beta NSStatusBarButton draws a tinted backing over any
        // image assigned to it. Strip the default content + subviews so
        // the backing is empty, then attach our custom view.
        if let button = statusItem.button {
            button.image = nil
            button.title = ""
            button.subviews.forEach { $0.removeFromSuperview() }
        }

        // Compute initial content size for the icon view; MenuBarRenderer
        // re-renders at 2 Hz and may change width as the bar fills.
        let initialSize = MenuBarRenderer.preferredSize(
            mode: monitor.menuBarMode,
            memoryPercent: monitor.memory.usagePercent,
            downloadBps: monitor.displayDownloadSpeed,
            uploadBps: monitor.displayUploadSpeed
        )
        iconView = StatusBarIconView(frame: NSRect(origin: .zero, size: initialSize))
        iconView.target = self
        iconView.action = #selector(handleClick(_:))
        statusItem.button?.addSubview(iconView)

        // Popover with the 4x2 data table panel.
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 300)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(monitor: monitor)
        )

        // 2 Hz is plenty for a numeric bar; the timer also re-evaluates
        // content width when the percentage rolls over a tick boundary.
        renderer = MenuBarRenderer(monitor: monitor) { [weak self] nsImage, newSize in
            guard let self else { return }
            // Resize the view if the rendered image grew/shrank.
            if self.iconView.frame.size != newSize {
                self.iconView.frame = NSRect(origin: .zero, size: newSize)
            }
            self.iconView.image = nsImage
            self.iconView.needsDisplay = true
        }

        // Re-render the menu-bar icon when the system appearance changes
        // (light ⇄ dark, or high-contrast variants). The NSImage is
        // template-mode so AppKit tints it with the new foreground color
        // automatically, but we still need to redraw the underlying CG
        // bitmap so any state held in the renderer's tick counter is
        // fresh. We KVO `NSApp.effectiveAppearance` because that's the
        // canonical source for "what appearance am I being drawn under"
        // and it covers manual toggles AND macOS Auto Dark Mode flips.
        //
        // (An earlier draft tried `AppleInterfaceThemeChangedNotification`
        // and `NSSystemColorsDidChange`, but the former is not exposed
        // to Swift and the latter fires too aggressively.)
        themeObservation = NSApp.observe(\.effectiveAppearance, options: [.new, .initial]) { [weak self] _, _ in
            // KVO callbacks land on the thread that mutated the value,
            // which is the main thread for `NSApp.effectiveAppearance`.
            MainActor.assumeIsolated { self?.renderer?.render() }
        }
    }

    @objc private func handleClick(_ sender: Any?) {
        let event = NSApp.currentEvent

        // Right-click → quit menu.
        if event?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Quit MemBar", action: #selector(quit), keyEquivalent: "q")
            statusItem.menu = menu
            DispatchQueue.main.async { [weak self] in self?.statusItem.menu = nil }
            return
        }

        // Left-click → toggle popover with the data table.
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(
                relativeTo: iconView.bounds,
                of: iconView,
                preferredEdge: .minY
            )
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) {
        renderer?.stop()
        monitor?.stop()
    }
}

// MARK: - StatusBarIconView
// =====================================================
// Bypasses NSButton entirely: draws a raw NSImage onto an NSView with
// no backing fill, so the menu bar background shows through transparent
// pixels of the template-mode alpha mask.
// =====================================================

final class StatusBarIconView: NSView {
    var image: NSImage?
    weak var target: AnyObject?
    var action: Selector?

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // No background fill — transparent pixels of the template mask
        // let the menu bar show through.
        guard let image else { return }
        image.draw(
            in: bounds,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1.0
        )
    }

    override func mouseDown(with event: NSEvent) { sendAction() }
    override func rightMouseDown(with event: NSEvent) { sendAction() }

    private func sendAction() {
        guard let target, let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }
}

// MARK: - MenuBarRenderer
// =====================================================
// 2 Hz timer → renders a progress-bar + percentage (or download/upload speeds)
// string into an NSAttributedString, rasterizes to a template-mode NSImage,
// and reports the new content size so the icon view can resize to fit.
// =====================================================

@MainActor
final class MenuBarRenderer {
    private let monitor: SystemMonitor
    private let onImage: (NSImage, NSSize) -> Void
    private var timer: Timer?

    // Visual constants — measured in POINTS (1pt = 1px @ 1x, 2px @ 2x retina).
    // The renderer rasterizes at 2x for crispness on retina, but layout is
    // always in points.
    //
    // Donut chart: outer ring renders as a low-alpha stroke; the filled
    // portion is an arc that grows clockwise from 12 o'clock as memory
    // usage rises. The 22pt menu bar height is the binding constraint —
    // donut diameter is set to fit comfortably inside.
    private static let donutDiameter: CGFloat = 16
    private static let strokeWidth: CGFloat = 2.5
    private static let gap: CGFloat = 5            // gap between donut and label
    private static let fontSize: CGFloat = 11      // ~NSFont.smallSystemFontSize

    init(monitor: SystemMonitor, onImage: @escaping (NSImage, NSSize) -> Void) {
        self.monitor = monitor
        self.onImage = onImage
        start()
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            // Timer fires on the main run loop, so we're already on
            // the main actor — `assumeIsolated` lets us call the
            // @MainActor-isolated `render()` synchronously.
            MainActor.assumeIsolated { self?.render() }
        }
        render()
    }

    func stop() { timer?.invalidate(); timer = nil }

    /// Public so AppDelegate can size the initial view before the first frame.
    static func preferredSize(
        mode: SystemMonitor.MenuBarMode,
        memoryPercent: Double,
        downloadBps: Double,
        uploadBps: Double
    ) -> NSSize {
        let labelText = labelString(mode: mode, memoryPercent: memoryPercent,
                                    downloadBps: downloadBps, uploadBps: uploadBps)
        let labelWidth = textWidth(labelText)
        let contentWidth = donutDiameter + gap + labelWidth
        return NSSize(width: ceil(contentWidth), height: 22)
    }

    // MARK: - Day / night color scheme
    // =====================================================
    // The ring and label color follow the macOS system appearance
    // (light/dark mode) — not the wall-clock time. The menu-bar icon
    // uses `NSImage.isTemplate = true` (set later) so AppKit auto-tints
    // it with the system foreground. The popover ring uses SwiftUI's
    // `Color.primary` which also auto-flips. We just need a hook to
    // re-render the menu-bar icon when the appearance changes — that's
    // the `themeObserver` in `AppDelegate`.
    // =====================================================

    // MARK: - Content

    private static func labelString(
        mode: SystemMonitor.MenuBarMode,
        memoryPercent: Double,
        downloadBps: Double,
        uploadBps: Double
    ) -> String {
        switch mode {
        case .memory:
            return String(format: "%.0f%%", memoryPercent)
        case .network:
            return "↓\(formatSpeedShort(downloadBps)) ↑\(formatSpeedShort(uploadBps))"
        }
    }

    private static func formatSpeedShort(_ bps: Double) -> String {
        if bps >= 1_000_000_000 { return String(format: "%.1fG", bps / 1_000_000_000) }
        if bps >= 1_000_000 { return String(format: "%.1fM", bps / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0fK", bps / 1_000) }
        return String(format: "%.0fB", bps)
    }

    private static func textWidth(_ text: String) -> CGFloat {
        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attrs)
        return ceil(size.width)
    }

    // MARK: - Render

    func render() {
        let memPct = monitor.memory.usagePercent
        let down = monitor.displayDownloadSpeed
        let up = monitor.displayUploadSpeed
        let mode = monitor.menuBarMode

        let labelText = Self.labelString(mode: mode, memoryPercent: memPct,
                                        downloadBps: down, uploadBps: up)
        let labelWidth = Self.textWidth(labelText)
        let contentW = ceil(Self.donutDiameter + Self.gap + labelWidth)
        let contentH: CGFloat = 22  // match menu bar height

        // Render at 2x for retina sharpness; NSSize stays in points.
        let scale: CGFloat = 2
        let pixelW = Int(contentW * scale)
        let pixelH = Int(contentH * scale)
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        guard let ctx = CGContext(
            data: nil, width: pixelW, height: pixelH,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: info
        ) else { return }
        ctx.translateBy(x: 0, y: CGFloat(pixelH))
        ctx.scaleBy(x: 1, y: -1)
        ctx.setShouldAntialias(true)
        ctx.scaleBy(x: scale, y: scale)  // from here on, work in points

        // ---- 1. Donut geometry ----
        // Center the donut vertically in the 22pt slot. CG arc origin is the
        // top-left of the bounding box, so we use (cx, cy) as the center
        // and compute the box from the radius.
        let donutRadius = Self.donutDiameter / 2
        let cx = donutRadius
        let cy = contentH / 2
        let donutBox = CGRect(
            x: cx - donutRadius,
            y: cy - donutRadius,
            width: Self.donutDiameter,
            height: Self.donutDiameter
        )

        // ---- 2. Foreground arc (filled portion) ----
        // The arc grows clockwise on screen from 12 o'clock. At 0% nothing
        // is drawn — the icon is "empty" so the user knows memory is idle.
        // We deliberately do NOT draw a faint background ring, because:
        //   1) macOS template-mode NSImage treats the alpha mask with a
        //      threshold — a low-alpha ring (e.g. 0.22) renders as fully
        //      transparent and is invisible.
        //   2) A high-alpha ring (e.g. 0.55) would render as a solid ring
        //      and visually conflict with the foreground arc, killing the
        //      "growing" effect that makes the gauge readable.
        // CG `addArc` semantics (Y-flipped context):
        //   - clockwise: false + end > start   → short arc, growing CCW in
        //     CG math = visually CW on screen after the Y flip
        //   - For sweep > 180° we still use end = start + sweep; CG will
        //     take the long way around (wrapping past 2π) and the arc
        //     still grows CW on screen.
        //   - For sweep == 2π (i.e. 100%) the arc closes back to start.
        let fillRatio = max(0, min(1, memPct / 100.0))
        if fillRatio > 0 {
            let sweep: CGFloat = .pi * 2 * CGFloat(fillRatio)
            ctx.setLineWidth(Self.strokeWidth)
            ctx.setLineCap(.round)
            // Opaque white pixels; AppKit tints with the system foreground
            // when isTemplate is set on the resulting NSImage.
            ctx.setStrokeColor([1, 1, 1, 1.0])
            let inset = Self.strokeWidth / 2
            let bgRadius = donutRadius - inset
            let fgPath = CGMutablePath()
            fgPath.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: bgRadius,
                startAngle: .pi / 2,
                endAngle: .pi / 2 + sweep,
                clockwise: false
            )
            ctx.addPath(fgPath)
            ctx.strokePath()
        }

        // ---- 4. Label (percentage or speeds) ----
        let font = NSFont.monospacedDigitSystemFont(ofSize: Self.fontSize, weight: .medium)
        let para = NSMutableParagraphStyle()
        para.alignment = .left
        para.lineBreakMode = .byClipping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(white: 1.0, alpha: 1.0),
            .paragraphStyle: para
        ]
        let labelPointSize = NSSize(width: labelWidth, height: Self.fontSize + 2)
        // CoreText draws upside-down due to our Y flip, so use NSString.draw
        // via NSGraphicsContext.push so the layout engine handles the flip.
        let labelOrigin = NSPoint(x: Self.donutDiameter + Self.gap,
                                  y: (contentH - labelPointSize.height) / 2)
        let labelRect = NSRect(origin: labelOrigin, size: labelPointSize)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        (labelText as NSString).draw(in: labelRect, withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()

        // `donutBox` retained for debugging / future center-text use.
        _ = donutBox

        guard let cg = ctx.makeImage() else { return }
        let img = NSImage(cgImage: cg, size: NSSize(width: contentW, height: contentH))
        // isTemplate = true tells AppKit to treat the bitmap as an alpha
        // mask and apply the system foreground tint (black in light mode,
        // white in dark mode). This is the macOS-standard way for menu-
        // bar icons to follow the user's appearance setting.
        img.isTemplate = true
        onImage(img, NSSize(width: contentW, height: contentH))
    }
}
