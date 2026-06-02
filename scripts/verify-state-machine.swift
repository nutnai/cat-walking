import AppKit
import Foundation

@MainActor
@main
struct StateMachineChecks {
    static func main() {
        do {
            try speechBubbleCycleDoesNotRescheduleWhenDisabled()
            try sleepClearsBubbleAndPausesSpeechTimerUntilWake()
            try automaticBehaviorFallsBackToIdleWhenEverythingIsDisabled()
            try sleepContinuationRespectsSleepFrequency()
            print("State-machine checks passed.")
        } catch {
            fputs("State-machine checks failed: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func speechBubbleCycleDoesNotRescheduleWhenDisabled() throws {
        let settings = makeSettings()
        settings.enableSpeechBubble = false

        let engine = makeEngine(settings: settings)
        engine.advanceSpeechBubbleCycleForTesting()

        try expect(engine.isSpeechBubbleTimerActiveForTesting == false, "Disabled speech should not keep a timer alive")
        try expect(engine.currentSpeechBubbleTextForTesting == nil, "Disabled speech should not show text")
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
        try expect(engine.currentSpeechBubbleTextForTesting != nil, "Expected a speech bubble before sleep")
        try expect(engine.isSpeechBubbleTimerActiveForTesting, "Expected active speech timer before sleep")

        engine.applyBehaviorForTesting(.sleep)
        try expect(engine.currentSpeechBubbleTextForTesting == nil, "Sleep should clear speech bubbles")
        try expect(engine.isSpeechBubbleTimerActiveForTesting == false, "Sleep should pause the speech cycle")

        engine.applyBehaviorForTesting(.idle)
        try expect(engine.isSpeechBubbleTimerActiveForTesting, "Waking should restart the speech cycle")
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
        try expect(engine.nextAutomaticBehaviorForTesting() == .idle, "Automatic behavior should fall back to idle")
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
        try expect(alwaysSleepEngine.nextBehaviorWhileSleepForTesting() == .sleep, "Sleep frequency of 1 should continue sleeping")

        settings.sleepFrequency = 0
        let neverSleepEngine = makeEngine(
            settings: settings,
            randomSource: .init(
                nextUnitDouble: { 1 },
                nextBool: { false },
                randomDuration: { $0.lowerBound }
            )
        )
        try expect(neverSleepEngine.nextBehaviorWhileSleepForTesting() == .layDown, "Sleep frequency of 0 should wake to lay down")
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

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if condition() == false {
            throw VerificationError(message)
        }
    }
}

private struct VerificationError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}