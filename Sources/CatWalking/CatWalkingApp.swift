import AppKit
import SwiftUI

@MainActor
final class AppContainer {
    static let shared = AppContainer()

    let settings = AppSettings()
    lazy var spriteSheet = SpriteSheet.load()
    lazy var engine = PetEngine(settings: settings, spriteSheet: spriteSheet)

    private init() {}
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if ProcessInfo.processInfo.environment["CATWALKING_RUN_STATE_CHECKS"] == "1" {
            do {
                try PetEngineStateChecks.run()
            } catch {
                NSLog("PetEngine state checks failed: %@", String(describing: error))
            }

            NSApp.terminate(nil)
            return
        }

        let container = AppContainer.shared
        let overlayController = OverlayWindowController(engine: container.engine, settings: container.settings)
        self.overlayController = overlayController

        container.engine.start()
        overlayController.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppContainer.shared.engine.stop()
    }
}

@main
struct CatWalkingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppContainer.shared.settings
    @StateObject private var engine = AppContainer.shared.engine

    var body: some Scene {
        MenuBarExtra("Calico Cat", systemImage: "cat") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Calico Cat")
                    .font(.headline)

                Text("Use Settings to change size, speed, and enabled animations.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Current: \(engine.currentBehaviorDisplayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SettingsLink {
                    Text("Open Settings...")
                }

                Toggle("Stay on Top", isOn: $settings.stayOnTop)

                Divider()

                Button("Auto Behavior") {
                    engine.setManualBehaviorOverride(nil)
                }

                Button("Test Walk Down") {
                    engine.setManualBehaviorOverride(.walkDown)
                }

                Button("Test Walk Left") {
                    engine.setManualBehaviorOverride(.walkLeft)
                }

                Button("Test Walk Right") {
                    engine.setManualBehaviorOverride(.walkRight)
                }

                Button("Test Walk Up") {
                    engine.setManualBehaviorOverride(.walkUp)
                }

                Button("Test Idle") {
                    engine.setManualBehaviorOverride(.idle)
                }

                Button("Test Groom") {
                    engine.setManualBehaviorOverride(.groom)
                }

                if engine.supportsManualBehavior(.layDown) {
                    Button("Test Lay Down") {
                        engine.setManualBehaviorOverride(.layDown)
                    }
                }

                if engine.supportsManualBehavior(.sleep) {
                    Button("Test Sleep") {
                        engine.setManualBehaviorOverride(.sleep)
                    }
                }

                if engine.supportsManualBehavior(.extraTwo) {
                    Button("Test Extra 2") {
                        engine.playOneShotBehavior(.extraTwo)
                    }
                }

                Divider()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .padding(10)
            .frame(width: 220)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(settings: settings)
        }
    }
}
