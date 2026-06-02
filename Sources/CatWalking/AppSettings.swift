import AppKit
import Combine

@MainActor
final class AppSettings: ObservableObject {

    enum BehaviorPreset: String, CaseIterable, Identifiable {
        case naughty
        case normal
        case lazy
        case custom

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .naughty:
                return "Naughty"
            case .normal:
                return "Normal"
            case .lazy:
                return "Lazy"
            case .custom:
                return "Custom"
            }
        }
    }

    private struct AnimationProfile {
        let animationFPS: Double
        let movementSpeed: Double
        let sitPreference: Double
        let sleepFrequency: Double
        let lazyPercentage: Double
    }

    private enum Keys {
        static let selectedCatTemplate = "selectedCatTemplate"
        static let catScale = "catScale"
        static let openAtLogin = "openAtLogin"
        static let enableSpeechBubble = "enableSpeechBubble"
        static let speechBubbleMessages = "speechBubbleMessages"
        static let speechBubbleChance = "speechBubbleChance"
        static let speechBubbleDuration = "speechBubbleDuration"
        static let speechBubbleColorRed = "speechBubbleColorRed"
        static let speechBubbleColorGreen = "speechBubbleColorGreen"
        static let speechBubbleColorBlue = "speechBubbleColorBlue"
        static let animationFPS = "animationFPS"
        static let movementSpeed = "movementSpeed"
        static let enableVerticalMovement = "enableVerticalMovement"
        static let defaultYOffset = "defaultYOffset"
        static let verticalMovementRange = "verticalMovementRange"
        static let sitPreference = "sitPreference"
        static let sleepFrequency = "sleepFrequency"
        static let lazyPercentage = "lazyPercentage"
        static let stayOnTop = "stayOnTop"
        static let enableWalkDown = "enableWalkDown"
        static let enableWalkLeft = "enableWalkLeft"
        static let enableWalkRight = "enableWalkRight"
        static let enableWalkUp = "enableWalkUp"
        static let enableIdle = "enableIdle"
        static let enableGroom = "enableGroom"
        static let enableSleep = "enableSleep"
        static let behaviorPreset = "behaviorPreset"

        static let customAnimationFPS = "customAnimationFPS"
        static let customMovementSpeed = "customMovementSpeed"
        static let customSitPreference = "customSitPreference"
        static let customSleepFrequency = "customSleepFrequency"
        static let customLazyPercentage = "customLazyPercentage"
    }

    private let defaults: UserDefaults
    private var customAnimationProfile: AnimationProfile

    @Published var selectedCatTemplate: String {
        didSet { defaults.set(selectedCatTemplate, forKey: Keys.selectedCatTemplate) }
    }

    @Published var catScale: Double {
        didSet { defaults.set(catScale, forKey: Keys.catScale) }
    }

    @Published var openAtLogin: Bool {
        didSet {
            defaults.set(openAtLogin, forKey: Keys.openAtLogin)
            LaunchAtLoginManager.shared.setEnabled(openAtLogin)
        }
    }

    @Published var enableSpeechBubble: Bool {
        didSet { defaults.set(enableSpeechBubble, forKey: Keys.enableSpeechBubble) }
    }

    @Published var speechBubbleMessagesRaw: String {
        didSet { defaults.set(speechBubbleMessagesRaw, forKey: Keys.speechBubbleMessages) }
    }

    @Published var speechBubbleChance: Double {
        didSet { defaults.set(speechBubbleChance, forKey: Keys.speechBubbleChance) }
    }

    @Published var speechBubbleDuration: Double {
        didSet { defaults.set(speechBubbleDuration, forKey: Keys.speechBubbleDuration) }
    }

    @Published var speechBubbleColorRed: Double {
        didSet { defaults.set(speechBubbleColorRed, forKey: Keys.speechBubbleColorRed) }
    }

    @Published var speechBubbleColorGreen: Double {
        didSet { defaults.set(speechBubbleColorGreen, forKey: Keys.speechBubbleColorGreen) }
    }

    @Published var speechBubbleColorBlue: Double {
        didSet { defaults.set(speechBubbleColorBlue, forKey: Keys.speechBubbleColorBlue) }
    }

    @Published var animationFPS: Double {
        didSet {
            defaults.set(animationFPS, forKey: Keys.animationFPS)
            syncCustomAnimationProfileIfNeeded()
        }
    }

    @Published var movementSpeed: Double {
        didSet {
            defaults.set(movementSpeed, forKey: Keys.movementSpeed)
            syncCustomAnimationProfileIfNeeded()
        }
    }

    @Published var enableVerticalMovement: Bool {
        didSet {
            if !enableVerticalMovement {
                enableWalkDown = false
                enableWalkUp = false
            }
            defaults.set(enableVerticalMovement, forKey: Keys.enableVerticalMovement)
        }
    }

    @Published var defaultYOffset: Double {
        didSet { defaults.set(defaultYOffset, forKey: Keys.defaultYOffset) }
    }

    @Published var verticalMovementRange: Double {
        didSet { defaults.set(verticalMovementRange, forKey: Keys.verticalMovementRange) }
    }

    @Published var sitPreference: Double {
        didSet {
            defaults.set(sitPreference, forKey: Keys.sitPreference)
            syncCustomAnimationProfileIfNeeded()
        }
    }

    @Published var sleepFrequency: Double {
        didSet {
            defaults.set(sleepFrequency, forKey: Keys.sleepFrequency)
            syncCustomAnimationProfileIfNeeded()
        }
    }

    @Published var lazyPercentage: Double {
        didSet {
            defaults.set(lazyPercentage, forKey: Keys.lazyPercentage)
            syncCustomAnimationProfileIfNeeded()
        }
    }

    @Published var stayOnTop: Bool {
        didSet { defaults.set(stayOnTop, forKey: Keys.stayOnTop) }
    }

    @Published var enableWalkDown: Bool {
        didSet {
            defaults.set(enableWalkDown, forKey: Keys.enableWalkDown)
        }
    }

    @Published var enableWalkLeft: Bool {
        didSet {
            defaults.set(enableWalkLeft, forKey: Keys.enableWalkLeft)
        }
    }

    @Published var enableWalkRight: Bool {
        didSet {
            defaults.set(enableWalkRight, forKey: Keys.enableWalkRight)
        }
    }

    @Published var enableWalkUp: Bool {
        didSet {
            defaults.set(enableWalkUp, forKey: Keys.enableWalkUp)
        }
    }

    @Published var enableIdle: Bool {
        didSet {
            defaults.set(enableIdle, forKey: Keys.enableIdle)
        }
    }

    @Published var enableGroom: Bool {
        didSet {
            defaults.set(enableGroom, forKey: Keys.enableGroom)
        }
    }

    @Published var enableSleep: Bool {
        didSet {
            defaults.set(enableSleep, forKey: Keys.enableSleep)
        }
    }

    @Published var behaviorPreset: BehaviorPreset {
        didSet {
            defaults.set(behaviorPreset.rawValue, forKey: Keys.behaviorPreset)
            applyBehaviorPresetTransition(from: oldValue, to: behaviorPreset)
        }
    }

    var isCustomBehaviorPreset: Bool {
        behaviorPreset == .custom
    }

    var speechBubbleMessages: [String] {
        speechBubbleMessagesRaw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func updateSpeechBubbleMessage(at index: Int, to value: String) {
        var messages = speechBubbleMessages
        guard messages.indices.contains(index) else {
            return
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue.isEmpty {
            messages.remove(at: index)
        } else {
            messages[index] = trimmedValue
        }

        speechBubbleMessagesRaw = messages.joined(separator: "\n")
    }

    func addSpeechBubbleMessage(_ value: String = "New phrase") {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return
        }

        var messages = speechBubbleMessages
        messages.append(trimmedValue)
        speechBubbleMessagesRaw = messages.joined(separator: "\n")
    }

    func removeSpeechBubbleMessage(at index: Int) {
        var messages = speechBubbleMessages
        guard messages.indices.contains(index) else {
            return
        }

        messages.remove(at: index)
        speechBubbleMessagesRaw = messages.joined(separator: "\n")
    }

    var speechBubbleColor: NSColor {
        NSColor(
            calibratedRed: speechBubbleColorRed,
            green: speechBubbleColorGreen,
            blue: speechBubbleColorBlue,
            alpha: 0.95
        )
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selectedCatTemplate = defaults.string(forKey: Keys.selectedCatTemplate) ?? SpriteSheet.defaultTemplateSelection
        self.catScale = defaults.object(forKey: Keys.catScale) as? Double ?? 0.4
        self.openAtLogin = defaults.object(forKey: Keys.openAtLogin) as? Bool ?? LaunchAtLoginManager.shared.isEnabled
        self.enableSpeechBubble = defaults.object(forKey: Keys.enableSpeechBubble) as? Bool ?? true
        self.speechBubbleMessagesRaw = defaults.string(forKey: Keys.speechBubbleMessages) ?? "Meow\nPurr...\nHello!"
        self.speechBubbleChance = defaults.object(forKey: Keys.speechBubbleChance) as? Double ?? 0.05
        self.speechBubbleDuration = defaults.object(forKey: Keys.speechBubbleDuration) as? Double ?? 3.0
        self.speechBubbleColorRed = defaults.object(forKey: Keys.speechBubbleColorRed) as? Double ?? 1.0
        self.speechBubbleColorGreen = defaults.object(forKey: Keys.speechBubbleColorGreen) as? Double ?? 1.0
        self.speechBubbleColorBlue = defaults.object(forKey: Keys.speechBubbleColorBlue) as? Double ?? 1.0
        self.animationFPS = defaults.object(forKey: Keys.animationFPS) as? Double ?? 4.0
        self.movementSpeed = defaults.object(forKey: Keys.movementSpeed) as? Double ?? 80.0
        self.enableVerticalMovement = defaults.object(forKey: Keys.enableVerticalMovement) as? Bool ?? false
        self.defaultYOffset = defaults.object(forKey: Keys.defaultYOffset) as? Double ?? 0.0
        self.verticalMovementRange = defaults.object(forKey: Keys.verticalMovementRange) as? Double ?? 180.0
        self.sitPreference = defaults.object(forKey: Keys.sitPreference) as? Double ?? 0.5
        self.sleepFrequency = defaults.object(forKey: Keys.sleepFrequency) as? Double ?? 0.5
        self.lazyPercentage = defaults.object(forKey: Keys.lazyPercentage) as? Double ?? 0.3
        self.stayOnTop = defaults.object(forKey: Keys.stayOnTop) as? Bool ?? true
        self.enableWalkDown = defaults.object(forKey: Keys.enableWalkDown) as? Bool ?? false
        self.enableWalkLeft = defaults.object(forKey: Keys.enableWalkLeft) as? Bool ?? true
        self.enableWalkRight = defaults.object(forKey: Keys.enableWalkRight) as? Bool ?? true
        self.enableWalkUp = defaults.object(forKey: Keys.enableWalkUp) as? Bool ?? false
        self.enableIdle = defaults.object(forKey: Keys.enableIdle) as? Bool ?? true
        self.enableGroom = defaults.object(forKey: Keys.enableGroom) as? Bool ?? true
        self.enableSleep = defaults.object(forKey: Keys.enableSleep) as? Bool ?? true
        self.behaviorPreset = BehaviorPreset(rawValue: defaults.string(forKey: Keys.behaviorPreset) ?? "") ?? .custom
        self.customAnimationProfile = AnimationProfile(
            animationFPS: defaults.object(forKey: Keys.customAnimationFPS) as? Double ?? (defaults.object(forKey: Keys.animationFPS) as? Double ?? 4.0),
            movementSpeed: defaults.object(forKey: Keys.customMovementSpeed) as? Double ?? (defaults.object(forKey: Keys.movementSpeed) as? Double ?? 80.0),
            sitPreference: defaults.object(forKey: Keys.customSitPreference) as? Double ?? (defaults.object(forKey: Keys.sitPreference) as? Double ?? 0.5),
            sleepFrequency: defaults.object(forKey: Keys.customSleepFrequency) as? Double ?? (defaults.object(forKey: Keys.sleepFrequency) as? Double ?? 0.5),
            lazyPercentage: defaults.object(forKey: Keys.customLazyPercentage) as? Double ?? (defaults.object(forKey: Keys.lazyPercentage) as? Double ?? 0.3)
        )

        if !enableVerticalMovement {
            enableWalkDown = false
            enableWalkUp = false
        }

        applyBehaviorPresetOnLaunch()
    }

    private func applyBehaviorPresetOnLaunch() {
        if behaviorPreset == .custom {
            applyAnimationProfile(customAnimationProfile)
            return
        }

        if let profile = presetProfile(for: behaviorPreset) {
            applyAnimationProfile(profile)
        }
    }

    private func applyBehaviorPresetTransition(from oldValue: BehaviorPreset, to newValue: BehaviorPreset) {
        guard oldValue != newValue else {
            return
        }

        if oldValue == .custom {
            customAnimationProfile = captureCurrentAnimationProfile()
            persistCustomAnimationProfile(customAnimationProfile)
        }

        if newValue == .custom {
            applyAnimationProfile(customAnimationProfile)
            return
        }

        if let profile = presetProfile(for: newValue) {
            applyAnimationProfile(profile)
        }
    }

    private func syncCustomAnimationProfileIfNeeded() {
        guard behaviorPreset == .custom else {
            return
        }

        customAnimationProfile = captureCurrentAnimationProfile()
        persistCustomAnimationProfile(customAnimationProfile)
    }

    private func captureCurrentAnimationProfile() -> AnimationProfile {
        AnimationProfile(
            animationFPS: animationFPS,
            movementSpeed: movementSpeed,
            sitPreference: sitPreference,
            sleepFrequency: sleepFrequency,
            lazyPercentage: lazyPercentage
        )
    }

    private func persistCustomAnimationProfile(_ profile: AnimationProfile) {
        defaults.set(profile.animationFPS, forKey: Keys.customAnimationFPS)
        defaults.set(profile.movementSpeed, forKey: Keys.customMovementSpeed)
        defaults.set(profile.sitPreference, forKey: Keys.customSitPreference)
        defaults.set(profile.sleepFrequency, forKey: Keys.customSleepFrequency)
        defaults.set(profile.lazyPercentage, forKey: Keys.customLazyPercentage)
    }

    private func applyAnimationProfile(_ profile: AnimationProfile) {
        animationFPS = profile.animationFPS
        movementSpeed = profile.movementSpeed
        sitPreference = profile.sitPreference
        sleepFrequency = profile.sleepFrequency
        lazyPercentage = profile.lazyPercentage
    }

    private func presetProfile(for preset: BehaviorPreset) -> AnimationProfile? {
        switch preset {
        case .naughty:
            return AnimationProfile(
                animationFPS: 8,
                movementSpeed: 220,
                sitPreference: 0.12,
                sleepFrequency: 0.08,
                lazyPercentage: 0.05
            )
        case .normal:
            return AnimationProfile(
                animationFPS: 5,
                movementSpeed: 110,
                sitPreference: 0.5,
                sleepFrequency: 0.35,
                lazyPercentage: 0.35
            )
        case .lazy:
            return AnimationProfile(
                animationFPS: 4,
                movementSpeed: 55,
                sitPreference: 0.88,
                sleepFrequency: 0.75,
                lazyPercentage: 0.9
            )
        case .custom:
            return nil
        }
    }
}
