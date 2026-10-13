import AppKit
import Combine
import SwiftUI

@main
struct ChiikawaPetApp {
    @MainActor
    static func main() async {
        let arguments = CommandLine.arguments
        if arguments.contains("--usage") {
            let usageClient = UsageClient()
            for provider in UsageProvider.allCases {
                do {
                    let reading = try await usageClient.fetch(provider, allowKeychainPrompt: false)
                    for window in reading.windows {
                        print("\(provider.rawValue) · \(window.title): \(window.remainingPercent)% remaining")
                    }
                } catch {
                    print("\(provider.rawValue): \(error.localizedDescription)")
                }
            }
            return
        }
        var previewPercent: Double?
        if let index = arguments.firstIndex(of: "--preview") {
            guard arguments.indices.contains(index + 1),
                  let percent = Double(arguments[index + 1]), percent.isFinite,
                  (0...100).contains(percent) else {
                fputs("--preview requires a remaining percentage from 0 to 100\n", stderr)
                exit(64)
            }
            previewPercent = percent
        }
        let application = NSApplication.shared
        let delegate = PetAppDelegate(previewPercent: previewPercent, showUsageOnLaunch: arguments.contains("--show-usage"))
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        runApplication(application, keeping: delegate)
    }

    @MainActor
    private static func runApplication(_ application: NSApplication, keeping delegate: PetAppDelegate) {
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class PetAppDelegate: NSObject, NSApplicationDelegate {
    private let store: UsageStore
    private let showUsageOnLaunch: Bool
    private var petWindow: NSPanel!
    private var usageWindow: NSPanel?
    private var petView: DraggablePetView!
    private var statusItem: NSStatusItem!
    private var animationTimer: Timer?
    private var refreshTimer: Timer?
    private var observation: AnyCancellable?
    private var clickMonitor: Any?
    private var direction: CGFloat = -1
    private var isDragging = false

    init(previewPercent: Double?, showUsageOnLaunch: Bool) {
        store = UsageStore(usageFetching: UsageClient(), previewPercent: previewPercent)
        self.showUsageOnLaunch = showUsageOnLaunch
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let saved = UserDefaults.standard
        let origin = saved.object(forKey: "petX") == nil
            ? NSPoint(x: screen.maxX - 190, y: screen.minY + 55)
            : NSPoint(x: saved.double(forKey: "petX"), y: saved.double(forKey: "petY"))
        petWindow = NSPanel(contentRect: NSRect(origin: origin, size: NSSize(width: 148, height: 164)), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        petWindow.title = "치이카와 펫"
        petWindow.setAccessibilityRole(.window)
        petWindow.setAccessibilitySubrole(.floatingWindow)
        petWindow.level = .floating
        petWindow.isOpaque = false
        petWindow.backgroundColor = .clear
        petWindow.hasShadow = false
        petWindow.hidesOnDeactivate = false
        petWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        petWindow.isReleasedWhenClosed = false
        petView = DraggablePetView(frame: NSRect(origin: .zero, size: petWindow.frame.size))
        petView.owner = self
        petView.remainingPercent = store.remainingPercent
        petWindow.contentView = petView
        constrainPetToScreens()
        petWindow.orderFrontRegardless()
        observation = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.petView.remainingPercent = self.store.remainingPercent
                self.statusItem.button?.toolTip = "치이카와 · \(self.store.remainingPercent.map { "\(Int($0.rounded(.down)))% 남음" } ?? "연결 필요")"
            }
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "치이카와 펫")
        statusItem.menu = makeMenu()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.walk() }
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.store.refresh() }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(screenChanged), name: NSWorkspace.didWakeNotification, object: nil)
        Task { await store.refresh() }
        if showUsageOnLaunch { toggleUsage() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        animationTimer?.invalidate()
        refreshTimer?.invalidate()
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        savePosition()
    }

    func beginDragging() { isDragging = true }
    func endDragging() { isDragging = false; constrainPetToScreens(); savePosition() }

    func movePet(to origin: NSPoint) {
        petWindow.setFrameOrigin(origin)
        constrainPetToScreens()
    }

    @objc func toggleUsage() {
        if usageWindow?.isVisible == true { closeUsage(); return }
        let hostingView = NSHostingView(rootView: UsagePanel(store: store))
        let fitting = hostingView.fittingSize
        let screen = petWindow.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        let height = min(max(fitting.height, 420), screen.height - 24)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: height), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "치이카와 사용량"
        panel.setAccessibilityRole(.window)
        panel.setAccessibilitySubrole(.floatingWindow)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = hostingView
        let pet = petWindow.frame
        let preferredX = pet.midX - 180
        let x = min(max(preferredX, screen.minX + 12), screen.maxX - 372)
        let above = pet.maxY + 8
        let y = above + height <= screen.maxY - 12 ? above : max(screen.minY + 12, pet.minY - height - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        usageWindow = panel
        panel.orderFrontRegardless()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let mouse = NSEvent.mouseLocation
                if self.usageWindow?.frame.contains(mouse) != true && !self.petWindow.frame.contains(mouse) {
                    self.closeUsage()
                }
            }
        }
    }

    func closeUsage() {
        usageWindow?.close()
        usageWindow = nil
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor); self.clickMonitor = nil }
    }

    func showContextMenu(with event: NSEvent) { NSMenu.popUpContextMenu(makeMenu(), with: event, for: petView) }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "치이카와 · 사용량 보기", action: #selector(toggleUsage), keyEquivalent: "")
        menu.addItem(withTitle: "사용량 새로고침 / 연결", action: #selector(refreshUsage), keyEquivalent: "")
        menu.addItem(.separator())
        let wander = menu.addItem(withTitle: "느긋하게 산책하기", action: #selector(toggleWandering), keyEquivalent: "")
        wander.state = store.wanders ? .on : .off
        menu.addItem(withTitle: "화면 가운데로 데려오기", action: #selector(centerPet), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "치이카와 종료", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        return menu
    }

    @objc private func refreshUsage() { Task { await store.refresh(allowKeychainPrompt: true) } }
    @objc private func toggleWandering() { store.wanders.toggle(); statusItem.menu = makeMenu() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func centerPet() {
        let screen = NSScreen.main?.visibleFrame ?? petWindow.frame
        movePet(to: NSPoint(x: screen.midX - 74, y: screen.minY + 60))
        savePosition()
    }
    @objc private func screenChanged() { constrainPetToScreens(); closeUsage() }

    private func walk() {
        guard store.wanders, !isDragging, usageWindow == nil,
              !NSEvent.mouseLocation.isNear(petWindow.frame, padding: 24) else { return }
        let screen = petWindow.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        var origin = petWindow.frame.origin
        origin.x += direction * 0.65
        if origin.x < screen.minX + 12 { origin.x = screen.minX + 12; direction = 1 }
        if origin.x + petWindow.frame.width > screen.maxX - 12 {
            origin.x = screen.maxX - petWindow.frame.width - 12; direction = -1
        }
        petWindow.setFrameOrigin(origin)
    }

    private func constrainPetToScreens() {
        let frames = NSScreen.screens.map(\.visibleFrame)
        guard let fallback = frames.first else { return }
        let frame = petWindow.frame
        let screen = frames.first { $0.intersects(frame) } ?? fallback
        let x = min(max(frame.minX, screen.minX), screen.maxX - frame.width)
        let y = min(max(frame.minY, screen.minY), screen.maxY - frame.height)
        petWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func savePosition() {
        UserDefaults.standard.set(petWindow.frame.minX, forKey: "petX")
        UserDefaults.standard.set(petWindow.frame.minY, forKey: "petY")
    }
}

@MainActor
final class DraggablePetView: PixelPetView {
    weak var owner: PetAppDelegate?
    private var clickLocation = NSPoint.zero
    private var originalOrigin = NSPoint.zero
    private var dragged = false

    override func mouseDown(with event: NSEvent) {
        clickLocation = NSEvent.mouseLocation
        originalOrigin = window?.frame.origin ?? .zero
        dragged = false
        owner?.beginDragging()
    }
    override func mouseDragged(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        let deltaX = mouse.x - clickLocation.x
        let deltaY = mouse.y - clickLocation.y
        if hypot(deltaX, deltaY) > 3 {
            dragged = true
            owner?.closeUsage()
        }
        owner?.movePet(to: NSPoint(x: originalOrigin.x + deltaX, y: originalOrigin.y + deltaY))
    }
    override func mouseUp(with event: NSEvent) {
        owner?.endDragging()
        if !dragged { owner?.toggleUsage() }
    }
    override func rightMouseDown(with event: NSEvent) { owner?.showContextMenu(with: event) }
    override func accessibilityPerformPress() -> Bool { owner?.toggleUsage(); return true }
}

private extension NSPoint {
    func isNear(_ rectangle: NSRect, padding: CGFloat) -> Bool {
        rectangle.insetBy(dx: -padding, dy: -padding).contains(self)
    }
}
