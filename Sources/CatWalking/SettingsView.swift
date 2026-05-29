import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Appearance") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Cat Scale")
                        Spacer()
                        Text(String(format: "%.1fx", settings.catScale))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.catScale, in: 1 ... 4, step: 0.5)
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
            }

            Section("Enabled Animations") {
                Toggle("Walk Down", isOn: $settings.enableWalkDown)
                Toggle("Walk Left", isOn: $settings.enableWalkLeft)
                Toggle("Walk Right", isOn: $settings.enableWalkRight)
                Toggle("Walk Up", isOn: $settings.enableWalkUp)
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
