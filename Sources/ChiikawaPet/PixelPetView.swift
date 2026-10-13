import AppKit

@MainActor
class PixelPetView: NSView {
    var remainingPercent: Double? {
        didSet {
            updateAccessibility()
            needsDisplay = true
        }
    }

    var animationEnabled = true {
        didSet {
            updateAnimationTimer()
            needsDisplay = true
        }
    }

    private var animationTimer: Timer?
    private var animationFrame = 0
    private static let gridWidth: CGFloat = 48
    private static let gridHeight: CGFloat = 52
    private static let ink = NSColor(srgbRed: 0.29, green: 0.23, blue: 0.22, alpha: 1)
    private static let cream = NSColor(srgbRed: 1, green: 0.985, blue: 0.94, alpha: 1)
    private static let shade = NSColor(srgbRed: 0.94, green: 0.89, blue: 0.81, alpha: 1)
    private static let pink = NSColor(srgbRed: 1, green: 0.70, blue: 0.73, alpha: 1)
    private static let blush = NSColor(srgbRed: 1, green: 0.82, blue: 0.80, alpha: 1)
    private static let blue = NSColor(srgbRed: 0.36, green: 0.72, blue: 0.96, alpha: 1)
    private static let paleBlue = NSColor(srgbRed: 0.73, green: 0.90, blue: 1, alpha: 1)
    private static let shadow = NSColor(srgbRed: 0.38, green: 0.30, blue: 0.27, alpha: 0.12)

    private static let bodyOutline: [NSRect] = [
        NSRect(x: 16, y: 11, width: 16, height: 1),
        NSRect(x: 12, y: 12, width: 24, height: 1),
        NSRect(x: 9, y: 13, width: 30, height: 2),
        NSRect(x: 7, y: 15, width: 34, height: 3),
        NSRect(x: 5, y: 18, width: 38, height: 5),
        NSRect(x: 4, y: 23, width: 40, height: 9),
        NSRect(x: 5, y: 32, width: 38, height: 4),
        NSRect(x: 7, y: 36, width: 34, height: 3),
        NSRect(x: 10, y: 39, width: 28, height: 2),
        NSRect(x: 15, y: 41, width: 18, height: 2)
    ]
    private static let bodyFill: [NSRect] = [
        NSRect(x: 17, y: 12, width: 14, height: 1),
        NSRect(x: 13, y: 13, width: 22, height: 1),
        NSRect(x: 10, y: 14, width: 28, height: 2),
        NSRect(x: 8, y: 16, width: 32, height: 3),
        NSRect(x: 6, y: 19, width: 36, height: 4),
        NSRect(x: 5, y: 23, width: 38, height: 9),
        NSRect(x: 6, y: 32, width: 36, height: 3),
        NSRect(x: 8, y: 35, width: 32, height: 3),
        NSRect(x: 11, y: 38, width: 26, height: 2),
        NSRect(x: 16, y: 40, width: 16, height: 2)
    ]

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureAccessibility()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAccessibility()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateAnimationTimer()
    }

    func advanceFrame() {
        animationFrame = (animationFrame + 1) % 120
        needsDisplay = true
    }

    private func updateAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
        guard window != nil, animationEnabled else { return }
        let timer = Timer(timeInterval: 0.14, repeats: true) { [weak self] timer in
            let hasView = MainActor.assumeIsolated {
                guard let self else { return false }
                self.advanceFrame()
                return true
            }
            if !hasView { timer.invalidate() }
        }
        animationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func configureAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        toolTip = "클릭하면 사용량을 확인하고, 드래그하면 위치를 옮겨요."
        setAccessibilityHelp(toolTip)
        updateAccessibility()
    }

    private func updateAccessibility() {
        let mood = PetMood.forRemaining(remainingPercent)
        if let remainingPercent, remainingPercent.isFinite {
            let percent = remainingPercent.formatted(.number.precision(.fractionLength(0...1)))
            setAccessibilityLabel("치이카와, 잔여량 \(percent)퍼센트. \(mood.caption)")
        } else {
            setAccessibilityLabel("치이카와, 잔여량을 아직 몰라요. \(mood.caption)")
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let graphics = NSGraphicsContext.current else { return }
        let context = graphics.cgContext
        context.clear(bounds)
        guard bounds.width > 0, bounds.height > 0 else { return }
        let backingScale = window?.backingScaleFactor ?? 2
        let fit = min(bounds.width / Self.gridWidth, bounds.height / Self.gridHeight)
        let scale = floor(fit * backingScale) / backingScale
        guard scale > 0 else { return }
        let originX = (bounds.minX + (bounds.width - Self.gridWidth * scale) / 2) * backingScale
        let originY = (bounds.minY + (bounds.height - Self.gridHeight * scale) / 2) * backingScale
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        graphics.shouldAntialias = false
        context.setShouldAntialias(false)
        context.translateBy(x: originX.rounded() / backingScale, y: originY.rounded() / backingScale)
        context.scaleBy(x: scale, y: scale)

        Self.shadow.setFill()
        pixel(13, 47, 22, 1)
        pixel(9, 48, 30, 2)
        pixel(13, 50, 22, 1)

        let mood = PetMood.forRemaining(remainingPercent)
        let bob = (animationFrame / 7) % 4 == 2 ? -1 : 0
        let shake = mood == .crying ? (animationFrame % 4 == 0 ? -1 : (animationFrame % 4 == 2 ? 1 : 0)) : 0
        context.translateBy(x: CGFloat(shake), y: CGFloat(bob))
        drawEar(at: 9)
        drawEar(at: 29)
        drawFeet()
        Self.ink.setFill()
        for rectangle in Self.bodyOutline { NSBezierPath.fill(rectangle) }
        Self.cream.setFill()
        for rectangle in Self.bodyFill { NSBezierPath.fill(rectangle) }
        drawBodyDetails()
        drawFace(mood)
        if mood == .unknown { drawQuestion() }
        if mood == .delighted {
            drawSparkle(x: 1, y: 14 + (animationFrame / 4) % 2)
            drawSparkle(x: 42, y: 10 - (animationFrame / 4) % 2)
        }
    }

    private func pixel(_ x: Int, _ y: Int, _ width: Int = 1, _ height: Int = 1) {
        let rectangle = NSRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
        NSBezierPath.fill(rectangle)
    }

    private func drawEar(at x: Int) {
        Self.ink.setFill()
        pixel(x + 3, 5, 4, 1)
        pixel(x + 1, 6, 8, 2)
        pixel(x, 8, 10, 5)
        pixel(x + 1, 13, 8, 2)
        Self.cream.setFill()
        pixel(x + 3, 6, 4, 1)
        pixel(x + 2, 7, 6, 1)
        pixel(x + 1, 8, 8, 5)
        pixel(x + 2, 13, 6, 1)
        Self.pink.setFill()
        pixel(x + 3, 8, 4, 1)
        pixel(x + 2, 9, 6, 3)
        pixel(x + 3, 12, 4, 1)
    }

    private func drawFeet() {
        Self.ink.setFill()
        pixel(14, 40, 7, 5)
        pixel(15, 45, 5, 1)
        pixel(27, 40, 7, 5)
        pixel(28, 45, 5, 1)
        Self.cream.setFill()
        pixel(15, 40, 5, 4)
        pixel(28, 40, 5, 4)
        Self.shade.setFill()
        pixel(16, 44, 3, 1)
        pixel(29, 44, 3, 1)
    }

    private func drawBodyDetails() {
        Self.shade.setFill()
        pixel(9, 37, 2, 1)
        pixel(11, 39, 5, 1)
        pixel(16, 40, 16, 1)
        pixel(32, 39, 5, 1)
        pixel(37, 37, 2, 1)
        Self.ink.setFill()
        pixel(7, 32, 1, 3)
        pixel(8, 35, 3, 1)
        pixel(10, 32, 1, 3)
        pixel(37, 32, 1, 3)
        pixel(38, 35, 3, 1)
        pixel(40, 32, 1, 3)
        Self.blush.setFill()
        pixel(8, 28, 7, 2)
        pixel(9, 27, 5, 4)
        pixel(33, 28, 7, 2)
        pixel(34, 27, 5, 4)
        Self.pink.setFill()
        pixel(10, 28, 1, 2)
        pixel(12, 28, 1, 2)
        pixel(35, 28, 1, 2)
        pixel(37, 28, 1, 2)
    }

    private func drawFace(_ mood: PetMood) {
        Self.ink.setFill()
        let blinking = animationFrame % 36 >= 34
        if mood == .delighted {
            smilingEye(at: 13)
            smilingEye(at: 29)
        } else if mood == .crying {
            pixel(13, 23, 2, 1)
            pixel(15, 24, 3, 1)
            pixel(12, 25, 3, 1)
            pixel(33, 23, 2, 1)
            pixel(30, 24, 3, 1)
            pixel(33, 25, 3, 1)
            pixel(12, 20, 3, 1)
            pixel(15, 19, 3, 1)
            pixel(30, 19, 3, 1)
            pixel(33, 20, 3, 1)
        } else if blinking {
            pixel(13, 25, 6, 1)
            pixel(29, 25, 6, 1)
        } else {
            openEye(at: 13)
            openEye(at: 29)
        }

        Self.ink.setFill()
        if mood == .uneasy || mood == .sad {
            pixel(13, 20, 3, 1)
            pixel(16, 19, 3, 1)
            pixel(29, 19, 3, 1)
            pixel(32, 20, 3, 1)
        }
        pixel(23, 27, 2, 1)
        switch mood {
        case .delighted:
            pixel(20, 30, 1, 2)
            pixel(27, 30, 1, 2)
            pixel(21, 32, 6, 1)
            pixel(22, 33, 4, 1)
            Self.pink.setFill()
            pixel(22, 31, 4, 1)
            pixel(23, 32, 2, 1)
        case .happy:
            pixel(20, 30, 1, 1)
            pixel(21, 31, 2, 1)
            pixel(23, 30, 2, 1)
            pixel(25, 31, 2, 1)
            pixel(27, 30, 1, 1)
        case .unknown:
            pixel(23, 30, 2, 1)
            pixel(22, 31, 1, 2)
            pixel(25, 31, 1, 2)
            pixel(23, 33, 2, 1)
        case .uneasy:
            pixel(22, 31, 4, 1)
            pixel(26, 30, 1, 1)
        case .sad:
            pixel(22, 30, 4, 1)
            pixel(21, 31, 1, 1)
            pixel(26, 31, 1, 1)
        case .crying:
            let sob = animationFrame % 3 == 0 ? 1 : 0
            pixel(22, 30, 4, 1)
            pixel(21, 31, 6, 3 + sob)
            pixel(22, 34 + sob, 4, 1)
            Self.pink.setFill()
            pixel(22, 33 + sob, 4, 1)
            drawTears()
        }
    }

    private func openEye(at x: Int) {
        Self.ink.setFill()
        pixel(x + 1, 22, 4, 1)
        pixel(x, 23, 6, 3)
        pixel(x + 1, 26, 4, 1)
        Self.cream.setFill()
        pixel(x + 1, 23, 2, 1)
        pixel(x + 4, 25, 1, 1)
    }

    private func smilingEye(at x: Int) {
        pixel(x + 2, 22, 2, 1)
        pixel(x + 1, 23, 1, 1)
        pixel(x + 4, 23, 1, 1)
        pixel(x, 24, 1, 2)
        pixel(x + 5, 24, 1, 2)
    }

    private func drawTears() {
        let flow = animationFrame % 6
        Self.blue.setFill()
        pixel(13, 26, 3, 10 + flow / 2)
        pixel(32, 26, 3, 11 + (flow + 3) % 6 / 2)
        pixel(12, 28 + flow, 1, 3)
        pixel(35, 28 + (flow + 3) % 6, 1, 3)
        let leftDrop = 39 + flow
        let rightDrop = 39 + (flow + 3) % 6
        pixel(14, leftDrop, 1, 1)
        pixel(13, leftDrop + 1, 3, 2)
        pixel(14, leftDrop + 3, 1, 1)
        pixel(33, rightDrop, 1, 1)
        pixel(32, rightDrop + 1, 3, 2)
        pixel(33, rightDrop + 3, 1, 1)
        Self.paleBlue.setFill()
        pixel(14, 27, 1, 8 + flow / 2)
        pixel(33, 27, 1, 9 + (flow + 3) % 6 / 2)
        pixel(14, leftDrop + 1, 1, 1)
        pixel(33, rightDrop + 1, 1, 1)
    }

    private func drawQuestion() {
        Self.ink.setFill()
        pixel(42, 2, 3, 1)
        pixel(41, 3, 1, 1)
        pixel(45, 3, 1, 2)
        pixel(43, 5, 2, 1)
        pixel(43, 6, 1, 1)
        pixel(43, 8, 1, 1)
    }

    private func drawSparkle(x: Int, y: Int) {
        Self.pink.setFill()
        pixel(x + 2, y, 1, 2)
        pixel(x, y + 2, 5, 1)
        pixel(x + 2, y + 3, 1, 2)
        Self.cream.setFill()
        pixel(x + 2, y + 2, 1, 1)
    }
}
