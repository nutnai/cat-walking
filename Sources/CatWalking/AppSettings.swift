import AppKit
import Combine

@MainActor
final class AppSettings: ObservableObject {

    private enum Keys {
        static let selectedCatTemplate = "selectedCatTemplate"
        static let catScale = "catScale"
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
        static let stayOnTop = "stayOnTop"
        static let enableWalkDown = "enableWalkDown"
        static let enableWalkLeft = "enableWalkLeft"
        static let enableWalkRight = "enableWalkRight"
        static let enableWalkUp = "enableWalkUp"
        static let enableIdle = "enableIdle"
        static let enableGroom = "enableGroom"
    }

    private let defaults: UserDefaults

    @Published var selectedCatTemplate: String {
        didSet { defaults.set(selectedCatTemplate, forKey: Keys.selectedCatTemplate) }
    }

    @Published var catScale: Double {
        didSet { defaults.set(catScale, forKey: Keys.catScale) }
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
        didSet { defaults.set(animationFPS, forKey: Keys.animationFPS) }
    }

    @Published var movementSpeed: Double {
        didSet { defaults.set(movementSpeed, forKey: Keys.movementSpeed) }
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
        didSet { defaults.set(sitPreference, forKey: Keys.sitPreference) }
    }

    @Published var stayOnTop: Bool {
        didSet { defaults.set(stayOnTop, forKey: Keys.stayOnTop) }
    }

    @Published var enableWalkDown: Bool {
        didSet { defaults.set(enableWalkDown, forKey: Keys.enableWalkDown) }
    }

    @Published var enableWalkLeft: Bool {
        didSet { defaults.set(enableWalkLeft, forKey: Keys.enableWalkLeft) }
    }

    @Published var enableWalkRight: Bool {
        didSet { defaults.set(enableWalkRight, forKey: Keys.enableWalkRight) }
    }

    @Published var enableWalkUp: Bool {
        didSet { defaults.set(enableWalkUp, forKey: Keys.enableWalkUp) }
    }

    @Published var enableIdle: Bool {
        didSet { defaults.set(enableIdle, forKey: Keys.enableIdle) }
    }

    @Published var enableGroom: Bool {
        didSet { defaults.set(enableGroom, forKey: Keys.enableGroom) }
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
        self.stayOnTop = defaults.object(forKey: Keys.stayOnTop) as? Bool ?? true
        self.enableWalkDown = defaults.object(forKey: Keys.enableWalkDown) as? Bool ?? false
        self.enableWalkLeft = defaults.object(forKey: Keys.enableWalkLeft) as? Bool ?? true
        self.enableWalkRight = defaults.object(forKey: Keys.enableWalkRight) as? Bool ?? true
        self.enableWalkUp = defaults.object(forKey: Keys.enableWalkUp) as? Bool ?? false
        self.enableIdle = defaults.object(forKey: Keys.enableIdle) as? Bool ?? true
        self.enableGroom = defaults.object(forKey: Keys.enableGroom) as? Bool ?? true

        if !enableVerticalMovement {
            enableWalkDown = false
            enableWalkUp = false
        }
    }
}
