import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let catScale = "catScale"
        static let animationFPS = "animationFPS"
        static let movementSpeed = "movementSpeed"
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

    @Published var catScale: Double {
        didSet { defaults.set(catScale, forKey: Keys.catScale) }
    }

    @Published var animationFPS: Double {
        didSet { defaults.set(animationFPS, forKey: Keys.animationFPS) }
    }

    @Published var movementSpeed: Double {
        didSet { defaults.set(movementSpeed, forKey: Keys.movementSpeed) }
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.catScale = defaults.object(forKey: Keys.catScale) as? Double ?? 1.0
        self.animationFPS = defaults.object(forKey: Keys.animationFPS) as? Double ?? 3.0
        self.movementSpeed = defaults.object(forKey: Keys.movementSpeed) as? Double ?? 30.0
        self.sitPreference = defaults.object(forKey: Keys.sitPreference) as? Double ?? 0.7
        self.stayOnTop = defaults.object(forKey: Keys.stayOnTop) as? Bool ?? true
        self.enableWalkDown = defaults.object(forKey: Keys.enableWalkDown) as? Bool ?? false
        self.enableWalkLeft = defaults.object(forKey: Keys.enableWalkLeft) as? Bool ?? true
        self.enableWalkRight = defaults.object(forKey: Keys.enableWalkRight) as? Bool ?? true
        self.enableWalkUp = defaults.object(forKey: Keys.enableWalkUp) as? Bool ?? false
        self.enableIdle = defaults.object(forKey: Keys.enableIdle) as? Bool ?? false
        self.enableGroom = defaults.object(forKey: Keys.enableGroom) as? Bool ?? true
    }
}
