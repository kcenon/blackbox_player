/// @file SettingsView.swift
/// @brief App settings page
/// @author BlackboxPlayer Development Team
/// @details
/// Settings page that manages all app settings.
/// Groups settings by category for display.

import SwiftUI

/// App settings view
///
/// ## Settings Categories
/// - UI Settings: Sidebar, debug log display options
/// - Overlay Settings: GPS, metadata, map, graph overlay defaults
/// - Playback Settings: Default playback speed, volume, auto-play
/// - Video Settings: Layout mode, control auto-hide duration
/// - Performance Settings: Frame rate, hardware acceleration
///
/// ## Usage Example
/// ```swift
/// .sheet(isPresented: $showSettings) {
///     SettingsView()
/// }
/// ```
struct SettingsView: View {
    // MARK: - Properties

    /// App settings (Singleton)
    @ObservedObject var settings = AppSettings.shared

    /// Action to dismiss settings window
    @Environment(\.dismiss) private var dismiss

    /// Whether to show reset confirmation alert
    @State private var showResetAlert = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Settings content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    uiSettingsSection
                    overlaySettingsSection
                    playbackSettingsSection
                    videoSettingsSection
                    performanceSettingsSection
                }
                .padding(24)
            }

            Divider()

            // Footer buttons
            footer
        }
        .frame(width: 600, height: 700)
        .alert("Reset Settings", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.resetToDefaults()
            }
        } message: {
            Text("Are you sure you want to reset all settings to default values?")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding()
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(action: { showResetAlert = true }) {
                Text("Reset to Defaults")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: { dismiss() }) {
                Text("Done")
                    .frame(width: 80)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - UI Settings Section

    private var uiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "UI Settings",
                icon: "sidebar.left",
                description: "User interface display settings"
            )

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $settings.showSidebarByDefault) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Sidebar by Default")
                            .font(.body)
                        Text("Display sidebar when app launches")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $settings.showDebugLogByDefault) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Debug Log by Default")
                            .font(.body)
                        Text("Display debug log when app launches")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }

    // MARK: - Overlay Settings Section

    private var overlaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Overlay Settings",
                icon: "square.stack.3d.up",
                description: "Information layers displayed over video"
            )

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $settings.showGPSOverlayByDefault) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show GPS Overlay by Default")
                            .font(.body)
                        Text("Display GPS information such as speed and coordinates")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $settings.showMetadataOverlayByDefault) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Metadata Overlay by Default")
                            .font(.body)
                        Text("Display video file information")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $settings.showMapOverlayByDefault) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Map Overlay by Default")
                            .font(.body)
                        Text("Display GPS trajectory on map")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $settings.showGraphOverlayByDefault) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Graph Overlay by Default")
                            .font(.body)
                        Text("Display graphs such as speed and acceleration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }

    // MARK: - Playback Settings Section

    private var playbackSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Playback Settings",
                icon: "play.circle",
                description: "Video playback related settings"
            )

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Default Playback Speed")
                            .font(.body)
                        Spacer()
                        Text(String(format: "%.2fx", settings.defaultPlaybackSpeed))
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $settings.defaultPlaybackSpeed, in: 0.25...4.0, step: 0.25)

                    HStack {
                        Text("0.25x")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("4.0x")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Default Volume")
                            .font(.body)
                        Spacer()
                        Text("\(Int(settings.defaultVolume * 100))%")
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $settings.defaultVolume, in: 0.0...1.0, step: 0.05)

                    HStack {
                        Text("0%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $settings.autoPlayOnSelect) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-play on File Selection")
                            .font(.body)
                        Text("Automatically start playback when a file is selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }

    // MARK: - Video Settings Section

    private var videoSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Video Settings",
                icon: "video",
                description: "Video display related settings"
            )

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Layout Mode")
                        .font(.body)

                    Picker("", selection: $settings.defaultLayoutMode) {
                        Text("Grid").tag("grid")
                        Text("Single").tag("single")
                        Text("PIP").tag("pip")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Controls Auto-hide Duration")
                            .font(.body)
                        Spacer()
                        Text(String(format: "%.1fs", settings.controlsAutoHideDelay))
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $settings.controlsAutoHideDelay, in: 1.0...10.0, step: 0.5)

                    HStack {
                        Text("1s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("10s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }

    // MARK: - Performance Settings Section

    private var performanceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Performance Settings",
                icon: "speedometer",
                description: "Video playback performance related settings"
            )

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Target Frame Rate")
                            .font(.body)
                        Spacer()
                        Text("\(settings.targetFrameRate) FPS")
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    Picker("", selection: $settings.targetFrameRate) {
                        Text("24 FPS").tag(24)
                        Text("30 FPS").tag(30)
                        Text("60 FPS").tag(60)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Toggle(isOn: $settings.useHardwareAcceleration) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use Hardware Acceleration")
                            .font(.body)
                        Text("Improve video decoding performance using GPU")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }

    // MARK: - Helper Views

    /// Section header
    private func sectionHeader(title: String, icon: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
