//
//  VideoTransformations.swift
//  BlackboxPlayer
//
//  Video transformation parameters for brightness, flip, and zoom effects.
//

import Foundation
import Combine

/// Video transformation settings that can be applied to rendered video
struct VideoTransformations: Codable, Equatable {
    /// Brightness adjustment (-1.0 to 1.0, where 0.0 is neutral)
    var brightness: Float = 0.0

    /// Horizontal flip (mirror horizontally)
    var flipHorizontal: Bool = false

    /// Vertical flip (mirror vertically)
    var flipVertical: Bool = false

    /// Digital zoom level (1.0 = no zoom, 2.0 = 2x zoom, etc.)
    var zoomLevel: Float = 1.0

    /// Zoom center X coordinate (0.0 to 1.0, where 0.5 is center)
    var zoomCenterX: Float = 0.5

    /// Zoom center Y coordinate (0.0 to 1.0, where 0.5 is center)
    var zoomCenterY: Float = 0.5

    /// Reset all transformations to default values
    mutating func reset() {
        brightness = 0.0
        flipHorizontal = false
        flipVertical = false
        zoomLevel = 1.0
        zoomCenterX = 0.5
        zoomCenterY = 0.5
    }

    /// Check if any transformations are active
    var hasActiveTransformations: Bool {
        return brightness != 0.0 ||
               flipHorizontal ||
               flipVertical ||
               zoomLevel != 1.0
    }
}

/// Service for managing video transformation settings
class VideoTransformationService: ObservableObject {
    static let shared = VideoTransformationService()

    private let userDefaults = UserDefaults.standard
    private let transformationsKey = "VideoTransformations"

    /// Current transformation settings
    @Published var transformations = VideoTransformations()

    private init() {
        loadTransformations()
    }

    /// Load transformation settings from UserDefaults
    func loadTransformations() {
        guard let data = userDefaults.data(forKey: transformationsKey),
              let loaded = try? JSONDecoder().decode(VideoTransformations.self, from: data) else {
            infoLog("[VideoTransformationService] No saved transformations found, using defaults")
            return
        }

        transformations = loaded
        infoLog("[VideoTransformationService] Loaded transformations: brightness=\(loaded.brightness), flipH=\(loaded.flipHorizontal), flipV=\(loaded.flipVertical), zoom=\(loaded.zoomLevel)")
    }

    /// Save transformation settings to UserDefaults
    func saveTransformations() {
        guard let data = try? JSONEncoder().encode(transformations) else {
            errorLog("[VideoTransformationService] Failed to encode transformations")
            return
        }

        userDefaults.set(data, forKey: transformationsKey)
        debugLog("[VideoTransformationService] Saved transformations: brightness=\(transformations.brightness), flipH=\(transformations.flipHorizontal), flipV=\(transformations.flipVertical), zoom=\(transformations.zoomLevel)")
    }

    /// Update brightness level
    func setBrightness(_ value: Float) {
        let clamped = max(-1.0, min(1.0, value))
        transformations.brightness = clamped
        saveTransformations()
    }

    /// Toggle horizontal flip
    func toggleFlipHorizontal() {
        transformations.flipHorizontal.toggle()
        saveTransformations()
    }

    /// Toggle vertical flip
    func toggleFlipVertical() {
        transformations.flipVertical.toggle()
        saveTransformations()
    }

    /// Set zoom level
    func setZoomLevel(_ level: Float) {
        let clamped = max(1.0, min(5.0, level))
        transformations.zoomLevel = clamped
        saveTransformations()
    }

    /// Set zoom center point
    func setZoomCenter(x: Float, y: Float) {
        transformations.zoomCenterX = max(0.0, min(1.0, x))
        transformations.zoomCenterY = max(0.0, min(1.0, y))
        saveTransformations()
    }

    /// Reset all transformations
    func resetTransformations() {
        transformations.reset()
        saveTransformations()
        infoLog("[VideoTransformationService] Reset all transformations to default")
    }
}
