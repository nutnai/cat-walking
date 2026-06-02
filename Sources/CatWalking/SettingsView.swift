import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    private var isAnimationPresetLocked: Bool {
        !settings.isCustomBehaviorPreset
    }

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "Version \(shortVersion) (Build \(buildVersion))"
    }

    private func speechBubbleMessageBinding(for index: Int) -> Binding<String> {
        Binding(
            get: {
                guard settings.speechBubbleMessages.indices.contains(index) else {
                    return ""
                }
                return settings.speechBubbleMessages[index]
            },
            set: { settings.updateSpeechBubbleMessage(at: index, to: $0) }
        )
    }

    private var speechBubbleMessages: [String] {
        settings.speechBubbleMessages
    }

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
            Section("System") {
                Toggle("Stay on Top", isOn: $settings.stayOnTop)
                Toggle("Open at Login", isOn: $settings.openAtLogin)

                Text(appVersionText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

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
                        in: 0.1 ... 10.0,
                        step: 0.1
                    )
                }
            }

            Section("Speech Bubble") {
                Toggle("Enable Cat Speech", isOn: $settings.enableSpeechBubble)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Speech Chance")
                        Spacer()
                        Text(String(format: "%.0f%%", settings.speechBubbleChance * 100))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.speechBubbleChance, in: 0 ... 1, step: 0.01)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Bubble Duration")
                        Spacer()
                        Text(String(format: "%.1f s", settings.speechBubbleDuration))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.speechBubbleDuration, in: 0.5 ... 10, step: 0.5)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Bubble Color")
                        Spacer()
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: settings.speechBubbleColor))
                            .frame(width: 44, height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Red")
                            Spacer()
                            Text(String(format: "%.0f%%", settings.speechBubbleColorRed * 100))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.speechBubbleColorRed, in: 0 ... 1, step: 0.05)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Green")
                            Spacer()
                            Text(String(format: "%.0f%%", settings.speechBubbleColorGreen * 100))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.speechBubbleColorGreen, in: 0 ... 1, step: 0.05)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Blue")
                            Spacer()
                            Text(String(format: "%.0f%%", settings.speechBubbleColorBlue * 100))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.speechBubbleColorBlue, in: 0 ... 1, step: 0.05)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Speech Text List")
                    Text("Add, edit, or delete phrases one by one.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(speechBubbleMessages.enumerated()), id: \.offset) { index, message in
                            HStack(spacing: 4) {
                                Text("\(index + 1).")
                                    .frame(minWidth: 20, alignment: .leading)

                                TextField(
                                    "",
                                    text: speechBubbleMessageBinding(for: index)
                                )
                                .textFieldStyle(.roundedBorder)

                                Button(role: .destructive) {
                                    settings.removeSpeechBubbleMessage(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }

                        Button {
                            settings.addSpeechBubbleMessage()
                        } label: {
                            Label("Add New Text", systemImage: "plus")
                        }
                    }
                }
            }

            Section("Animation") {
                Picker("Behavior Preset", selection: $settings.behaviorPreset) {
                    ForEach(AppSettings.BehaviorPreset.allCases) { preset in
                        Text(preset.displayName)
                            .tag(preset)
                    }
                }

                if isAnimationPresetLocked {
                    Text("This preset controls animation tuning values only. Vertical and animation-enable settings stay editable.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Animation Speed")
                        Spacer()
                        Text(String(format: "%.0f fps", settings.animationFPS))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.animationFPS, in: 4 ... 8, step: 1)
                }
                .disabled(isAnimationPresetLocked)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Movement Speed")
                        Spacer()
                        Text(String(format: "%.0f pt/s", settings.movementSpeed))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.movementSpeed, in: 30 ... 260, step: 5)
                }
                .disabled(isAnimationPresetLocked)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Sit Frequency")
                        Spacer()
                        Text(String(format: "%.0f%%", settings.sitPreference * 100))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.sitPreference, in: 0 ... 1, step: 0.05)
                }
                .disabled(isAnimationPresetLocked)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Sleep Frequency")
                        Spacer()
                        Text(String(format: "%.0f%%", settings.sleepFrequency * 100))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.sleepFrequency, in: 0 ... 1, step: 0.05)
                }
                .disabled(isAnimationPresetLocked)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Lazy Percentage")
                        Spacer()
                        Text(String(format: "%.0f%%", settings.lazyPercentage * 100))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.lazyPercentage, in: 0 ... 1, step: 0.05)
                }
                .disabled(isAnimationPresetLocked)
            }

            Section("Vertical Movement") {
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
                Group {
                    Toggle("Walk Left", isOn: $settings.enableWalkLeft)
                    Toggle("Walk Right", isOn: $settings.enableWalkRight)
                    Toggle("Idle", isOn: $settings.enableIdle)
                    Toggle("Groom", isOn: $settings.enableGroom)
                    Toggle("Sleep", isOn: $settings.enableSleep)
                }

                Text("If every automatic animation is disabled, the app still uses idle as a safe fallback so the pet stays visible.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }
}
