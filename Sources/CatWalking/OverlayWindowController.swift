import AppKit
import Combine
import SwiftUI

@MainActor
final class OverlayWindowController {
    private let engine: PetEngine
    private let settings: AppSettings
    private let window: NSWindow
    private var cancellables: Set<AnyCancellable> = []

    init(engine: PetEngine, settings: AppSettings) {
        self.engine = engine
        self.settings = settings

        let initialRect = CGRect(origin: .zero, size: engine.contentSize)
        window = NSWindow(
            contentRect: initialRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        let rootView = PetView(engine: engine)
        let hostingView = NSHostingView(rootView: rootView)

        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.level = settings.stayOnTop ? .floating : .normal
        window.isReleasedWhenClosed = false
        window.setFrame(initialRect, display: false)

        bind()
        observeScreenChanges()
        updateScreenFrame()
        layoutWindow()
    }

    func show() {
        window.orderFrontRegardless()
    }

    private func bind() {
        engine.$positionX
            .sink { [weak self] _ in
                self?.layoutWindow()
            }
            .store(in: &cancellables)

        engine.$positionY
            .sink { [weak self] _ in
                self?.layoutWindow()
            }
            .store(in: &cancellables)

        engine.$contentSize
            .sink { [weak self] _ in
                self?.layoutWindow()
            }
            .store(in: &cancellables)

        settings.$stayOnTop
            .sink { [weak self] isOnTop in
                self?.window.level = isOnTop ? .floating : .normal
                self?.window.orderFrontRegardless()
            }
            .store(in: &cancellables)

        settings.$catScale
            .sink { [weak self] _ in
                self?.engine.settingsDidChange()
            }
            .store(in: &cancellables)

        settings.$selectedCatTemplate
            .sink { [weak self] templateName in
                guard let self else { return }
                self.engine.reloadSpriteSheet(SpriteSheet.load(templateName: templateName))
                self.layoutWindow()
            }
            .store(in: &cancellables)

        settings.$animationFPS
            .sink { [weak self] _ in
                self?.engine.settingsDidChange()
            }
            .store(in: &cancellables)

        settings.$movementSpeed
            .sink { [weak self] _ in
                self?.engine.settingsDidChange()
            }
            .store(in: &cancellables)

        settings.$enableVerticalMovement
            .sink { [weak self] _ in
                self?.engine.settingsDidChange()
            }
            .store(in: &cancellables)

        settings.$defaultYOffset
            .sink { [weak self] _ in
                self?.engine.settingsDidChange()
            }
            .store(in: &cancellables)

        settings.$verticalMovementRange
            .sink { [weak self] _ in
                self?.engine.settingsDidChange()
            }
            .store(in: &cancellables)

        settings.$sitPreference
            .sink { [weak self] _ in
                self?.engine.settingsDidChange()
            }
            .store(in: &cancellables)

        settings.$enableWalkLeft
            .sink { [weak self] _ in
                self?.engine.settingsDidChange()
            }
            .store(in: &cancellables)

        settings.$enableWalkDown
            .sink { [weak self] _ in
                self?.engine.settingsDidChange()
            }
            .store(in: &cancellables)

        settings.$enableWalkRight
            .sink { [weak self] _ in
                self?.engine.settingsDidChange()
            }
            .store(in: &cancellables)

        settings.$enableWalkUp
            .sink { [weak self] _ in
                self?.engine.settingsDidChange()
            }
            .store(in: &cancellables)

        settings.$enableIdle
            .sink { [weak self] _ in
                self?.engine.settingsDidChange()
            }
            .store(in: &cancellables)

        settings.$enableGroom
            .sink { [weak self] _ in
                self?.engine.settingsDidChange()
            }
            .store(in: &cancellables)
    }

    private func observeScreenChanges() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.updateScreenFrame()
                self?.layoutWindow()
            }
            .store(in: &cancellables)
    }

    private func updateScreenFrame() {
        let frame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 2560, height: 1600)
        engine.updateScreenFrame(frame)
    }

    private func layoutWindow() {
        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 2560, height: 1600)
        let size = engine.contentSize
        let origin = CGPoint(
            x: screenFrame.minX + engine.positionX,
            y: screenFrame.minY + engine.positionY
        )
        let frame = CGRect(origin: origin, size: size)
        window.setFrame(frame, display: true)
    }
}
