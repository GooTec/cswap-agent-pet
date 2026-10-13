import AppKit
import ImageIO

@MainActor
class PixelPetView: NSView {
    var remainingPercent: Double? {
        didSet {
            guard remainingPercent != oldValue else { return }
            updateAccessibility()
            needsDisplay = true
        }
    }

    var character: PetCharacter = .chiikawa {
        didSet {
            guard character != oldValue else { return }
            updateAccessibility()
            needsDisplay = true
        }
    }

    var animationEnabled = true {
        didSet { updateAnimationTimer() }
    }

    private var animationTimer: Timer?
    private var animationFrame = 0
    private static let spriteSize = CGSize(width: 64, height: 80)
    private static let shadow = CGColor(srgbRed: 0.39, green: 0.30, blue: 0.31, alpha: 0.12)
    private static let frames: [PetCharacter: [CGImage]] = loadFrames()

    private static func loadFrames() -> [PetCharacter: [CGImage]] {
        var sprites: [PetCharacter: [CGImage]] = [:]
        for character in PetCharacter.allCases {
            guard let url = Bundle.module.url(forResource: character.rawValue, withExtension: "png"),
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  atlas.width == 512, atlas.height == 480 else {
                fatalError("Missing or invalid bundled sprite: \(character.rawValue)")
            }
            var characterFrames: [CGImage] = []
            characterFrames.reserveCapacity(48)
            for row in 0..<6 {
                for column in 0..<8 {
                    let rectangle = CGRect(x: column * 64, y: row * 80, width: 64, height: 80)
                    guard let frame = atlas.cropping(to: rectangle) else {
                        fatalError("Invalid sprite frame: \(character.rawValue)")
                    }
                    characterFrames.append(frame)
                }
            }
            sprites[character] = characterFrames
        }
        return sprites
    }

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
        toolTip = "클릭: 사용량 · 드래그: 이동 · 우클릭: 펫 종류"
        setAccessibilityHelp(toolTip)
        updateAccessibility()
    }

    private func updateAccessibility() {
        let mood = PetMood.forRemaining(remainingPercent)
        if let remainingPercent {
            let percent = remainingPercent.formatted(.number.precision(.fractionLength(0...1)))
            setAccessibilityLabel("\(character.name), 잔여량 \(percent)퍼센트. \(mood.caption)")
        } else {
            setAccessibilityLabel("\(character.name), 잔여량을 아직 몰라요. \(mood.caption)")
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let graphics = NSGraphicsContext.current else { return }
        let context = graphics.cgContext
        context.clear(bounds)
        let backingScale = window?.backingScaleFactor ?? 2
        let fit = min(bounds.width / Self.spriteSize.width, bounds.height / Self.spriteSize.height)
        let scale = floor(fit * backingScale) / backingScale
        guard scale > 0 else { return }
        let originX = ((bounds.width - Self.spriteSize.width * scale) / 2 * backingScale).rounded() / backingScale
        let originY = ((bounds.height - Self.spriteSize.height * scale) / 2 * backingScale).rounded() / backingScale
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.interpolationQuality = .none
        context.translateBy(x: originX, y: originY)
        context.scaleBy(x: scale, y: scale)
        context.setFillColor(Self.shadow)
        context.fill(CGRect(x: 22, y: 77, width: 20, height: 1))
        context.fill(CGRect(x: 18, y: 78, width: 28, height: 1))

        let mood = PetMood.forRemaining(remainingPercent)
        let row: Int
        switch mood {
        case .delighted: row = 0
        case .happy: row = 1
        case .uneasy: row = 2
        case .sad: row = 3
        case .crying: row = 4
        case .unknown: row = 5
        }
        let column: Int
        if mood == .crying {
            column = (animationFrame / 3) % 8
        } else if animationFrame % 40 >= 38 {
            column = 6 + animationFrame % 2
        } else {
            column = animationFrame % 6
        }
        let bob = (animationFrame / 8) % 4 == 2 ? -1 : 0
        context.translateBy(x: 0, y: CGFloat(bob) + Self.spriteSize.height)
        context.scaleBy(x: 1, y: -1)
        let frame = Self.frames[character]![row * 8 + column]
        context.draw(frame, in: CGRect(origin: .zero, size: Self.spriteSize))
    }
}
