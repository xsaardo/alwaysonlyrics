import SwiftUI

/// Preferences window for application settings
struct PreferencesWindow: View {

    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            // Settings content
            Form {
                Section {
                    windowBehaviorSection
                }

                Section {
                    appearanceSection
                }

                Section {
                    lyricsSection
                }

                Section {
                    generalSection
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 500, height: 560)
    }

    // MARK: - Window Behavior Section

    private var windowBehaviorSection: some View {
        Group {
            Text("Window Behavior")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.top, 8)

            Toggle("Always on top", isOn: $settings.alwaysOnTop)
                .help("Keep the lyrics window floating above other windows")

            Toggle("Remember window position", isOn: $settings.rememberWindowPosition)
                .help("Restore window position when app launches")

            Toggle("Remember window size", isOn: $settings.rememberWindowSize)
                .help("Restore window size when app launches")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Window opacity")
                    Spacer()
                    Text("\(Int(settings.windowOpacity * 100))%")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .frame(minWidth: 40, alignment: .trailing)
                }

                Slider(value: $settings.windowOpacity, in: 0.3...1.0, step: 0.05)
                    .help("Adjust window transparency")

                Text("Lower values make the window more transparent")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Group {
            Text("Appearance")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Font size")
                    Spacer()
                    Text("\(Int(settings.fontSize))pt")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .frame(minWidth: 40, alignment: .trailing)
                }

                Slider(value: $settings.fontSize, in: 10...24, step: 1)
                    .help("Adjust lyrics text size")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Line spacing")
                    Spacer()
                    Text("\(Int(settings.lineSpacing))pt")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .frame(minWidth: 40, alignment: .trailing)
                }

                Slider(value: $settings.lineSpacing, in: 0...16, step: 2)
                    .help("Adjust space between lyrics lines")
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Lyrics Section

    private var lyricsSection: some View {
        Group {
            Text("Lyrics")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.top, 8)

            Toggle("Show synced lyrics when available", isOn: $settings.enableSyncedLyrics)
                .help("Display time-synchronized lyrics that highlight and scroll automatically")

            Text("When disabled, plain text lyrics will be displayed")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Group {
            Text("General")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.top, 8)

            Toggle("Launch at login", isOn: $settings.launchAtLogin)
                .help("Automatically start AlwaysOnLyrics when you log in")

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Actions

    private func resetToDefaults() {
        settings.resetToDefaults()
    }
}

// MARK: - Preview

#Preview {
    PreferencesWindow()
}
