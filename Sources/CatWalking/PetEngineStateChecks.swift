#if DEBUG
import AppKit
import Foundation

@MainActor
enum PetEngineStateChecks {
    enum Failure: Error, CustomStringConvertible {
        case message(String)

        var description: String {
            switch self {
            case let .message(message):
                return message
            }
        }
    }

    static func run() throws {
        try speechBubbleCycleDoesNotRescheduleWhenDisabled()
        try sleepClearsBubbleAndPausesSpeechTimerUntilWake()
        try automaticBehaviorFallsBackToIdleWhenEverythingIsDisabled()
        try sleepContinuationRespectsSleepFrequency()

        NSLog("PetEngine state checks passed")
    }

    private static func speechBubbleCycleDoesNotRescheduleWhenDisabled() throws {
        let settings = makeSettings()
        settings.enableSpeechBubble = false

        let engine = makeEngine(settings: settings)
        engine.advanceSpeechBubbleCycleForTesting()

        try require(engine.isSpeechBubbleTimerActiveForTesting == false, "Speech timer should stop when speech bubbles are disabled")
        try require(engine.currentSpeechBubbleTextForTesting == nil, "Speech bubble text should clear when speech bubbles are disabled")
    }

    private static func sleepClearsBubbleAndPausesSpeechTimerUntilWake() throws {
        let settings = makeSettings()
        settings.enableSpeechBubble = true
        settings.speechBubbleChance = 1

        let engine = makeEngine(
            settings: settings,
            randomSource: .init(
                nextUnitDouble: { 0 },
                nextBool: { false },
                randomDuration: { $0.lowerBound }
            )
        )

        engine.advanceSpeechBubbleCycleForTesting()
        try require(engine.currentSpeechBubbleTextForTesting != nil, "Speech bubble should appear when the speech chance is guaranteed")
        try require(engine.isSpeechBubbleTimerActiveForTesting, "Speech timer should be active while a bubble is visible")

        engine.applyBehaviorForTesting(.sleep)
        try require(engine.currentSpeechBubbleTextForTesting == nil, "Sleep should immediately clear the speech bubble")
        try require(engine.isSpeechBubbleTimerActiveForTesting == false, "Sleep should pause the speech timer")

        engine.applyBehaviorForTesting(.idle)
        try require(engine.isSpeechBubbleTimerActiveForTesting, "Waking from sleep should restart the speech timer")
    }

    private static func automaticBehaviorFallsBackToIdleWhenEverythingIsDisabled() throws {
        let settings = makeSettings()
        settings.enableWalkDown = false
        settings.enableWalkLeft = false
        settings.enableWalkRight = false
        settings.enableWalkUp = false
        settings.enableIdle = false
        settings.enableGroom = false

        let engine = makeEngine(settings: settings)

        try require(engine.nextAutomaticBehaviorForTesting() == .idle, "Automatic behavior should fall back to idle when every automatic animation is disabled")
    }

    private static func sleepContinuationRespectsSleepFrequency() throws {
        let settings = makeSettings()
        settings.enableSleep = true

        settings.sleepFrequency = 1
        let alwaysSleepEngine = makeEngine(
            settings: settings,
            randomSource: .init(
                nextUnitDouble: { 0 },
                nextBool: { false },
                randomDuration: { $0.lowerBound }
            )
        )
        try require(alwaysSleepEngine.nextBehaviorWhileSleepForTesting() == .sleep, "Sleep should continue when sleep frequency is 100%")

        settings.sleepFrequency = 0
        let neverSleepEngine = makeEngine(
            settings: settings,
            randomSource: .init(
                nextUnitDouble: { 1 },
                nextBool: { false },
                randomDuration: { $0.lowerBound }
            )
        )
        try require(neverSleepEngine.nextBehaviorWhileSleepForTesting() == .layDown, "Sleep should end in lay down when sleep frequency is 0%")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw Failure.message(message)
        }
    }

    private static func makeEngine(
        settings: AppSettings,
        randomSource: PetEngine.RandomSource = .live
    ) -> PetEngine {
        PetEngine(
            settings: settings,
            spriteSheet: makeSpriteSheet(),
            randomSource: randomSource
        )
    }

    private static func makeSettings() -> AppSettings {
        let suiteName = "CatWalkingStateChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
    }

    private static func makeSpriteSheet() -> SpriteSheet {
        let mapping = SpriteSheetAnimationMapping(
            selections: [
                .walkDown: .init(row: 0),
                .walkRight: .init(row: 1),
                .walkUp: .init(row: 2),
                .walkLeft: .init(row: 3),
                .idle: .init(row: 4),
                .groom: .init(row: 5),
                .layDown: .init(row: 6),
                .sleep: .init(row: 7, startColumn: 0, endColumn: 1),
                .extraTwo: .init(row: 7, startColumn: 2, endColumn: 3)
            ]
        )
        let configuration = SpriteSheetConfiguration(
            rows: 8,
            columns: 4,
            rowOrder: .topToBottom,
            animationMapping: mapping
        )

        let frame = NSImage(size: CGSize(width: 16, height: 16))
        let rows = (0 ..< configuration.rows).map { _ in
            (0 ..< configuration.columns).map { _ in frame }
        }

        return SpriteSheet(
            configuration: configuration,
            framesByRow: rows,
            frameSize: CGSize(width: 16, height: 16)
        )
    }
}
#endif