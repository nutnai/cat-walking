import AppKit
import Combine
import Foundation

@MainActor
final class PetEngine: ObservableObject {
    private static let groomLoopStartFrame = 1
    private static let groomLoopEndFrame = 3
    private static let sleepLoopStartFrame = 0
    private static let sleepLoopEndFrame = 1
    private static let sleepFrameAdvanceDivisor = 4
    private static let speechBubbleSpacing: CGFloat = 1
    private static let speechBubbleHorizontalPadding: CGFloat = 14
    private static let speechBubbleVerticalPadding: CGFloat = 10
    private static let speechBubbleMinimumWidth: CGFloat = 120
    private static let speechBubbleMaximumWidthRatio: CGFloat = 2.4
    private static let speechBubbleMinimumInterval: ClosedRange<Double> = 1.0 ... 3.0

    private struct PreferredBehaviorOption {
        let behavior: Behavior
        let chance: Double

        init(_ behavior: Behavior, chance: Double = 1.0) {
            self.behavior = behavior
            self.chance = min(max(chance, 0), 1)
        }
    }

    struct RandomSource: Sendable {
        let nextUnitDouble: @Sendable () -> Double
        let nextBool: @Sendable () -> Bool
        let randomDuration: @Sendable (ClosedRange<Double>) -> Double

        static let live = RandomSource(
            nextUnitDouble: { Double.random(in: 0 ... 1) },
            nextBool: { Bool.random() },
            randomDuration: { Double.random(in: $0) }
        )
    }

    enum Behavior: CaseIterable {
        case walkDown
        case walkLeft
        case walkRight
        case walkUp
        case idle
        case groom
        case layDown
        case sleep
        case extraTwo

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
            case .layDown:
                return .layDown
            case .sleep:
                return .sleep
            case .extraTwo:
                return .extraTwo
            }
        }
    }

    private static let automaticBehaviors: [Behavior] = [
        .walkDown,
        .walkLeft,
        .walkRight,
        .walkUp,
        .idle,
        .groom
    ]

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

    private enum SleepPlaybackState {
        case inactive
        case enteringFromLayDown
        case enteringFromStanding
        case sleeping
    }

    @Published private(set) var currentFrame: NSImage
    @Published private(set) var contentSize: CGSize
    @Published private(set) var petSize: CGSize
    @Published private(set) var positionX: CGFloat
    @Published private(set) var positionY: CGFloat
    @Published private(set) var behavior: Behavior
    @Published private(set) var manualBehaviorOverride: Behavior?
    @Published private(set) var speechBubbleText: String?
    @Published private(set) var speechBubbleColor: NSColor
    @Published private(set) var speechBubbleTextColor: NSColor

    private let settings: AppSettings
    private var spriteSheet: SpriteSheet
    private let randomSource: RandomSource
    private var animationTimer: Timer?
    private var movementTimer: Timer?
    private var behaviorTimer: Timer?
    private var speechBubbleTimer: Timer?
    private var screenFrame: CGRect
    private var currentFrameIndex = 0
    private var idlePlaybackState: IdlePlaybackState = .inactive
    private var groomPlaybackState: GroomPlaybackState = .inactive
    private var sleepPlaybackState: SleepPlaybackState = .inactive
    private var sleepFrameAdvanceCountdown = 0
    private var remainingGroomLoops = 0
    private var sleepEndDate: Date?
    private var pendingBehaviorAfterIdleExit: Behavior?
    private var pendingBehaviorAfterIdleSit: Behavior?

    init(settings: AppSettings, spriteSheet: SpriteSheet, randomSource: RandomSource = .live) {
        let initialPetSize = CGSize(
            width: spriteSheet.frameSize.width * settings.catScale,
            height: spriteSheet.frameSize.height * settings.catScale
        )
        let initialSpeechBubbleColor = settings.speechBubbleColor
        let initialSpeechBubbleTextColor: NSColor = {
            let convertedColor = initialSpeechBubbleColor.usingColorSpace(.deviceRGB) ?? initialSpeechBubbleColor
            let brightness = ((convertedColor.redComponent * 299) + (convertedColor.greenComponent * 587) + (convertedColor.blueComponent * 114)) / 1000
            return brightness > 0.6 ? .black : .white
        }()

        self.settings = settings
        self.spriteSheet = spriteSheet
        self.randomSource = randomSource
        self.screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 2560, height: 1600)
        self.behavior = .idle
        self.manualBehaviorOverride = nil
        self.currentFrame = spriteSheet.frames(for: .idle).first ?? NSImage(size: spriteSheet.frameSize)
        self.petSize = initialPetSize
        self.contentSize = initialPetSize
        self.positionX = 0
        self.positionY = 0
        self.speechBubbleText = nil
        self.speechBubbleColor = initialSpeechBubbleColor
        self.speechBubbleTextColor = initialSpeechBubbleTextColor

        positionX = max(0, (screenFrame.width - contentSize.width) / 2)
        positionY = clampedPositionY(settings.defaultYOffset)
        refreshSpeechBubbleStyle()
    }

    func start() {
        refreshContentSize()
        restartAnimationTimer()
        restartMovementTimer()
        restartSpeechBubbleCycle()
        chooseNextBehavior()
    }

    func stop() {
        animationTimer?.invalidate()
        movementTimer?.invalidate()
        behaviorTimer?.invalidate()
        speechBubbleTimer?.invalidate()
    }

    func updateScreenFrame(_ newFrame: CGRect) {
        screenFrame = newFrame
        clampPositionToVisibleRange()
    }

    func settingsDidChange() {
        refreshSpeechBubbleStyle()
        refreshContentSize()
        restartAnimationTimer()
        restartSpeechBubbleCycle()
        reconcileBehaviorAvailability()
    }

    func reloadSpriteSheet(_ newSpriteSheet: SpriteSheet) {
        spriteSheet = newSpriteSheet
        currentFrameIndex = 0
        refreshContentSize()
        reconcileBehaviorAvailability()
        updateFrameImage()
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

    func playOneShotBehavior(_ behavior: Behavior) {
        guard isBehaviorEnabled(behavior) else {
            return
        }

        manualBehaviorOverride = nil
        behaviorTimer?.invalidate()
        applyBehavior(behavior)
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
        case .layDown:
            return "Lay Down"
        case .sleep:
            return "Sleep"
        case .extraTwo:
            return "Extra 2"
        }
    }

    func supportsManualBehavior(_ behavior: Behavior) -> Bool {
        isBehaviorEnabled(behavior)
    }

    private func refreshContentSize() {
        petSize = CGSize(
            width: spriteSheet.frameSize.width * settings.catScale,
            height: spriteSheet.frameSize.height * settings.catScale
        )
        let bubbleSize = speechBubbleSize(for: speechBubbleText)
        contentSize = CGSize(
            width: max(petSize.width, bubbleSize.width),
            height: petSize.height + (bubbleSize.height > 0 ? bubbleSize.height + Self.speechBubbleSpacing : 0)
        )
        clampPositionToVisibleRange()
        updateFrameImage()
    }

    private func refreshSpeechBubbleStyle() {
        speechBubbleColor = settings.speechBubbleColor
        speechBubbleTextColor = preferredTextColor(for: speechBubbleColor)
    }

    private func restartSpeechBubbleCycle() {
        speechBubbleTimer?.invalidate()

        guard settings.enableSpeechBubble,
              !settings.speechBubbleMessages.isEmpty
        else {
            if speechBubbleText != nil {
                speechBubbleText = nil
                refreshContentSize()
            }
            return
        }

        if speechBubbleText != nil {
            scheduleNextSpeechBubbleEvent(after: max(0.5, settings.speechBubbleDuration))
        } else {
            scheduleNextSpeechBubbleEvent(after: nextSpeechBubbleAttemptInterval())
        }
    }

    private func scheduleNextSpeechBubbleEvent(after interval: Double) {
        speechBubbleTimer?.invalidate()
        speechBubbleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.advanceSpeechBubbleCycle()
            }
        }
        RunLoop.main.add(speechBubbleTimer!, forMode: .common)
    }

    private func advanceSpeechBubbleCycle() {
        if speechBubbleText != nil {
            hideSpeechBubble()
            return
        }

        showRandomSpeechBubble()
    }

    private func showRandomSpeechBubble() {
        guard settings.enableSpeechBubble else {
            pauseSpeechBubbleCycle(clearBubble: true)
            return
        }

        guard !settings.speechBubbleMessages.isEmpty else {
            speechBubbleText = nil
            refreshContentSize()
            return
        }

        guard behavior != .sleep else {
            pauseSpeechBubbleCycle(clearBubble: true)
            return
        }

        let clampedChance = min(max(settings.speechBubbleChance, 0), 1)
        guard randomSource.nextUnitDouble() < clampedChance else {
            scheduleNextSpeechBubbleEvent(after: nextSpeechBubbleAttemptInterval())
            return
        }

        guard let message = settings.speechBubbleMessages.randomElement() else {
            speechBubbleText = nil
            refreshContentSize()
            return
        }

        speechBubbleText = message
        refreshContentSize()
        scheduleNextSpeechBubbleEvent(after: max(0.5, settings.speechBubbleDuration))
    }

    private func nextSpeechBubbleAttemptInterval() -> Double {
        let baseInterval = randomSource.randomDuration(Self.speechBubbleMinimumInterval)
        let clampedChance = min(max(settings.speechBubbleChance, 0), 1)

        // Lower chance should also reduce retry frequency, not only per-attempt success.
        let retryScale = 1 + ((1 - clampedChance) * 8)
        return baseInterval * retryScale
    }

    private func pauseSpeechBubbleCycle(clearBubble: Bool) {
        speechBubbleTimer?.invalidate()
        speechBubbleTimer = nil

        if clearBubble, speechBubbleText != nil {
            speechBubbleText = nil
            refreshContentSize()
        }
    }

    private func hideSpeechBubble() {
        speechBubbleText = nil
        refreshContentSize()
        scheduleNextSpeechBubbleEvent(after: nextSpeechBubbleAttemptInterval())
    }

    private func speechBubbleSize(for text: String?) -> CGSize {
        guard let text, !text.isEmpty else {
            return .zero
        }

        let maxWidth = max(
            Self.speechBubbleMinimumWidth,
            min(screenFrame.width * 0.5, petSize.width * Self.speechBubbleMaximumWidthRatio)
        )
        let textSize = NSString(string: text).boundingRect(
            with: CGSize(
                width: maxWidth - (Self.speechBubbleHorizontalPadding * 2),
                height: .greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: NSFont.systemFont(ofSize: max(13, settings.catScale * 12), weight: .medium)
            ]
        ).integral.size

        return CGSize(
            width: min(maxWidth, textSize.width + (Self.speechBubbleHorizontalPadding * 2)),
            height: max(34, textSize.height + (Self.speechBubbleVerticalPadding * 2) + 10)
        )
    }

    private func preferredTextColor(for bubbleColor: NSColor) -> NSColor {
        let convertedColor = bubbleColor.usingColorSpace(.deviceRGB) ?? bubbleColor
        let brightness = ((convertedColor.redComponent * 299) + (convertedColor.greenComponent * 587) + (convertedColor.blueComponent * 114)) / 1000
        return brightness > 0.6 ? .black : .white
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

        if behavior == .sleep {
            advanceSleepAnimationFrame(frames: frames)
            return
        }

        if behavior == .layDown {
            advanceLayDownAnimationFrame(frames: frames)
            return
        }

        currentFrameIndex = (currentFrameIndex + 1) % frames.count
        updateFrameImage()
    }

    private func advanceMovementFrame(deltaTime: TimeInterval) {
        let delta = CGFloat(settings.movementSpeed * deltaTime)

        switch behavior {
        case .walkDown:
            guard settings.enableVerticalMovement else { break }
            positionY -= delta
            if positionY <= minimumPositionY {
                positionY = minimumPositionY
                chooseNextBehavior(preferred: [
                    PreferredBehaviorOption(.walkUp, chance: 0.70),
                    PreferredBehaviorOption(.idle, chance: 1)
                ])
            }
        case .walkLeft:
            positionX -= delta
            if positionX <= 0 {
                positionX = 0
                chooseNextBehavior(preferred: [
                    PreferredBehaviorOption(.walkRight, chance: 0.70),
                    PreferredBehaviorOption(.idle, chance: 1)
                ])
            }
        case .walkRight:
            positionX += delta
            let maxX = maximumPositionX
            if positionX >= maxX {
                positionX = maxX
                chooseNextBehavior(preferred: [
                    PreferredBehaviorOption(.walkLeft, chance: 0.70),
                    PreferredBehaviorOption(.idle, chance: 1)
                ])
            }
        case .walkUp:
            guard settings.enableVerticalMovement else { break }
            positionY += delta
            if positionY >= maximumPositionY {
                positionY = maximumPositionY
                chooseNextBehavior(preferred: [
                    PreferredBehaviorOption(.walkDown, chance: 0.70),
                    PreferredBehaviorOption(.idle, chance: 1)
                ])
            }
        case .idle, .groom, .layDown, .sleep, .extraTwo:
            break
        }
    }

    private func chooseNextBehavior(preferred: Behavior? = nil) {
        let preferredBehaviors = preferred.map { [PreferredBehaviorOption($0)] } ?? []
        chooseNextBehavior(preferred: preferredBehaviors)
    }

    private func chooseNextBehavior(preferred preferredBehaviors: [PreferredBehaviorOption]) {
        behaviorTimer?.invalidate()

        if let manualBehaviorOverride, isBehaviorEnabled(manualBehaviorOverride) {
            transition(to: manualBehaviorOverride)
            return
        }

        let nextBehavior = nextAutomaticBehavior(preferred: preferredBehaviors)
        transition(to: nextBehavior)
    }

    private func nextAutomaticBehavior(preferred preferredBehaviors: [PreferredBehaviorOption] = []) -> Behavior {
        if behavior == .idle, idlePlaybackState == .seated {
            return nextBehaviorWhileSeated(preferred: preferredBehaviors)
        }

        if let preferredBehavior = selectedPreferredBehavior(from: preferredBehaviors) {
            return preferredBehavior
        }

        let availableBehaviors = automaticBehaviorPool()
        return availableBehaviors.randomElement() ?? .idle
    }

    private func nextBehaviorWhileSeated(preferred preferredBehaviors: [PreferredBehaviorOption] = []) -> Behavior {
        if let preferredBehavior = selectedPreferredBehavior(from: preferredBehaviors) {
            if preferredBehavior == .groom, isBehaviorEnabled(.groom) {
                return .groom
            }

            if preferredBehavior == .sleep, isBehaviorEnabled(.sleep) {
                return .sleep
            }

            if preferredBehavior != .idle {
                return preferredBehavior
            }
        }

        

        if isBehaviorEnabled(.idle), Double.random(in: 0 ... 1) < seatedIdleHoldChance {
                    if isBehaviorEnabled(.sleep), randomSource.nextUnitDouble() < sleepFrequencyChance {
                        return .sleep
                    }

                    if isBehaviorEnabled(.groom), randomSource.nextBool() {
                        return .groom
                    }

                    return .idle
        }

        let standingBehaviors = [Behavior.walkDown, .walkLeft, .walkRight, .walkUp]
            .filter(isBehaviorEnabled)
        return standingBehaviors.randomElement() ?? .idle
    }

    private func nextBehaviorWhileSleep() -> Behavior {
        if isBehaviorEnabled(.sleep), randomSource.nextUnitDouble() < sleepFrequencyChance {
            return .sleep
        }

        return .layDown
    }

    private func selectedPreferredBehavior(from options: [PreferredBehaviorOption]) -> Behavior? {
        for option in options where isBehaviorEnabled(option.behavior) {
            if randomSource.nextUnitDouble() < option.chance {
                return option.behavior
            }
        }

        return nil
    }

    private func automaticBehaviorPool() -> [Behavior] {
        if positionX <= 8 {
            return isBehaviorEnabled(.walkRight) ? [.walkRight] : fallbackBehaviors()
        }

        if positionX >= maximumPositionX - 8 {
            return isBehaviorEnabled(.walkLeft) ? [.walkLeft] : fallbackBehaviors()
        }

        var weightedBehaviors: [Behavior] = []

        if isBehaviorEnabled(.idle) && seatedIdleHoldChance != 0 {
            weightedBehaviors.append(.idle)
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

        // groom handle in idle

        return weightedBehaviors
    }

    private var seatedIdleHoldChance: Double {
        min(max(settings.sitPreference, 0), 1)
    }

    private var sleepFrequencyChance: Double {
        min(max(settings.sleepFrequency, 0), 1)
    }

    private var maximumPositionX: CGFloat {
        max(0, screenFrame.width - contentSize.width)
    }

    private var minimumPositionY: CGFloat {
        clampedPositionY(settings.defaultYOffset - settings.verticalMovementRange / 2)
    }

    private var maximumPositionY: CGFloat {
        clampedPositionY(settings.defaultYOffset + settings.verticalMovementRange / 2)
    }

    private func clampPositionToVisibleRange() {
        positionX = min(max(positionX, 0), maximumPositionX)
        if settings.enableVerticalMovement {
            positionY = min(max(positionY, minimumPositionY), maximumPositionY)
        } else {
            positionY = clampedPositionY(settings.defaultYOffset)
        }
    }

    private func clampedPositionY(_ proposedValue: Double) -> CGFloat {
        let maxY = max(0, screenFrame.height - contentSize.height)
        return min(max(CGFloat(proposedValue), 0), maxY)
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
        let enabled = Self.automaticBehaviors.filter(isBehaviorEnabled)

        // Keep the pet visible and recoverable even if the user disables every automatic behavior.
        return enabled.isEmpty ? [.idle] : enabled
    }

    private func hasFrames(for behavior: Behavior) -> Bool {
        !spriteSheet.frames(for: behavior.spriteSequence).isEmpty
    }

    private func isBehaviorEnabled(_ behavior: Behavior) -> Bool {
        switch behavior {
        case .walkDown:
            return settings.enableWalkDown && hasFrames(for: behavior)
        case .walkLeft:
            return settings.enableWalkLeft && hasFrames(for: behavior)
        case .walkRight:
            return settings.enableWalkRight && hasFrames(for: behavior)
        case .walkUp:
            return settings.enableWalkUp && hasFrames(for: behavior)
        case .idle:
            return settings.enableIdle && hasFrames(for: behavior)
        case .groom:
            return settings.enableGroom && hasFrames(for: behavior)
        case .layDown:
            return hasFrames(for: behavior)
        case .sleep:
            return settings.enableSleep && hasFrames(for: behavior)
        case .extraTwo:
            return hasFrames(for: behavior)
        }
    }

    private func applyBehavior(_ newBehavior: Behavior) {
        let previousBehavior = behavior
        behavior = newBehavior
        pendingBehaviorAfterIdleExit = nil
        sleepEndDate = nil
        sleepFrameAdvanceCountdown = 0

        if newBehavior == .sleep,
           speechBubbleText != nil || speechBubbleTimer != nil {
            pauseSpeechBubbleCycle(clearBubble: true)
        } else if previousBehavior == .sleep {
            restartSpeechBubbleCycle()
        }

        if newBehavior == .idle {
            idlePlaybackState = .entering
            groomPlaybackState = .inactive
            sleepPlaybackState = .inactive
            remainingGroomLoops = 0
            currentFrameIndex = 0
        } else if newBehavior == .groom {
            idlePlaybackState = .seated
            groomPlaybackState = .active
            sleepPlaybackState = .inactive
            remainingGroomLoops = Int.random(in: 1 ... 5)
            currentFrameIndex = groomLoopStartIndex(for: spriteSheet.frames(for: .groom))
        } else if newBehavior == .layDown {
            idlePlaybackState = .inactive
            groomPlaybackState = .inactive
            sleepPlaybackState = .inactive
            remainingGroomLoops = 0
            currentFrameIndex = 0
        } else if newBehavior == .sleep {
            idlePlaybackState = .inactive
            groomPlaybackState = .inactive
            remainingGroomLoops = 0

            if previousBehavior == .layDown {
                sleepPlaybackState = .enteringFromLayDown
                currentFrameIndex = 0
                if let restingFrame = spriteSheet.frames(for: .layDown).last {
                    currentFrame = restingFrame
                }
            } else {
                sleepPlaybackState = .enteringFromStanding
                currentFrameIndex = 0
                if let firstLayDownFrame = spriteSheet.frames(for: .layDown).first {
                    currentFrame = firstLayDownFrame
                }
            }
        } else {
            idlePlaybackState = .inactive
            groomPlaybackState = .inactive
            sleepPlaybackState = .inactive
            remainingGroomLoops = 0
            currentFrameIndex = 0
        }

        if newBehavior != .sleep {
            updateFrameImage()
        }
        scheduleBehaviorTimer(for: newBehavior)
    }

    private func updateFrameImage() {
        let frames = spriteSheet.frames(for: behavior.spriteSequence)
        guard !frames.isEmpty else { return }

        let safeIndex = min(currentFrameIndex, frames.count - 1)
        currentFrame = frames[safeIndex]
    }

    private func transition(to nextBehavior: Behavior) {
        if nextBehavior == .sleep,
           behavior == .layDown {
            applyBehavior(.sleep)
            return
        }

        if nextBehavior == .sleep,
           behavior != .idle || idlePlaybackState != .seated {
            beginIdleEnterTransition(for: .sleep)
            return
        }

        if nextBehavior == .sleep,
           behavior == .idle,
           idlePlaybackState == .seated {
            applyBehavior(.sleep)
            return
        }

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

          if behavior == .sleep,
              nextBehavior != .sleep {
                finishSleep(nextBehavior: nextBehavior)
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

        let loopStart = groomLoopStartIndex(for: frames)
        let loopEnd = groomLoopEndIndex(for: frames)

        switch groomPlaybackState {
        case .inactive:
            currentFrameIndex = min(max(currentFrameIndex, loopStart), loopEnd)
            updateFrameImage()
        case .active:
            if currentFrameIndex < loopEnd {
                currentFrameIndex += 1
                updateFrameImage()
                return
            }

            if remainingGroomLoops > 1 {
                remainingGroomLoops -= 1
                currentFrameIndex = loopStart
                updateFrameImage()
                return
            }

            remainingGroomLoops = 0
            groomPlaybackState = .inactive
            applySeatedIdleHold()
        }
    }

    private func advanceLayDownAnimationFrame(frames: [NSImage]) {
        guard !frames.isEmpty else { return }

        if currentFrameIndex < frames.count - 1 {
            currentFrameIndex += 1
        } else {
            currentFrameIndex = frames.count - 1
        }

        updateFrameImage()
    }

    private func advanceSleepAnimationFrame(frames: [NSImage]) {
        guard !frames.isEmpty else { return }

        switch sleepPlaybackState {
        case .inactive:
            currentFrameIndex = min(currentFrameIndex, frames.count - 1)
            updateFrameImage()
        case .enteringFromLayDown:
            startSleepLoop(frames: frames)
        case .enteringFromStanding:
            let layDownFrames = spriteSheet.frames(for: .layDown)
            if layDownFrames.isEmpty {
                startSleepLoop(frames: frames)
                return
            }

            if currentFrameIndex < layDownFrames.count {
                currentFrame = layDownFrames[currentFrameIndex]
                currentFrameIndex += 1
                return
            }

            startSleepLoop(frames: frames)
        case .sleeping:
            if let sleepEndDate, Date() >= sleepEndDate {
                let nextBehavior = nextBehaviorWhileSleep()
                if nextBehavior == .sleep {
                    startSleepLoop(frames: frames)
                } else {
                    finishSleep(nextBehavior: nextBehavior)
                }
                return
            }

            if sleepFrameAdvanceCountdown < Self.sleepFrameAdvanceDivisor - 1 {
                sleepFrameAdvanceCountdown += 1
                return
            }

            sleepFrameAdvanceCountdown = 0

            let loopStart = sleepLoopStartIndex(for: frames)
            let loopEnd = sleepLoopEndIndex(for: frames)
            if currentFrameIndex < loopStart || currentFrameIndex > loopEnd {
                currentFrameIndex = loopStart
            } else if currentFrameIndex < loopEnd {
                currentFrameIndex += 1
            } else {
                currentFrameIndex = loopStart
            }
            updateFrameImage()
        }
    }

    private func startSleepLoop(frames: [NSImage]) {
        sleepPlaybackState = .sleeping
        sleepEndDate = Date().addingTimeInterval(randomDuration(for: 8.0 ... 18.0, behavior: .sleep))
        sleepFrameAdvanceCountdown = 0
        currentFrameIndex = sleepLoopStartIndex(for: frames)
        updateFrameImage()
    }

    private var lazyDurationMultiplier: Double {
        1 + (min(max(settings.lazyPercentage, 0), 1) * 2)
    }

    private func randomDuration(for baseRange: ClosedRange<Double>, behavior: Behavior) -> Double {
        let multiplier = lazyDurationMultiplier
        let adjustedRange: ClosedRange<Double>

        switch behavior {
        case .walkDown, .walkLeft, .walkRight, .walkUp:
            adjustedRange = (baseRange.lowerBound / multiplier) ... (baseRange.upperBound / multiplier)
        case .idle, .layDown, .sleep:
            adjustedRange = (baseRange.lowerBound * multiplier) ... (baseRange.upperBound * multiplier)
        case .groom, .extraTwo:
            adjustedRange = baseRange
        }

        return randomSource.randomDuration(adjustedRange)
    }

    private func sleepLoopStartIndex(for frames: [NSImage]) -> Int {
        min(Self.sleepLoopStartFrame, max(0, frames.count - 1))
    }

    private func sleepLoopEndIndex(for frames: [NSImage]) -> Int {
        max(sleepLoopStartIndex(for: frames), min(Self.sleepLoopEndFrame, frames.count - 1))
    }

    private func finishSleep(nextBehavior: Behavior) {
        sleepEndDate = nil
        sleepPlaybackState = .inactive

        if nextBehavior == .layDown {
            applyLayDownRestPose(scheduleTimer: true)
            restartSpeechBubbleCycle()
            return
        }

        applyLayDownRestPose(scheduleTimer: false)
        restartSpeechBubbleCycle()
        behaviorTimer?.invalidate()
        behaviorTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.chooseNextBehavior(preferred: [PreferredBehaviorOption(nextBehavior, chance: 1)])
            }
        }
        RunLoop.main.add(behaviorTimer!, forMode: .common)
    }

    private func groomLoopStartIndex(for frames: [NSImage]) -> Int {
        min(Self.groomLoopStartFrame, max(0, frames.count - 1))
    }

    private func groomLoopEndIndex(for frames: [NSImage]) -> Int {
        max(groomLoopStartIndex(for: frames), min(Self.groomLoopEndFrame, frames.count - 1))
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

    private func applyLayDownRestPose(scheduleTimer: Bool) {
        let layDownFrames = spriteSheet.frames(for: .layDown)

        behavior = .layDown
        idlePlaybackState = .inactive
        groomPlaybackState = .inactive
        sleepPlaybackState = .inactive
        remainingGroomLoops = 0
        sleepEndDate = nil
        currentFrameIndex = max(0, layDownFrames.count - 1)

        if let restingFrame = layDownFrames.last {
            currentFrame = restingFrame
        } else {
            updateFrameImage()
        }

        behaviorTimer?.invalidate()
        if scheduleTimer {
            scheduleBehaviorTimer(for: .layDown)
        } else {
            behaviorTimer = nil
        }
    }

    private func scheduleBehaviorTimer(for behavior: Behavior) {
        if behavior == .groom {
            behaviorTimer?.invalidate()
            behaviorTimer = nil
            return
        }

        if behavior == .sleep {
            behaviorTimer?.invalidate()
            behaviorTimer = nil
            return
        }

        let duration: ClosedRange<Double>
        switch behavior {
        case .walkDown:
            duration = 1.0 ... 5.0
        case .walkLeft, .walkRight:
            duration = 1.0 ... 5.0
        case .walkUp:
            duration = 1.0 ... 5.0
        case .idle:
            duration = 1.0 ... 3.0
        case .groom:
            return
        case .layDown:
            duration = 10.0 ... 20.0
        case .sleep:
            return
        case .extraTwo:
            duration = 1.0 ... 2.0
        }

        behaviorTimer?.invalidate()
        behaviorTimer = Timer.scheduledTimer(withTimeInterval: randomDuration(for: duration, behavior: behavior), repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.chooseNextBehavior()
            }
        }
        RunLoop.main.add(behaviorTimer!, forMode: .common)
    }
}

#if DEBUG
extension PetEngine {
    var currentBehaviorForTesting: Behavior {
        behavior
    }

    var isSpeechBubbleTimerActiveForTesting: Bool {
        speechBubbleTimer?.isValid ?? false
    }

    var currentSpeechBubbleTextForTesting: String? {
        speechBubbleText
    }

    func advanceSpeechBubbleCycleForTesting() {
        advanceSpeechBubbleCycle()
    }

    func applyBehaviorForTesting(_ behavior: Behavior) {
        applyBehavior(behavior)
    }

    func nextAutomaticBehaviorForTesting() -> Behavior {
        nextAutomaticBehavior()
    }

    func nextBehaviorWhileSleepForTesting() -> Behavior {
        nextBehaviorWhileSleep()
    }
}
#endif
