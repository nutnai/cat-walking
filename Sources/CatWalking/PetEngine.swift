import AppKit
import Combine
import Foundation

@MainActor
final class PetEngine: ObservableObject {
    enum Behavior: CaseIterable {
        case walkDown
        case walkLeft
        case walkRight
        case walkUp
        case idle
        case groom

        var spriteSequence: SpriteSequence {
            switch self {
            case .walkDown:
                return .walkDown
            case .walkLeft:
                return .walkLeft
            case .walkRight:
                return .walkRight
            case .walkUp:
                return .walkUp
            case .idle:
                return .idle
            case .groom:
                return .groom
            }
        }
    }

    private enum IdlePlaybackState {
        case inactive
        case entering
        case seated
        case exiting
    }

    private enum GroomPlaybackState {
        case inactive
        case active
    }

    @Published private(set) var currentFrame: NSImage
    @Published private(set) var contentSize: CGSize
    @Published private(set) var positionX: CGFloat
    @Published private(set) var behavior: Behavior
    @Published private(set) var manualBehaviorOverride: Behavior?

    private let settings: AppSettings
    private let spriteSheet: SpriteSheet
    private var animationTimer: Timer?
    private var movementTimer: Timer?
    private var behaviorTimer: Timer?
    private var screenFrame: CGRect
    private var currentFrameIndex = 0
    private var idlePlaybackState: IdlePlaybackState = .inactive
    private var groomPlaybackState: GroomPlaybackState = .inactive
    private var remainingGroomLoops = 0
    private var pendingBehaviorAfterIdleExit: Behavior?
    private var pendingBehaviorAfterIdleSit: Behavior?

    init(settings: AppSettings, spriteSheet: SpriteSheet) {
        self.settings = settings
        self.spriteSheet = spriteSheet
        self.screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        self.behavior = .idle
        self.manualBehaviorOverride = nil
        self.currentFrame = spriteSheet.frames(for: .idle).first ?? NSImage(size: spriteSheet.frameSize)
        self.contentSize = CGSize(width: spriteSheet.frameSize.width * settings.catScale, height: spriteSheet.frameSize.height * settings.catScale)
        self.positionX = 0

        positionX = max(0, (screenFrame.width - contentSize.width) / 2)
    }

    func start() {
        refreshContentSize()
        restartAnimationTimer()
        restartMovementTimer()
        chooseNextBehavior()
    }

    func stop() {
        animationTimer?.invalidate()
        movementTimer?.invalidate()
        behaviorTimer?.invalidate()
    }

    func updateScreenFrame(_ newFrame: CGRect) {
        screenFrame = newFrame
        clampPositionToVisibleRange()
    }

    func settingsDidChange() {
        refreshContentSize()
        restartAnimationTimer()
        reconcileBehaviorAvailability()
    }

    func setManualBehaviorOverride(_ behavior: Behavior?) {
        manualBehaviorOverride = behavior.flatMap { isBehaviorEnabled($0) ? $0 : nil }
        behaviorTimer?.invalidate()

        if let behavior = manualBehaviorOverride {
            applyBehavior(behavior)
            return
        }

        chooseNextBehavior()
    }

    var currentBehaviorDisplayName: String {
        switch behavior {
        case .walkDown:
            return "Walk Down"
        case .walkLeft:
            return "Walk Left"
        case .walkRight:
            return "Walk Right"
        case .walkUp:
            return "Walk Up"
        case .idle:
            return "Idle"
        case .groom:
            return "Groom"
        }
    }

    private func refreshContentSize() {
        contentSize = CGSize(
            width: spriteSheet.frameSize.width * settings.catScale,
            height: spriteSheet.frameSize.height * settings.catScale
        )
        clampPositionToVisibleRange()
        updateFrameImage()
    }

    private func restartAnimationTimer() {
        animationTimer?.invalidate()

        let interval = max(1.0 / max(settings.animationFPS, 1.0), 1.0 / 24.0)
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceAnimationFrame()
            }
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
    }

    private func restartMovementTimer() {
        movementTimer?.invalidate()

        movementTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceMovementFrame(deltaTime: 1.0 / 60.0)
            }
        }
        RunLoop.main.add(movementTimer!, forMode: .common)
    }

    private func advanceAnimationFrame() {
        let frames = spriteSheet.frames(for: behavior.spriteSequence)
        guard !frames.isEmpty else { return }

        if behavior == .idle {
            advanceIdleAnimationFrame(frames: frames)
            return
        }

        if behavior == .groom {
            advanceGroomAnimationFrame(frames: frames)
            return
        }

        currentFrameIndex = (currentFrameIndex + 1) % frames.count
        updateFrameImage()
    }

    private func advanceMovementFrame(deltaTime: TimeInterval) {
        let delta = CGFloat(settings.movementSpeed * deltaTime)

        switch behavior {
        case .walkDown:
            break
        case .walkLeft:
            positionX -= delta
            if positionX <= 0 {
                positionX = 0
                chooseNextBehavior(preferred: .walkRight)
            }
        case .walkRight:
            positionX += delta
            let maxX = maximumPositionX
            if positionX >= maxX {
                positionX = maxX
                chooseNextBehavior(preferred: .walkLeft)
            }
        case .walkUp, .idle, .groom:
            break
        }
    }

    private func chooseNextBehavior(preferred: Behavior? = nil) {
        behaviorTimer?.invalidate()

        if let manualBehaviorOverride, isBehaviorEnabled(manualBehaviorOverride) {
            transition(to: manualBehaviorOverride)
            return
        }

        let nextBehavior = nextAutomaticBehavior(preferred: preferred)
        transition(to: nextBehavior)
    }

    private func nextAutomaticBehavior(preferred: Behavior? = nil) -> Behavior {
        if behavior == .idle, idlePlaybackState == .seated {
            return nextBehaviorWhileSeated(preferred: preferred)
        }

        if let preferred, isBehaviorEnabled(preferred) {
            return preferred
        }

        let availableBehaviors = automaticBehaviorPool()
        return availableBehaviors.randomElement() ?? .idle
    }

    private func nextBehaviorWhileSeated(preferred: Behavior? = nil) -> Behavior {
        if let preferred {
            if preferred == .groom, isBehaviorEnabled(.groom) {
                return .groom
            }

            if preferred != .idle, isBehaviorEnabled(preferred) {
                return preferred
            }
        }

        if isBehaviorEnabled(.idle), Double.random(in: 0 ... 1) < seatedIdleHoldChance {
            return .idle
        }

        if isBehaviorEnabled(.groom), Bool.random() {
            return .groom
        }

        let standingBehaviors = [Behavior.walkDown, .walkLeft, .walkRight, .walkUp]
            .filter(isBehaviorEnabled)
        return standingBehaviors.randomElement() ?? .idle
    }

    private func automaticBehaviorPool() -> [Behavior] {
        if positionX <= 8 {
            return isBehaviorEnabled(.walkRight) ? [.walkRight] : fallbackBehaviors()
        }

        if positionX >= maximumPositionX - 8 {
            return isBehaviorEnabled(.walkLeft) ? [.walkLeft] : fallbackBehaviors()
        }

        var weightedBehaviors: [Behavior] = []

        if isBehaviorEnabled(.idle) {
            let idleWeight = max(1, Int(round(settings.sitPreference * 6)))
            weightedBehaviors.append(contentsOf: Array(repeating: .idle, count: idleWeight))
        }

        if isBehaviorEnabled(.walkLeft) {
            weightedBehaviors.append(.walkLeft)
        }

        if isBehaviorEnabled(.walkRight) {
            weightedBehaviors.append(.walkRight)
        }

        if isBehaviorEnabled(.walkDown) {
            weightedBehaviors.append(.walkDown)
        }

        if isBehaviorEnabled(.walkUp) {
            weightedBehaviors.append(.walkUp)
        }

        if isBehaviorEnabled(.groom) {
            weightedBehaviors.append(.groom)
        }

        return weightedBehaviors
    }

    private var seatedIdleHoldChance: Double {
        min(max(0.25 + settings.sitPreference * 0.5, 0), 0.95)
    }

    private var maximumPositionX: CGFloat {
        max(0, screenFrame.width - contentSize.width)
    }

    private func clampPositionToVisibleRange() {
        positionX = min(max(positionX, 0), maximumPositionX)
    }

    private func reconcileBehaviorAvailability() {
        if let manualBehaviorOverride, !isBehaviorEnabled(manualBehaviorOverride) {
            self.manualBehaviorOverride = nil
        }

        guard !isBehaviorEnabled(behavior) else {
            return
        }

        chooseNextBehavior()
    }

    private func fallbackBehaviors() -> [Behavior] {
        let enabled = Behavior.allCases.filter(isBehaviorEnabled)
        return enabled.isEmpty ? [.idle] : enabled
    }

    private func isBehaviorEnabled(_ behavior: Behavior) -> Bool {
        switch behavior {
        case .walkDown:
            return settings.enableWalkDown
        case .walkLeft:
            return settings.enableWalkLeft
        case .walkRight:
            return settings.enableWalkRight
        case .walkUp:
            return settings.enableWalkUp
        case .idle:
            return settings.enableIdle
        case .groom:
            return settings.enableGroom
        }
    }

    private func applyBehavior(_ newBehavior: Behavior) {
        behavior = newBehavior
        pendingBehaviorAfterIdleExit = nil

        if newBehavior == .idle {
            idlePlaybackState = .entering
            groomPlaybackState = .inactive
            remainingGroomLoops = 0
            currentFrameIndex = 0
        } else if newBehavior == .groom {
            idlePlaybackState = .seated
            groomPlaybackState = .active
            remainingGroomLoops = Int.random(in: 1 ... 5)
            currentFrameIndex = 0
        } else {
            idlePlaybackState = .inactive
            groomPlaybackState = .inactive
            remainingGroomLoops = 0
            currentFrameIndex = 0
        }

        updateFrameImage()
        scheduleBehaviorTimer(for: newBehavior)
    }

    private func updateFrameImage() {
        let frames = spriteSheet.frames(for: behavior.spriteSequence)
        guard !frames.isEmpty else { return }

        let safeIndex = min(currentFrameIndex, frames.count - 1)
        currentFrame = frames[safeIndex]
    }

    private func transition(to nextBehavior: Behavior) {
        if nextBehavior == .idle,
           behavior == .idle,
           idlePlaybackState == .seated {
            applySeatedIdleHold()
            return
        }

        if nextBehavior == .groom,
           behavior == .idle,
           idlePlaybackState == .seated {
            applyBehavior(.groom)
            return
        }

        if nextBehavior == .groom,
           behavior != .idle || idlePlaybackState != .seated {
            beginIdleEnterTransition(for: .groom)
            return
        }

        if behavior == .groom,
           nextBehavior != .groom {
            beginReturnToSeatedIdle(nextBehavior: nextBehavior)
            return
        }

        if behavior == .idle,
           nextBehavior != .idle,
           idlePlaybackState != .exiting {
            beginIdleExitTransition(to: nextBehavior)
            return
        }

        applyBehavior(nextBehavior)
    }

    private func beginIdleEnterTransition(for nextBehavior: Behavior) {
        pendingBehaviorAfterIdleSit = nextBehavior

        if behavior == .idle {
            if idlePlaybackState == .seated {
                let pending = pendingBehaviorAfterIdleSit
                pendingBehaviorAfterIdleSit = nil
                if let pending {
                    transition(to: pending)
                }
            } else if idlePlaybackState == .inactive || idlePlaybackState == .exiting {
                applyBehavior(.idle)
            }
            return
        }

        applyBehavior(.idle)
    }

    private func beginIdleExitTransition(to nextBehavior: Behavior) {
        let frames = spriteSheet.frames(for: .idle)
        guard !frames.isEmpty else {
            applyBehavior(nextBehavior)
            return
        }

        pendingBehaviorAfterIdleExit = nextBehavior
        idlePlaybackState = .exiting
        currentFrameIndex = min(currentFrameIndex, frames.count - 1)
        updateFrameImage()
    }

    private func advanceIdleAnimationFrame(frames: [NSImage]) {
        guard !frames.isEmpty else { return }

        switch idlePlaybackState {
        case .inactive:
            currentFrameIndex = min(currentFrameIndex, frames.count - 1)
        case .entering:
            if currentFrameIndex < frames.count - 1 {
                currentFrameIndex += 1
            } else {
                idlePlaybackState = .seated

                if let pendingBehaviorAfterIdleSit {
                    let pending = pendingBehaviorAfterIdleSit
                    self.pendingBehaviorAfterIdleSit = nil
                    transition(to: pending)
                    return
                }
            }
        case .seated:
            currentFrameIndex = frames.count - 1
        case .exiting:
            if currentFrameIndex > 0 {
                currentFrameIndex -= 1
            } else {
                idlePlaybackState = .inactive
                let nextBehavior = pendingBehaviorAfterIdleExit ?? nextAutomaticBehavior()
                pendingBehaviorAfterIdleExit = nil
                applyBehavior(nextBehavior)
                return
            }
        }

        updateFrameImage()
    }

    private func advanceGroomAnimationFrame(frames: [NSImage]) {
        guard !frames.isEmpty else { return }

        switch groomPlaybackState {
        case .inactive:
            currentFrameIndex = min(currentFrameIndex, frames.count - 1)
            updateFrameImage()
        case .active:
            if currentFrameIndex < frames.count - 1 {
                currentFrameIndex += 1
                updateFrameImage()
                return
            }

            if remainingGroomLoops > 1 {
                remainingGroomLoops -= 1
                currentFrameIndex = 0
                updateFrameImage()
                return
            }

            remainingGroomLoops = 0
            groomPlaybackState = .inactive
            applySeatedIdleHold()
        }
    }

    private func beginReturnToSeatedIdle(nextBehavior: Behavior) {
        pendingBehaviorAfterIdleSit = nextBehavior == .idle ? nil : nextBehavior
        applySeatedIdleHold()
    }

    private func applySeatedIdleHold() {
        let idleFrames = spriteSheet.frames(for: .idle)
        behavior = .idle
        idlePlaybackState = .seated
        groomPlaybackState = .inactive
        remainingGroomLoops = 0
        currentFrameIndex = max(0, idleFrames.count - 1)
        updateFrameImage()
        scheduleBehaviorTimer(for: .idle)
    }

    private func scheduleBehaviorTimer(for behavior: Behavior) {
        let duration: ClosedRange<Double>
        switch behavior {
        case .walkDown:
            duration = 1.8 ... 3.0
        case .walkLeft, .walkRight:
            duration = 2.5 ... 5.0
        case .walkUp:
            duration = 1.8 ... 3.0
        case .idle:
            duration = 2.0 ... 4.0
        case .groom:
            duration = 0.6 ... 0.6
        }

        behaviorTimer?.invalidate()
        behaviorTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: duration), repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.chooseNextBehavior()
            }
        }
        RunLoop.main.add(behaviorTimer!, forMode: .common)
    }
}
