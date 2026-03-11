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
            }

            Section("Background") {
                HStack {
                    Text("Current Background")
                    Spacer()
                    Text(settings.activeBackgroundDescription)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Background Opacity")
                    Slider(value: $settings.backgroundOpacity, in: 0...1, step: 0.05)
                    Text("\(Int(settings.backgroundOpacity * 100))%")
                        .frame(width: 45)
                }

                HStack(spacing: 12) {
                    Button("Choose Image") {
                        settings.chooseBackgroundImage()
                    }

                    Button("Choose Video") {
                        settings.chooseBackgroundVideo()
                    }

                    if settings.backgroundImage != nil || settings.backgroundVideoURL != nil {
                        Button("Remove Background", role: .destructive) {
                            settings.clearBackgroundMedia()
                        }
                    }
                }
                
                HStack {
                    Text("Overlay Scale")
                    Slider(value: $settings.overlayScale, in: 0.75...1.75, step: 0.05)
                    Text(String(format: "%.2fx", settings.overlayScale))
                        .frame(width: 45)
                }
                

                Text("Videos are muted, loop automatically, and must be 60 seconds or shorter.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Behavior") {
                Stepper(
                    "History Limit: \(settings.historyLimit)",
                    value: $settings.historyLimit,
                    in: 5...200,
                    step: 5
                )
                
                Toggle("Copy item immediately when clicked", isOn: $settings.copyOnSelection)
                
                Toggle("Hide from Dock", isOn: $settings.hideFromDock)

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
        .frame(width: 560)
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
