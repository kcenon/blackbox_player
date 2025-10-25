/// @file AppSettings.swift
/// @brief App settings model
/// @author BlackboxPlayer Development Team
/// @details
/// Model that manages global app settings.
/// Uses UserDefaults to save and load settings.

import Foundation
import SwiftUI

/// @struct AppSettings
/// @brief App settings management class
/// @details
/// Implemented as ObservableObject to automatically update UI when settings change
class AppSettings: ObservableObject {
    // MARK: - Singleton

    static let shared = AppSettings()

    private init() {
        loadSettings()
    }

    // MARK: - UI Settings

    /// Show sidebar by default
    @Published var showSidebarByDefault: Bool = true {
        didSet { UserDefaults.standard.set(showSidebarByDefault, forKey: "showSidebarByDefault") }
    }

    /// Show debug log by default
    @Published var showDebugLogByDefault: Bool = false {
        didSet { UserDefaults.standard.set(showDebugLogByDefault, forKey: "showDebugLogByDefault") }
    }

    // MARK: - Overlay Settings

    /// Show GPS overlay by default
    @Published var showGPSOverlayByDefault: Bool = true {
        didSet { UserDefaults.standard.set(showGPSOverlayByDefault, forKey: "showGPSOverlayByDefault") }
    }

    /// Show metadata overlay by default
    @Published var showMetadataOverlayByDefault: Bool = true {
        didSet { UserDefaults.standard.set(showMetadataOverlayByDefault, forKey: "showMetadataOverlayByDefault") }
    }

    /// Show map overlay by default
    @Published var showMapOverlayByDefault: Bool = true {
        didSet { UserDefaults.standard.set(showMapOverlayByDefault, forKey: "showMapOverlayByDefault") }
    }

    /// Show graph overlay by default
    @Published var showGraphOverlayByDefault: Bool = true {
        didSet { UserDefaults.standard.set(showGraphOverlayByDefault, forKey: "showGraphOverlayByDefault") }
    }

    // MARK: - Playback Settings

    /// Default playback speed
    @Published var defaultPlaybackSpeed: Double = 1.0 {
        didSet { UserDefaults.standard.set(defaultPlaybackSpeed, forKey: "defaultPlaybackSpeed") }
    }

    /// Default volume
    @Published var defaultVolume: Double = 0.8 {
        didSet { UserDefaults.standard.set(defaultVolume, forKey: "defaultVolume") }
    }

    /// Auto-play on selection
    @Published var autoPlayOnSelect: Bool = false {
        didSet { UserDefaults.standard.set(autoPlayOnSelect, forKey: "autoPlayOnSelect") }
    }

    // MARK: - Video Settings

    /// Default layout mode
    @Published var defaultLayoutMode: String = "grid" {
        didSet { UserDefaults.standard.set(defaultLayoutMode, forKey: "defaultLayoutMode") }
    }

    /// Controls auto-hide delay (seconds)
    @Published var controlsAutoHideDelay: Double = 3.0 {
        didSet { UserDefaults.standard.set(controlsAutoHideDelay, forKey: "controlsAutoHideDelay") }
    }

    // MARK: - Performance Settings

    /// Target frame rate
    @Published var targetFrameRate: Int = 30 {
        didSet { UserDefaults.standard.set(targetFrameRate, forKey: "targetFrameRate") }
    }

    /// Use hardware acceleration
    @Published var useHardwareAcceleration: Bool = true {
        didSet { UserDefaults.standard.set(useHardwareAcceleration, forKey: "useHardwareAcceleration") }
    }

    // MARK: - Methods

    /// Load settings
    private func loadSettings() {
        let defaults = UserDefaults.standard

        // UI Settings
        if defaults.object(forKey: "showSidebarByDefault") != nil {
            showSidebarByDefault = defaults.bool(forKey: "showSidebarByDefault")
        }
        if defaults.object(forKey: "showDebugLogByDefault") != nil {
            showDebugLogByDefault = defaults.bool(forKey: "showDebugLogByDefault")
        }

        // Overlay Settings
        if defaults.object(forKey: "showGPSOverlayByDefault") != nil {
            showGPSOverlayByDefault = defaults.bool(forKey: "showGPSOverlayByDefault")
        }
        if defaults.object(forKey: "showMetadataOverlayByDefault") != nil {
            showMetadataOverlayByDefault = defaults.bool(forKey: "showMetadataOverlayByDefault")
        }
        if defaults.object(forKey: "showMapOverlayByDefault") != nil {
            showMapOverlayByDefault = defaults.bool(forKey: "showMapOverlayByDefault")
        }
        if defaults.object(forKey: "showGraphOverlayByDefault") != nil {
            showGraphOverlayByDefault = defaults.bool(forKey: "showGraphOverlayByDefault")
        }

        // Playback Settings
        if defaults.object(forKey: "defaultPlaybackSpeed") != nil {
            defaultPlaybackSpeed = defaults.double(forKey: "defaultPlaybackSpeed")
        }
        if defaults.object(forKey: "defaultVolume") != nil {
            defaultVolume = defaults.double(forKey: "defaultVolume")
        }
        if defaults.object(forKey: "autoPlayOnSelect") != nil {
            autoPlayOnSelect = defaults.bool(forKey: "autoPlayOnSelect")
        }

        // Video Settings
        if let layoutMode = defaults.string(forKey: "defaultLayoutMode") {
            defaultLayoutMode = layoutMode
        }
        if defaults.object(forKey: "controlsAutoHideDelay") != nil {
            controlsAutoHideDelay = defaults.double(forKey: "controlsAutoHideDelay")
        }

        // Performance Settings
        if defaults.object(forKey: "targetFrameRate") != nil {
            targetFrameRate = defaults.integer(forKey: "targetFrameRate")
        }
        if defaults.object(forKey: "useHardwareAcceleration") != nil {
            useHardwareAcceleration = defaults.bool(forKey: "useHardwareAcceleration")
        }
    }

    /// Reset settings to defaults
    func resetToDefaults() {
        // UI Settings
        showSidebarByDefault = true
        showDebugLogByDefault = false

        // Overlay Settings
        showGPSOverlayByDefault = true
        showMetadataOverlayByDefault = true
        showMapOverlayByDefault = true
        showGraphOverlayByDefault = true

        // Playback Settings
        defaultPlaybackSpeed = 1.0
        defaultVolume = 0.8
        autoPlayOnSelect = false

        // Video Settings
        defaultLayoutMode = "grid"
        controlsAutoHideDelay = 3.0

        // Performance Settings
        targetFrameRate = 30
        useHardwareAcceleration = true
    }
}
