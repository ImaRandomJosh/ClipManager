import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var clipboardManager: ClipboardManager

    @State private var showResetDefaultsAlert = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Font", selection: $settings.fontName) {
                    ForEach(settings.fontChoices, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }

                HStack {
                    Text("Font Size")
                    Slider(value: $settings.fontSize, in: 11...24, step: 1)
                    Text("\(Int(settings.fontSize))")
                        .frame(width: 32)
                }

                HStack {
                    Text("Background Opacity")
                    Slider(value: $settings.backgroundOpacity, in: 0...1, step: 0.05)
                    Text("\(Int(settings.backgroundOpacity * 100))%")
                        .frame(width: 45)
                }

                HStack {
                    Button("Choose Background Image") {
                        settings.chooseBackgroundImage()
                    }

                    if settings.backgroundImage != nil {
                        Button("Remove Background", role: .destructive) {
                            settings.clearBackgroundImage()
                        }
                    }
                }
            }

            Section("Behavior") {
                Stepper(
                    "History Limit: \(settings.historyLimit)",
                    value: $settings.historyLimit,
                    in: 5...200,
                    step: 5
                )

                Toggle("Copy item immediately when clicked", isOn: $settings.copyOnSelection)

                Toggle(
                    "Open at Login",
                    isOn: Binding(
                        get: { clipboardManager.launchAtLoginEnabled },
                        set: { _ in
                            clipboardManager.toggleLaunchAtLogin()
                        }
                    )
                )
            }

            Section("Danger Zone") {
                Button("Reset to Default Settings", role: .destructive) {
                    showResetDefaultsAlert = true
                }

                Button("Clear Clipboard History", role: .destructive) {
                    clipboardManager.clearHistory()
                }
            }
        }
        .padding(20)
        .frame(width: 520)
        .alert("Reset settings?", isPresented: $showResetDefaultsAlert) {
            Button("Cancel", role: .cancel) { }

            Button("Confirm Reset", role: .destructive) {
                settings.resetToDefaults()
            }
        } message: {
            Text("This will restore the default appearance and behavior settings.")
        }
    }
}
