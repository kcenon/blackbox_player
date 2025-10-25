/// @file VideoTransformations.swift
/// @brief Video transformation parameters for brightness, flip, and zoom effects
/// @author BlackboxPlayer Development Team
/// @details
/// This file defines visual effects that can be applied to video in real-time during playback.
/// Provides parameters for GPU shaders to perform transformations such as brightness adjustment, flipping, and digital zoom.

/**
 # VideoTransformations - Video Transformation Effects

 ## 🎨 What are Video Transformations?

 Visual effects that can be applied to video in real-time during playback.

 ### Supported transformation effects:

 1. **Brightness Adjustment**
 - Make video brighter or darker
 - Useful for improving night footage

 2. **Horizontal Flip**
 - Flip video left-to-right
 - Useful for rear-view mirror footage

 3. **Vertical Flip**
 - Flip video upside-down
 - Correct for upside-down camera installation

 4. **Digital Zoom**
 - Magnify specific portions of video
 - Useful for examining license plates, etc.

 ## 🎯 How It Works

 ### Processing in GPU Shader:
 ```
 Original Frame
 ↓
 Fragment Shader (GPU)
 ↓ Apply transformation parameters
 - brightness: Adjust pixel brightness
 - flip: Invert coordinates
 - zoom: Magnify coordinates
 ↓
 Transformed Frame
 ```

 ### Shader Code Example:
 ```metal
 // Metal Shader
 fragment float4 videoFragmentShader(
 VertexOut in [[stage_in]],
 texture2d<float> texture [[texture(0)]],
 constant Transforms &transforms [[buffer(0)]]
 ) {
 // 1. Coordinate transformation (zoom, flip)
 float2 coord = in.texCoord;

 // Horizontal flip
 if (transforms.flipH) {
 coord.x = 1.0 - coord.x;
 }

 // Apply zoom
 coord = (coord - transforms.zoomCenter) / transforms.zoomLevel + transforms.zoomCenter;

 // 2. Texture sampling
 float4 color = texture.sample(sampler, coord);

 // 3. Brightness adjustment
 color.rgb += transforms.brightness;

 return color;
 }
 ```

 ## 💡 Real-time Processing

 ### Why process on GPU?
 - CPU: Sequential processing of 1920×1080 = 2,073,600 pixels (slow)
 - GPU: Parallel processing of all pixels (fast, maintains 60fps)

 ### Performance Impact:
 - Transformation effects are processed on GPU, minimal performance impact
 - No frame drops even with all effects applied simultaneously

 ## 📚 Usage Examples

 ```swift
 // 1. Access service (singleton)
 let service = VideoTransformationService.shared

 // 2. Adjust brightness (+30%)
 service.setBrightness(0.3)

 // 3. Toggle horizontal flip
 service.toggleFlipHorizontal()

 // 4. Digital zoom (2x magnification)
 service.setZoomLevel(2.0)
 service.setZoomCenter(x: 0.7, y: 0.3)  // Magnify upper-right

 // 5. Reset all effects
 service.resetTransformations()
 ```

 ## 🔄 Persistence

 Settings are automatically saved to UserDefaults and persisted across app restarts.

 ```
 App Launch
 ↓
 Load settings from UserDefaults
 ↓
 User adjusts brightness
 ↓
 Immediately save to UserDefaults
 ↓
 App Quit
 ↓
 Settings persisted
 ```

 ---

 This module provides real-time transformation effects to help users view video more clearly.
 */

import Foundation
import Combine

// MARK: - Video Transformations Struct

/// @struct VideoTransformations
/// @brief Structure containing video transformation parameters to pass to GPU shader
///
/// @details
/// ## Features:
/// - **Codable**: Can be serialized/deserialized to/from JSON (save/load)
/// - **Equatable**: Can compare if two settings are the same
/// - **Value type (struct)**: Independent copy created when copied
///
/// ## Integration with GPU Shader:
/// ```swift
/// // Swift side:
/// let transforms = VideoTransformations(brightness: 0.3)
///
/// // GPU side (Metal Shader):
/// struct Transforms {
///     float brightness;
///     bool flipHorizontal;
///     bool flipVertical;
///     float zoomLevel;
///     float2 zoomCenter;
/// };
/// ```
///
/// ## Memory Layout:
/// ```
/// Swift struct → 24 bytes → GPU Uniform Buffer
/// ┌──────────────┬──────────┬──────────┬──────────┬────────────┐
/// │ brightness   │ flipH    │ flipV    │ zoomLvl  │ zoomCenter │
/// │ 4 bytes      │ 1 byte   │ 1 byte   │ 4 bytes  │ 8 bytes    │
/// └──────────────┴──────────┴──────────┴──────────┴────────────┘
/// ```
struct VideoTransformations: Codable, Equatable {

    // MARK: - Properties

    /// @var brightness
    /// @brief Brightness adjustment (-1.0 ~ +1.0)
    /// @details
    /// Value meanings:
    /// - **-1.0**: Completely dark (black)
    /// - **-0.5**: 50% darker
    /// - **0.0**: No change (default)
    /// - **+0.5**: 50% brighter
    /// - **+1.0**: Completely bright (white)
    ///
    /// How it works:
    /// ```
    /// In shader:
    /// outputColor.rgb = originalColor.rgb + brightness
    ///
    /// Example: Gray pixel (0.5, 0.5, 0.5)
    /// - brightness = +0.3 → (0.8, 0.8, 0.8) brighter
    /// - brightness = -0.3 → (0.2, 0.2, 0.2) darker
    /// ```
    ///
    /// Cautions:
    /// - Too high value: Overexposure (washed out white)
    /// - Too low value: Underexposure (crushed blacks)
    /// - Recommended range: -0.5 ~ +0.5
    var brightness: Float = 0.0

    /// @var flipHorizontal
    /// @brief Horizontal flip
    /// @details
    /// Flips the video left-to-right. Appears like a mirror image.
    ///
    /// Usage example:
    /// ```
    /// Original:            After flip:
    /// ┌──────────┐         ┌──────────┐
    /// │  ←  Car  │    →    │  Car  →  │
    /// └──────────┘         └──────────┘
    /// ```
    ///
    /// How it works:
    /// ```
    /// In shader:
    /// if (flipHorizontal) {
    ///     texCoord.x = 1.0 - texCoord.x;
    /// }
    ///
    /// Example: texCoord.x = 0.2 (20% from left)
    ///      → 1.0 - 0.2 = 0.8 (80% from left)
    /// ```
    ///
    /// Use cases:
    /// - Correcting rear-view mirror footage
    /// - Correcting left-right reversed camera
    var flipHorizontal: Bool = false

    /// @var flipVertical
    /// @brief Vertical flip
    /// @details
    /// Flips the video upside-down.
    ///
    /// Usage example:
    /// ```
    /// Original:            After flip:
    /// ┌──────────┐         ┌──────────┐
    /// │   Sky    │         │   Road   │
    /// │   Road   │    →    │   Sky    │
    /// └──────────┘         └──────────┘
    /// ```
    ///
    /// How it works:
    /// ```
    /// In shader:
    /// if (flipVertical) {
    ///     texCoord.y = 1.0 - texCoord.y;
    /// }
    /// ```
    ///
    /// Use cases:
    /// - Correcting upside-down camera installation
    /// - Ceiling-mounted cameras
    var flipVertical: Bool = false

    /// @var zoomLevel
    /// @brief Digital zoom level (1.0 ~ 5.0)
    /// @details
    /// Magnification factor for the video.
    ///
    /// Value meanings:
    /// - **1.0**: No magnification (original size) - default
    /// - **1.5**: 1.5x magnification
    /// - **2.0**: 2x magnification
    /// - **3.0**: 3x magnification
    /// - **5.0**: 5x magnification (maximum)
    ///
    /// Zoom principle:
    /// ```
    /// Zoom level = 2.0 (2x magnification):
    ///
    /// Original video area:     Displayed on screen:
    /// ┌─────────────────┐      ┌─────────────────┐
    /// │ ┌─────────────┐ │      │                 │
    /// │ │  Crop this   │ │  →   │  Magnify 2x to  │
    /// │ │  portion     │ │      │  fill screen    │
    /// │ └─────────────┘ │      │                 │
    /// └─────────────────┘      └─────────────────┘
    ///  (50% area)              (100% screen)
    /// ```
    ///
    /// Shader formula:
    /// ```
    /// newCoord = (originalCoord - zoomCenter) / zoomLevel + zoomCenter
    ///
    /// Example: zoomLevel = 2.0, zoomCenter = (0.5, 0.5)
    /// - (0.0, 0.0) → (0.25, 0.25)  top-left → near center
    /// - (1.0, 1.0) → (0.75, 0.75)  bottom-right → near center
    /// - (0.5, 0.5) → (0.5, 0.5)    center → center (fixed)
    /// ```
    ///
    /// Quality loss:
    /// - Digital zoom magnifies original pixels
    /// - Higher magnification = more quality degradation (pixels become visible)
    /// - Different from optical zoom (lens)
    var zoomLevel: Float = 1.0

    /// @var zoomCenterX
    /// @brief Zoom center X coordinate (0.0 ~ 1.0)
    /// @details
    /// Horizontal position to use as the center when magnifying.
    ///
    /// Normalized Coordinates:
    /// - **0.0**: Left edge
    /// - **0.5**: Center (default)
    /// - **1.0**: Right edge
    ///
    /// Visual example:
    /// ```
    /// 0.0              0.5              1.0
    ///  ↓                ↓                ↓
    /// ┌────────────────┬────────────────┐
    /// │ Left           │ Center │ Right │
    /// └────────────────┴────────────────┘
    /// ```
    ///
    /// Usage examples:
    /// ```swift
    /// // Magnify right license plate
    /// service.setZoomCenter(x: 0.8, y: 0.5)
    /// service.setZoomLevel(3.0)
    ///
    /// // Magnify left side mirror
    /// service.setZoomCenter(x: 0.2, y: 0.6)
    /// service.setZoomLevel(2.5)
    /// ```
    var zoomCenterX: Float = 0.5

    /// @var zoomCenterY
    /// @brief Zoom center Y coordinate (0.0 ~ 1.0)
    /// @details
    /// Vertical position to use as the center when magnifying.
    ///
    /// Normalized coordinates:
    /// - **0.0**: Bottom (Metal coordinate system has origin at bottom-left)
    /// - **0.5**: Center (default)
    /// - **1.0**: Top
    ///
    /// Metal coordinate system:
    /// ```
    /// (0.0, 1.0) ────────── (1.0, 1.0)
    ///    │                      │
    ///    │      Screen          │
    ///    │                      │
    /// (0.0, 0.0) ────────── (1.0, 0.0)
    /// ```
    ///
    /// Note:
    /// - Opposite of typical screen coordinates (top-left origin)
    /// - Metal/OpenGL use bottom-left origin
    var zoomCenterY: Float = 0.5

    // MARK: - Methods

    /// @brief Reset all transformations
    ///
    /// @details
    /// Resets all parameters to their default values.
    ///
    /// Reset values:
    /// ```
    /// brightness    → 0.0   (no brightness adjustment)
    /// flipHorizontal → false (no flipping)
    /// flipVertical   → false (no flipping)
    /// zoomLevel      → 1.0   (no magnification)
    /// zoomCenterX    → 0.5   (center)
    /// zoomCenterY    → 0.5   (center)
    /// ```
    ///
    /// What is mutating?
    /// - structs are immutable by default
    /// - Methods that modify their own properties need mutating keyword
    /// - classes don't need mutating (reference type)
    ///
    /// Usage example:
    /// ```swift
    /// var transforms = VideoTransformations()
    /// transforms.brightness = 0.5
    /// transforms.zoomLevel = 2.0
    ///
    /// transforms.reset()
    /// // brightness = 0.0, zoomLevel = 1.0
    /// ```
    mutating func reset() {
        brightness = 0.0
        flipHorizontal = false
        flipVertical = false
        zoomLevel = 1.0
        zoomCenterX = 0.5
        zoomCenterY = 0.5
    }

    /// @var hasActiveTransformations
    /// @brief Check for active transformations
    /// @return true if one or more transformations are active, false if all values are at defaults
    /// @details
    /// Checks if any transformation is currently applied.
    ///
    /// Usage examples:
    /// ```swift
    /// // 1. Show/hide "Reset" button in UI
    /// if transforms.hasActiveTransformations {
    ///     showResetButton()  // Show button if transformations exist
    /// }
    ///
    /// // 2. Performance optimization (skip unnecessary shader processing)
    /// if !transforms.hasActiveTransformations {
    ///     // No transformations - render original (fast)
    ///     renderOriginal()
    /// } else {
    ///     // Transformations exist - apply shader (slower)
    ///     renderWithTransformations()
    /// }
    /// ```
    ///
    /// Checked conditions:
    /// ```
    /// brightness != 0.0      → Brightness adjustment active
    /// flipHorizontal == true → Horizontal flip active
    /// flipVertical == true   → Vertical flip active
    /// zoomLevel != 1.0       → Zoom active
    /// ```
    var hasActiveTransformations: Bool {
        return brightness != 0.0 ||
            flipHorizontal ||
            flipVertical ||
            zoomLevel != 1.0
    }
}

// MARK: - Video Transformation Service

/// @class VideoTransformationService
/// @brief Service that manages video transformation settings and persistently saves them to UserDefaults
///
/// @details
/// ## Main Responsibilities:
/// 1. Manage transformation parameters (brightness, flip, zoom)
/// 2. Automatically save/load to/from UserDefaults
/// 3. Value validation (range clamping)
/// 4. SwiftUI integration (@Published, ObservableObject)
///
/// ## Singleton Pattern:
/// ```
/// Only one instance used throughout the app
/// → All screens share the same settings
/// → Memory efficient
/// ```
///
/// ## SwiftUI Integration:
/// ```swift
/// struct SettingsView: View {
///     @ObservedObject var service = VideoTransformationService.shared
///
///     var body: some View {
///         Slider(value: $service.transformations.brightness)
///         // ↑ UI automatically updates when transformations change
///     }
/// }
/// ```
class VideoTransformationService: ObservableObject {

    // MARK: - Singleton

    /// @var shared
    /// @brief Singleton instance
    /// @details
    /// What is the Singleton Pattern?
    /// A pattern that creates only one instance of a class throughout the entire app.
    ///
    /// Advantages:
    /// - Global access
    /// - Memory savings (only one exists)
    /// - Easy state sharing
    ///
    /// Disadvantages:
    /// - Difficult to test
    /// - Hidden dependencies
    ///
    /// Usage example:
    /// ```swift
    /// // Accessible from anywhere:
    /// VideoTransformationService.shared.setBrightness(0.5)
    ///
    /// // Same instance even when accessed from multiple places:
    /// let service1 = VideoTransformationService.shared
    /// let service2 = VideoTransformationService.shared
    /// // service1 === service2 (true)
    /// ```
    static let shared = VideoTransformationService()

    // MARK: - Properties

    /// @var userDefaults
    /// @brief UserDefaults instance
    /// @details
    /// What is UserDefaults?
    /// A key-value store for saving simple app settings.
    ///
    /// Features:
    /// - Data persists after app termination
    /// - Only stores small data (settings, options, etc.)
    /// - Automatic encryption (iOS/macOS)
    ///
    /// Storage location:
    /// - macOS: ~/Library/Preferences/com.yourapp.plist
    /// - iOS: /Library/Preferences/
    ///
    /// Analogy:
    /// - UserDefaults = "Notepad"
    /// - Only write simple things (brightness, zoom, etc.)
    /// - Use files/databases for large data
    private let userDefaults = UserDefaults.standard

    /// @var transformationsKey
    /// @brief UserDefaults key
    /// @details
    /// Settings are saved/loaded using this key.
    /// ```
    /// UserDefaults:
    /// {
    ///     "VideoTransformations": {
    ///         "brightness": 0.3,
    ///         "flipHorizontal": true,
    ///         "flipVertical": false,
    ///         "zoomLevel": 2.0,
    ///         "zoomCenterX": 0.5,
    ///         "zoomCenterY": 0.5
    ///     }
    /// }
    /// ```
    private let transformationsKey = "VideoTransformations"

    /// @var transformations
    /// @brief Current transformation settings
    /// @details
    /// What is @Published?
    /// - Property wrapper from Combine framework
    /// - Automatically sends notification when value changes
    /// - SwiftUI Views update automatically
    ///
    /// How it works:
    /// ```
    /// transformations.brightness = 0.5  (value changed)
    ///      ↓
    /// @Published detects change
    ///      ↓
    /// objectWillChange.send()  (send notification)
    ///      ↓
    /// SwiftUI View automatically re-renders
    /// ```
    ///
    /// Subscription example:
    /// ```swift
    /// service.$transformations
    ///     .sink { newValue in
    ///         print("Transformation settings changed: \(newValue)")
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    @Published var transformations = VideoTransformations()

    // MARK: - Initialization

    /// @brief Private initialization
    ///
    /// @details
    /// What is private init()?
    /// - Cannot create instance from outside
    /// - Enforces singleton pattern
    ///
    /// Not allowed:
    /// ```swift
    /// let service = VideoTransformationService()  // Compile error!
    /// ```
    ///
    /// Allowed:
    /// ```swift
    /// let service = VideoTransformationService.shared  // OK
    /// ```
    ///
    /// Initialization behavior:
    /// 1. Load saved settings from UserDefaults
    /// 2. Use defaults if none exist
    private init() {
        loadTransformations()
    }

    // MARK: - Persistence Methods

    /// @brief Load settings from UserDefaults
    ///
    /// @details
    /// Called at app launch to restore previously saved settings.
    ///
    /// Processing flow:
    /// ```
    /// 1. Get Data from UserDefaults
    ///    ↓
    /// 2. Decode JSON → VideoTransformations
    ///    ↓
    /// 3. Set transformations property
    ///    ↓
    /// 4. Log success
    ///
    /// On failure:
    ///    → Use defaults (reset state)
    ///    → Log info
    /// ```
    ///
    /// What is JSONDecoder?
    /// A tool that converts JSON data into Swift objects.
    ///
    /// ```
    /// JSON Data (UserDefaults):
    /// {
    ///     "brightness": 0.3,
    ///     "flipHorizontal": true,
    ///     ...
    /// }
    ///     ↓ JSONDecoder
    /// VideoTransformations(
    ///     brightness: 0.3,
    ///     flipHorizontal: true,
    ///     ...
    /// )
    /// ```
    ///
    /// Exception handling:
    /// - No saved data → use defaults
    /// - JSON parsing failed → use defaults
    /// - Data corrupted → use defaults
    func loadTransformations() {
        // ===== Step 1: Get Data from UserDefaults =====
        guard let data = userDefaults.data(forKey: transformationsKey),
              // ===== Step 2: JSON decoding =====
              let loaded = try? JSONDecoder().decode(VideoTransformations.self, from: data) else {
            // Load failed → use defaults
            infoLog("[VideoTransformationService] No saved transformations found, using defaults")
            return
        }

        // ===== Step 3: Apply settings =====
        transformations = loaded

        // ===== Step 4: Log =====
        infoLog("[VideoTransformationService] Loaded transformations: brightness=\(loaded.brightness), flipH=\(loaded.flipHorizontal), flipV=\(loaded.flipVertical), zoom=\(loaded.zoomLevel)")
    }

    /// @brief Save settings to UserDefaults
    ///
    /// @details
    /// Called whenever transformation settings change to persist them.
    ///
    /// Processing flow:
    /// ```
    /// 1. Encode VideoTransformations → JSON
    ///    ↓
    /// 2. Save Data to UserDefaults
    ///    ↓
    /// 3. Automatically sync to disk
    ///    ↓
    /// 4. Log
    ///
    /// On failure:
    ///    → Only log error
    ///    → Settings remain in memory (retry on next save)
    /// ```
    ///
    /// What is JSONEncoder?
    /// A tool that converts Swift objects into JSON data.
    ///
    /// ```
    /// VideoTransformations(
    ///     brightness: 0.3,
    ///     flipHorizontal: true,
    ///     ...
    /// )
    ///     ↓ JSONEncoder
    /// JSON Data:
    /// {
    ///     "brightness": 0.3,
    ///     "flipHorizontal": true,
    ///     ...
    /// }
    /// ```
    ///
    /// Automatic invocation:
    /// All transformation methods (setBrightness, toggleFlip, etc.)
    /// automatically call this method.
    ///
    /// ```swift
    /// service.setBrightness(0.5)
    ///   ↓ internally calls
    /// saveTransformations()
    ///   ↓
    /// Saved to UserDefaults
    /// ```
    func saveTransformations() {
        // ===== Step 1: JSON encoding =====
        guard let data = try? JSONEncoder().encode(transformations) else {
            errorLog("[VideoTransformationService] Failed to encode transformations")
            return
        }

        // ===== Step 2: Save to UserDefaults =====
        // set(_:forKey:) returns immediately, syncs to disk in background
        userDefaults.set(data, forKey: transformationsKey)

        // ===== Step 3: Log =====
        debugLog("[VideoTransformationService] Saved transformations: brightness=\(transformations.brightness), flipH=\(transformations.flipHorizontal), flipV=\(transformations.flipVertical), zoom=\(transformations.zoomLevel)")
    }

    // MARK: - Transformation Methods

    /// @brief Set brightness
    ///
    /// @param value Brightness value (-1.0 ~ +1.0)
    ///
    /// @details
    /// Sets brightness value, validates range, then saves.
    ///
    /// Value validation (Clamping):
    /// ```
    /// Input range: -∞ ~ +∞
    ///      ↓ max(-1.0, ...)
    /// -1.0 ~ +∞
    ///      ↓ min(1.0, ...)
    /// -1.0 ~ +1.0 (final)
    /// ```
    ///
    /// max, min functions:
    /// ```swift
    /// max(-1.0, value)  // Limit to -1.0 if smaller
    /// min(1.0, value)   // Limit to 1.0 if larger
    ///
    /// Examples:
    /// - setBrightness(1.5)  → 1.0 (upper limit)
    /// - setBrightness(-2.0) → -1.0 (lower limit)
    /// - setBrightness(0.5)  → 0.5 (as is)
    /// ```
    ///
    /// Usage example:
    /// ```swift
    /// // Called from Slider
    /// Slider(value: $brightness, in: -1.0...1.0)
    ///     .onChange(of: brightness) { newValue in
    ///         service.setBrightness(newValue)
    ///     }
    /// ```
    func setBrightness(_ value: Float) {
        // ===== Value validation (Clamping) =====
        let clamped = max(-1.0, min(1.0, value))

        // ===== Apply setting =====
        transformations.brightness = clamped

        // ===== Auto save =====
        saveTransformations()
    }

    /// @brief Toggle horizontal flip
    ///
    /// @details
    /// Switches current state to opposite.
    ///
    /// What is toggle()?
    /// ```swift
    /// var flag = false
    /// flag.toggle()  // flag = true
    ///
    /// flag.toggle()  // flag = false
    /// ```
    ///
    /// Usage example:
    /// ```swift
    /// // On button click
    /// Button("Horizontal Flip") {
    ///     service.toggleFlipHorizontal()
    /// }
    ///
    /// // Keyboard shortcut
    /// .keyboardShortcut("h", modifiers: .command)
    /// ```
    ///
    /// State changes:
    /// ```
    /// false → toggle() → true  → toggle() → false
    /// (no flip)        (flipped)        (no flip)
    /// ```
    func toggleFlipHorizontal() {
        // ===== Toggle state =====
        transformations.flipHorizontal.toggle()

        // ===== Auto save =====
        saveTransformations()
    }

    /// @brief Toggle vertical flip
    ///
    /// @details
    /// Switches current state to opposite.
    ///
    /// Usage example:
    /// ```swift
    /// Button("Vertical Flip") {
    ///     service.toggleFlipVertical()
    /// }
    /// ```
    func toggleFlipVertical() {
        // ===== Toggle state =====
        transformations.flipVertical.toggle()

        // ===== Auto save =====
        saveTransformations()
    }

    /// @brief Set zoom level
    ///
    /// @param level Zoom magnification (1.0 ~ 5.0)
    ///
    /// @details
    /// Sets zoom magnification, validates range, then saves.
    ///
    /// Value validation:
    /// ```
    /// Minimum: 1.0 (original size)
    /// Maximum: 5.0 (5x magnification)
    ///
    /// Examples:
    /// - setZoomLevel(0.5)  → 1.0 (lower limit)
    /// - setZoomLevel(10.0) → 5.0 (upper limit)
    /// - setZoomLevel(2.5)  → 2.5 (as is)
    /// ```
    ///
    /// Usage example:
    /// ```swift
    /// // Zoom control with Slider
    /// Slider(value: $zoomLevel, in: 1.0...5.0, step: 0.1)
    ///     .onChange(of: zoomLevel) { newValue in
    ///         service.setZoomLevel(newValue)
    ///     }
    ///
    /// // Fixed magnification with buttons
    /// Button("2x Zoom") { service.setZoomLevel(2.0) }
    /// Button("Reset") { service.setZoomLevel(1.0) }
    /// ```
    ///
    /// Quality loss:
    /// - 1.0 ~ 2.0: Good quality
    /// - 2.0 ~ 3.0: Slightly pixelated
    /// - 3.0 ~ 5.0: Clearly pixelated
    func setZoomLevel(_ level: Float) {
        // ===== Value validation (1.0 ~ 5.0) =====
        let clamped = max(1.0, min(5.0, level))

        // ===== Apply setting =====
        transformations.zoomLevel = clamped

        // ===== Auto save =====
        saveTransformations()
    }

    /// @brief Set zoom center point
    ///
    /// @param x Horizontal center (0.0 ~ 1.0)
    /// @param y Vertical center (0.0 ~ 1.0)
    ///
    /// @details
    /// Sets the center coordinates of the area to magnify.
    ///
    /// Value validation:
    /// ```
    /// Both x and y limited to 0.0 ~ 1.0 range
    ///
    /// Examples:
    /// - x = -0.5 → 0.0 (left edge)
    /// - x = 1.5  → 1.0 (right edge)
    /// - x = 0.7  → 0.7 (70% from left)
    /// ```
    ///
    /// Usage examples:
    /// ```swift
    /// // Move zoom center with mouse click
    /// .onTapGesture { location in
    ///     let x = Float(location.x / viewWidth)
    ///     let y = Float(location.y / viewHeight)
    ///     service.setZoomCenter(x: x, y: y)
    /// }
    ///
    /// // Move to fixed positions
    /// Button("Top-left") { service.setZoomCenter(x: 0.25, y: 0.75) }
    /// Button("Center") { service.setZoomCenter(x: 0.5, y: 0.5) }
    /// Button("Bottom-right") { service.setZoomCenter(x: 0.75, y: 0.25) }
    /// ```
    ///
    /// Coordinate system note:
    /// - x: 0.0(left) ~ 1.0(right)
    /// - y: 0.0(bottom) ~ 1.0(top) ← Metal coordinate system!
    func setZoomCenter(x: Float, y: Float) {
        // ===== Value validation (0.0 ~ 1.0) =====
        transformations.zoomCenterX = max(0.0, min(1.0, x))
        transformations.zoomCenterY = max(0.0, min(1.0, y))

        // ===== Auto save =====
        saveTransformations()
    }

    /// @brief Reset all transformations
    ///
    /// @details
    /// Resets all transformation effects to default values.
    ///
    /// What gets reset:
    /// - Brightness → 0.0
    /// - Horizontal flip → off
    /// - Vertical flip → off
    /// - Zoom → 1.0 (original)
    /// - Zoom center → screen center
    ///
    /// Usage examples:
    /// ```swift
    /// // "Reset" button
    /// Button("Reset All") {
    ///     service.resetTransformations()
    /// }
    ///
    /// // Auto reset when loading new video
    /// func loadNewVideo() {
    ///     service.resetTransformations()
    ///     // ... load video
    /// }
    /// ```
    ///
    /// Effects:
    /// - Immediately restore to original video
    /// - Save to UserDefaults (reset state persists across launches)
    func resetTransformations() {
        // ===== Call VideoTransformations.reset() =====
        transformations.reset()

        // ===== Auto save =====
        saveTransformations()

        // ===== Log =====
        infoLog("[VideoTransformationService] Reset all transformations to default")
    }
}

/**
 # VideoTransformations Integration Guide

 ## Usage in GPU Shader:

 ### 1. Create Uniform Buffer:
 ```swift
 // Swift side:
 let transforms = service.transformations
 let uniformBuffer = device.makeBuffer(
 bytes: &transforms,
 length: MemoryLayout<VideoTransformations>.size,
 options: []
 )
 ```

 ### 2. Access in Metal Shader:
 ```metal
 // Shaders.metal
 struct Transforms {
 float brightness;
 bool flipHorizontal;
 bool flipVertical;
 float zoomLevel;
 float2 zoomCenter;
 };

 fragment float4 videoFragmentShader(
 VertexOut in [[stage_in]],
 texture2d<float> texture [[texture(0)]],
 constant Transforms &transforms [[buffer(0)]]
 ) {
 float2 coord = in.texCoord;

 // Apply flipping
 if (transforms.flipHorizontal) {
 coord.x = 1.0 - coord.x;
 }
 if (transforms.flipVertical) {
 coord.y = 1.0 - coord.y;
 }

 // Apply zoom
 coord = (coord - transforms.zoomCenter) / transforms.zoomLevel + transforms.zoomCenter;

 // Texture sampling
 float4 color = texture.sample(sampler, coord);

 // Apply brightness
 color.rgb += transforms.brightness;
 color.rgb = clamp(color.rgb, 0.0, 1.0);

 return color;
 }
 ```

 ## Building UI in SwiftUI:

 ```swift
 struct TransformationControlView: View {
 @ObservedObject var service = VideoTransformationService.shared

 var body: some View {
 VStack {
 // Brightness slider
 HStack {
 Text("Brightness")
 Slider(value: $service.transformations.brightness,
 in: -1.0...1.0)
 .onChange(of: service.transformations.brightness) { value in
 service.setBrightness(value)
 }
 Text(String(format: "%.2f", service.transformations.brightness))
 }

 // Flip toggle
 Toggle("Horizontal Flip", isOn: Binding(
 get: { service.transformations.flipHorizontal },
 set: { _ in service.toggleFlipHorizontal() }
 ))

 // Zoom control
 HStack {
 Text("Zoom")
 Slider(value: Binding(
 get: { service.transformations.zoomLevel },
 set: { service.setZoomLevel($0) }
 ), in: 1.0...5.0, step: 0.1)
 Text(String(format: "%.1fx", service.transformations.zoomLevel))
 }

 // Reset button
 if service.transformations.hasActiveTransformations {
 Button("Reset All") {
 service.resetTransformations()
 }
 }
 }
 .padding()
 }
 }
 ```

 ## Performance Optimization Tips:

 1. **Skip unnecessary shader processing**
 ```swift
 if !transforms.hasActiveTransformations {
 // Render original as-is (fast)
 renderPassDescriptor.colorAttachments[0].texture = sourceTexture
 } else {
 // Apply shader (slower)
 applyTransformationsShader()
 }
 ```

 2. **Cache transformations**
 ```swift
 private var cachedTransforms: VideoTransformations?
 private var cachedUniformBuffer: MTLBuffer?

 func updateUniformBuffer() {
 if cachedTransforms == service.transformations {
 return  // Skip if no changes
 }
 // ... update buffer
 }
 ```

 3. **Limit UserDefaults save frequency**
 ```swift
 // Don't save during Slider dragging (performance)
 Slider(value: $brightness)
 .onDragEnded { _ in
 service.setBrightness(brightness)  // Only save when dragging ends
 }
 ```
 */
