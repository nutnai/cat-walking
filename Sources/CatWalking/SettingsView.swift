import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    private var availableCatTemplates: [String] {
        [SpriteSheet.defaultTemplateSelection] + SpriteSheet.availableTemplateNames()
    }

    private var maximumVerticalRange: Double {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 1600
        return max(40, screenHeight)
    }

    private var maximumVerticalOffset: Double {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 1600
        return max(0, screenHeight)
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Cat Template", selection: $settings.selectedCatTemplate) {
                    ForEach(availableCatTemplates, id: \.self) { templateName in
                        Text(SpriteSheet.displayName(for: templateName))
                            .tag(templateName)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Cat Scale")
                        Spacer()
                        Text(String(format: "%.1fx", settings.catScale))
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $settings.catScale,
                        in: 0.1 ... 2.0,
                        step: 0.1
                    )
                }

                Toggle("Stay on Top", isOn: $settings.stayOnTop)
            }

            Section("Animation") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Animation Speed")
                        Spacer()
                        Text(String(format: "%.0f fps", settings.animationFPS))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.animationFPS, in: 4 ... 8, step: 1)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Movement Speed")
                        Spacer()
                        Text(String(format: "%.0f pt/s", settings.movementSpeed))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.movementSpeed, in: 30 ... 260, step: 5)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Sit Frequency")
                        Spacer()
                        Text(String(format: "%.0f%%", settings.sitPreference * 100))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.sitPreference, in: 0 ... 1, step: 0.05)
                }

                Toggle("Enable Move Up and Down", isOn: $settings.enableVerticalMovement)

                HStack {
                    Toggle("Walk Up", isOn: $settings.enableWalkUp)
                    Toggle("Walk Down", isOn: $settings.enableWalkDown)
                }
                .disabled(!settings.enableVerticalMovement)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Default Y Axis")
                        Spacer()
                        Text(String(format: "%.0f pt", settings.defaultYOffset))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.defaultYOffset, in: 0 ... maximumVerticalOffset, step: 10)
                }
                .disabled(!settings.enableVerticalMovement)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Vertical Range")
                        Spacer()
                        Text(String(format: "%.0f pt", settings.verticalMovementRange))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.verticalMovementRange, in: 40 ... maximumVerticalRange, step: 10)
                }
                .disabled(!settings.enableVerticalMovement)
            }

            Section("Enabled Animations") {
                Toggle("Walk Left", isOn: $settings.enableWalkLeft)
                Toggle("Walk Right", isOn: $settings.enableWalkRight)
                Toggle("Idle", isOn: $settings.enableIdle)
                Toggle("Groom", isOn: $settings.enableGroom)

                Text("If all animations are disabled, the app falls back to idle.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }
}
