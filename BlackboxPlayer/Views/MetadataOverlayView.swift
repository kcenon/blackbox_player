/// @file MetadataOverlayView.swift
/// @brief View that displays real-time metadata overlay on video
/// @author BlackboxPlayer Development Team
/// @details
/// View that displays real-time metadata (GPS, speed, G-force) as an overlay on video.
/// Left panel shows speed gauge and GPS coordinates, right panel shows timestamp and G-Force information.

import SwiftUI

/// @struct MetadataOverlayView
/// @brief View that displays real-time metadata overlay on video
///
/// @details
/// View that displays real-time metadata overlay on video.
///
/// ## Screen Structure
/// ```
/// ┌─────────────────────────────────────────────────┐
/// │  ┌─────────┐                    ┌─────────────┐ │
/// │  │ 85      │                    │ 14:23:45    │ │
/// │  │ km/h    │                    │ 2024-01-15  │ │
/// │  │         │                    │             │ │
/// │  │ GPS     │                    │ G-Force     │ │
/// │  │ 37.566° │                    │ 2.3G        │ │
/// │  │ 126.98° │                    │             │ │
/// │  │         │                    │ EVENT       │ │
/// │  │ Altitude│                    │             │ │
/// │  │ Heading │                    │             │ │
/// │  └─────────┘                    └─────────────┘ │
/// │                                                  │
/// │  [Video Screen]                                  │
/// │                                                  │
/// └─────────────────────────────────────────────────┘
/// ```
///
/// ## Key Features
/// - **Left Panel**: Speed gauge, GPS coordinates, altitude, heading
/// - **Right Panel**: Timestamp, G-Force, event type badge
/// - **Semi-transparent Background**: Video shows through with `.opacity(0.6)`
/// - **Real-time Updates**: Metadata automatically updates based on currentTime
///
/// ## Core SwiftUI Concepts
///
/// ### 1. Conditional Rendering with Optional Binding
/// ```swift
/// if let gpsPoint = currentGPSPoint, let speed = gpsPoint.speed {
///     speedGauge(speed: speed)
/// }
/// ```
///
/// **What is Optional Binding?**
/// - Pattern for safely unwrapping Optional values
/// - If value exists (non-nil), execute code block
/// - If value is nil, skip code block
///
/// **Why is it needed?**
/// - GPS data may not be available (tunnels, indoors, etc.)
/// - Speed information may be missing (stopped, poor GPS signal)
/// - Using without nil check causes crashes
///
/// **Multiple Optional Binding:**
/// ```swift
/// // Executes only when both conditions are satisfied
/// if let gpsPoint = currentGPSPoint,  // 1. GPS data exists
///    let speed = gpsPoint.speed {     // 2. Speed data exists
///     speedGauge(speed: speed)
/// }
/// ```
///
/// ### 2. Semi-transparent Overlay Background
/// ```swift
/// .background(Color.black.opacity(0.6))
/// ```
///
/// **Effect of opacity(0.6):**
/// - 0.0: Fully transparent (invisible)
/// - 0.6: 60% opaque (video shows through at 40%)
/// - 1.0: Fully opaque (completely covers video)
///
/// **Why use semi-transparent background?**
/// - Ensures text readability (white text is clearly visible)
/// - Video content remains faintly visible
/// - Common pattern used in game HUDs, subtitles, etc.
///
/// ### 3. String Formatting
/// ```swift
/// String(format: "%.0f", speed)    // 85
/// String(format: "%.2f", value)    // 2.35
/// String(format: "%+.2f", value)   // +2.35 or -2.35
/// ```
///
/// **Format Specifiers:**
/// - `%`: Format start
/// - `.0f`: 0 decimal places (display as integer)
/// - `.2f`: 2 decimal places
/// - `+`: Always show sign (+/-)
/// - `f`: float/double type
///
/// **Real Examples:**
/// ```
/// speed = 85.7
/// String(format: "%.0f", speed) → "85" (rounded)
///
/// value = 2.3456
/// String(format: "%.2f", value) → "2.35" (rounded)
///
/// value = 1.5
/// String(format: "%+.2f", value) → "+1.50" (with sign)
///
/// value = -0.8
/// String(format: "%+.2f", value) → "-0.80" (negative sign)
/// ```
///
/// ### 4. Date/Time Formatting with Text Style
/// ```swift
/// Text(date, style: .time)  // 14:23:45
/// Text(date, style: .date)  // 2024-01-15
/// ```
///
/// **Advantages of Text(date, style:):**
/// - Automatically formats according to current locale
/// - Simple usage without DateFormatter
/// - Automatically adapts to system settings (12/24 hour)
///
/// **Available Styles:**
/// ```swift
/// .time     → 14:23:45 (time only)
/// .date     → 2024-01-15 (date only)
/// .timer    → 00:05:23 (timer format)
/// .relative → 3 minutes ago (relative time)
/// ```
///
/// ### 5. Getting Current Metadata with Computed Properties
/// ```swift
/// private var currentGPSPoint: GPSPoint? {
///     return videoFile.metadata.gpsPoint(at: currentTime)
/// }
/// ```
///
/// **What is a Computed Property?**
/// - Property that calculates and returns a value without storing it
/// - Automatically recalculated when currentTime changes
/// - Called every time the View is redrawn
///
/// **Why use it?**
/// - Eliminates duplicate code (prevents repeating same calculation)
/// - Improves readability (abstraction with meaningful names)
/// - Automatic updates (automatically reflects currentTime changes)
///
/// ### 6. VStack alignment
/// ```swift
/// VStack(alignment: .leading, spacing: 12) { ... }  // Left-aligned
/// VStack(alignment: .trailing, spacing: 12) { ... } // Right-aligned
/// ```
///
/// **alignment Options:**
/// - `.leading`: Left-aligned (start)
/// - `.center`: Center-aligned (default)
/// - `.trailing`: Right-aligned (end)
///
/// **Why use different alignments?**
/// ```
/// Left Panel (.leading):
/// 85
/// km/h
/// GPS
/// 37.566°  ← All left-aligned
///
/// Right Panel (.trailing):
///      14:23:45
///    2024-01-15
///       G-Force
///          2.3G  ← All right-aligned
/// ```
///
/// ### 7. Dynamic Color Logic
/// ```swift
/// private func gforceColor(magnitude: Double) -> Color {
///     if magnitude > 4.0 { return .red }
///     else if magnitude > 2.5 { return .orange }
///     else if magnitude > 1.5 { return .yellow }
///     else { return .green }
/// }
/// ```
///
/// **G-Force Thresholds:**
/// ```
/// 0.0 ~ 1.5G  → Green (normal)
/// 1.5 ~ 2.5G  → Yellow (warning)
/// 2.5 ~ 4.0G  → Orange (caution)
/// 4.0G+       → Red (danger)
/// ```
///
/// **Real Scenarios:**
/// - Normal driving: 0.5 ~ 1.0G (green)
/// - Rapid acceleration/braking: 1.5 ~ 2.5G (yellow)
/// - Accident: 4.0G+ (red)
///
/// ## Usage Examples
///
/// ### Example 1: Using in VideoPlayerView
/// ```swift
/// struct VideoPlayerView: View {
///     let videoFile: VideoFile
///     @State private var currentTime: TimeInterval = 0.0
///
///     var body: some View {
///         ZStack {
///             // Video screen
///             VideoFrameView(frame: currentFrame)
///
///             // Metadata overlay
///             MetadataOverlayView(
///                 videoFile: videoFile,
///                 currentTime: currentTime
///             )
///         }
///     }
/// }
/// ```
///
/// ### Example 2: Toggleable Overlay
/// ```swift
/// struct VideoPlayerView: View {
///     @State private var showMetadata = true
///
///     var body: some View {
///         ZStack {
///             VideoFrameView(frame: currentFrame)
///
///             // Toggle metadata display
///             if showMetadata {
///                 MetadataOverlayView(
///                     videoFile: videoFile,
///                     currentTime: currentTime
///                 )
///                 .transition(.opacity)
///             }
///         }
///         .toolbar {
///             Button("Toggle Metadata") {
///                 withAnimation {
///                     showMetadata.toggle()
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## Practical Applications
///
/// ### Adding Customization Options
/// ```swift
/// struct MetadataOverlayView: View {
///     let videoFile: VideoFile
///     let currentTime: TimeInterval
///
///     // Customization options
///     var showSpeed: Bool = true
///     var showGPS: Bool = true
///     var showGForce: Bool = true
///     var overlayOpacity: Double = 0.6
///
///     var body: some View {
///         VStack(alignment: .leading, spacing: 0) {
///             HStack(alignment: .top) {
///                 if showSpeed || showGPS {
///                     leftPanel
///                 }
///
///                 Spacer()
///
///                 if showGForce {
///                     rightPanel
///                 }
///             }
///         }
///         .background(Color.black.opacity(overlayOpacity))
///     }
/// }
/// ```
///
/// ### Show/Hide with Keyboard Shortcut
/// ```swift
/// .onKeyPress(.m) {
///     showMetadata.toggle()
///     return .handled
/// }
/// ```
///
/// ### Show Only on Mouse Hover
/// ```swift
/// @State private var isHovering = false
///
/// ZStack {
///     VideoFrameView(frame: currentFrame)
///
///     if isHovering {
///         MetadataOverlayView(
///             videoFile: videoFile,
///             currentTime: currentTime
///         )
///     }
/// }
/// .onHover { hovering in
///     withAnimation {
///         isHovering = hovering
///     }
/// }
/// ```
///
/// ## Performance Optimization
///
/// ### 1. Caching Instead of Computed Properties
/// ```swift
/// // Current: Calculate every time (inefficient)
/// private var currentGPSPoint: GPSPoint? {
///     return videoFile.metadata.gpsPoint(at: currentTime)
/// }
///
/// // Improved: Cache with onChange
/// @State private var cachedGPSPoint: GPSPoint?
///
/// .onChange(of: currentTime) { newTime in
///     cachedGPSPoint = videoFile.metadata.gpsPoint(at: newTime)
/// }
/// ```
///
/// ### 2. Stabilize Layout with Monospaced Font
/// ```swift
/// Text(value)
///     .font(.system(.caption, design: .monospaced))
///     // ✅ Width remains constant even when numbers change → Stable UI
/// ```
///
/// ## Test Data
///
/// ### Mock GPS Point
/// ```swift
/// extension GPSPoint {
///     static func mock() -> GPSPoint {
///         return GPSPoint(
///             latitude: 37.5665,
///             longitude: 126.9780,
///             speed: 85.0,
///             altitude: 35.0,
///             heading: 270.0,
///             satelliteCount: 12,
///             timestamp: Date()
///         )
///     }
/// }
/// ```
///
/// ### Mock Acceleration Data
/// ```swift
/// extension AccelerationData {
///     static func mock(magnitude: Double = 2.5) -> AccelerationData {
///         let x = magnitude * 0.6
///         let y = magnitude * 0.3
///         let z = magnitude * 0.1
///         return AccelerationData(
///             x: x,
///             y: y,
///             z: z,
///             timestamp: Date()
///         )
///     }
/// }
/// ```
///
/// ### Preview with Different States
/// ```swift
/// struct MetadataOverlayView_Previews: PreviewProvider {
///     static var previews: some View {
///         VStack(spacing: 20) {
///             // Normal state
///             ZStack {
///                 Color.black
///                 MetadataOverlayView(
///                     videoFile: videoFileWith(gforce: 1.0),
///                     currentTime: 10.0
///                 )
///             }
///             .previewDisplayName("Normal")
///
///             // Warning state
///             ZStack {
///                 Color.black
///                 MetadataOverlayView(
///                     videoFile: videoFileWith(gforce: 2.0),
///                     currentTime: 10.0
///                 )
///             }
///             .previewDisplayName("Warning")
///
///             // Danger state
///             ZStack {
///                 Color.black
///                 MetadataOverlayView(
///                     videoFile: videoFileWith(gforce: 5.0),
///                     currentTime: 10.0
///                 )
///             }
///             .previewDisplayName("Danger")
///         }
///         .frame(width: 800, height: 600)
///     }
/// }
/// ```
///
struct MetadataOverlayView: View {
    // MARK: - Properties

    /// @var videoFile
    /// @brief Video file
    ///
    /// **Included Information:**
    /// - metadata: Metadata such as GPS, acceleration sensor
    /// - timestamp: Video recording start time
    /// - eventType: Event type (normal, parking, event)
    let videoFile: VideoFile

    /// @var currentTime
    /// @brief Current playback time
    ///
    /// **What is TimeInterval?**
    /// - Typealias for Double (actually Double type)
    /// - Represents time in seconds (e.g., 10.5 seconds, 125.3 seconds)
    ///
    /// **Usage:**
    /// ```
    /// currentTime = 0.0    → Video start
    /// currentTime = 10.5   → 10.5 second mark
    /// currentTime = 125.3  → 2 minutes 5.3 seconds mark
    /// ```
    ///
    /// **Why is it needed?**
    /// - Retrieve GPS data corresponding to current time
    /// - Retrieve acceleration data corresponding to current time
    /// - Calculate timestamp (recording start time + currentTime)
    let currentTime: TimeInterval

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                // Left panel: Speed and GPS
                //
                // **Display content:**
                // - Speed gauge (large number)
                // - GPS coordinates
                // - Altitude
                // - Heading
                leftPanel

                Spacer()

                // Right panel: G-Force and timestamp
                //
                // **Display content:**
                // - Timestamp (time + date)
                // - G-Force magnitude
                // - X, Y, Z axis values
                // - Event type badge
                rightPanel
            }
            .padding()

            Spacer()
        }
    }

    // MARK: - Left Panel

    /// @brief Left panel
    ///
    /// ## Structure
    /// ```
    /// ┌─────────┐
    /// │ 85      │  ← Speed gauge
    /// │ km/h    │
    /// │         │
    /// │ GPS     │  ← GPS coordinates
    /// │ 37.566° │
    /// │ 126.98° │
    /// │ 12 sats │
    /// │         │
    /// │ Altitude│  ← Altitude
    /// │ 35 m    │
    /// │         │
    /// │ Heading │  ← Heading
    /// │ 270°    │
    /// └─────────┘
    /// ```
    ///
    /// ## Optional Binding Pattern
    /// ```swift
    /// if let gpsPoint = currentGPSPoint, let speed = gpsPoint.speed {
    ///     speedGauge(speed: speed)
    /// }
    /// ```
    ///
    /// **Why do this?**
    /// - GPS data may not be available (currentGPSPoint is nil)
    /// - Speed information may be missing (gpsPoint.speed is nil)
    /// - Display speedGauge only when both conditions are satisfied
    ///
    /// **Real Scenarios:**
    /// ```
    /// Entering tunnel: currentGPSPoint = nil → Hide speed gauge
    /// Receiving GPS: currentGPSPoint ≠ nil, speed = 85.0 → Show speed gauge
    /// Stopped: speed = 0.0 → Display "0 km/h"
    /// ```
    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Speed gauge
            //
            // Display only when both GPS data and speed information are available
            if let gpsPoint = currentGPSPoint, let speed = gpsPoint.speed {
                speedGauge(speed: speed)
            }

            // GPS coordinates
            //
            // Display only when GPS data is available
            if let gpsPoint = currentGPSPoint {
                gpsCoordinates(gpsPoint: gpsPoint)
            }

            // Altitude
            //
            // Display only when both GPS data and altitude information are available
            if let gpsPoint = currentGPSPoint, let altitude = gpsPoint.altitude {
                metadataRow(
                    icon: "arrow.up.arrow.down",
                    label: "Altitude",
                    value: String(format: "%.0f m", altitude)
                )
            }

            // Heading - Compass
            //
            // Display only when both GPS data and heading information are available
            if let gpsPoint = currentGPSPoint, let heading = gpsPoint.heading {
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.north.fill")
                            .font(.caption)
                        Text("Heading")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white.opacity(0.8))

                    // Compass view
                    CompassView(heading: heading)
                        .frame(width: 70, height: 70)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        // ✅ opacity(0.6): 60% opaque → Video shows through at 40%
        .cornerRadius(8)
    }

    // MARK: - Right Panel

    /// @brief Right panel
    ///
    /// ## Structure
    /// ```
    /// ┌─────────────┐
    /// │   14:23:45  │  ← Timestamp (time)
    /// │ 2024-01-15  │  ← Timestamp (date)
    /// │             │
    /// │   G-Force   │  ← G-Force magnitude
    /// │     2.3G    │
    /// │   X: +1.2   │
    /// │   Y: +0.8   │
    /// │   Z: -0.3   │
    /// │             │
    /// │ ⚠️ IMPACT   │  ← Impact warning (when 4G or more)
    /// │             │
    /// │   EVENT     │  ← Event type badge
    /// └─────────────┘
    /// ```
    ///
    /// ## alignment: .trailing
    /// ```swift
    /// VStack(alignment: .trailing, spacing: 12) { ... }
    /// ```
    ///
    /// **Why use .trailing?**
    /// - Cleanly organized with right alignment
    /// - Numbers aligned to the right for easy reading
    /// - Symmetrical with left panel (.leading)
    private var rightPanel: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Timestamp
            //
            // Video start time + currentTime
            timestampDisplay

            // G-Force
            //
            // Display only when acceleration data is available
            if let accelData = currentAccelerationData {
                gforceDisplay(accelData: accelData)
            }

            // Event type badge
            //
            // Distinguish between normal/parking/event
            EventBadge(eventType: videoFile.eventType)
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
    }

    // MARK: - Speed Gauge

    /// @brief Speed gauge
    ///
    /// ## Structure
    /// ```
    /// ┌─────────┐
    /// │   85    │  ← Large number (48pt, bold)
    /// │  km/h   │  ← Unit (small text, semi-transparent)
    /// └─────────┘
    /// ```
    ///
    /// ## .rounded Design
    /// ```swift
    /// .font(.system(size: 48, weight: .bold, design: .rounded))
    /// ```
    ///
    /// **design Options:**
    /// - `.default`: Normal system font
    /// - `.serif`: Serif font (with decorations)
    /// - `.rounded`: Rounded font (soft feel)
    /// - `.monospaced`: Fixed-width font (number alignment)
    ///
    /// **Why use .rounded?**
    /// - Numbers are soft and easy to read
    /// - Modern and friendly feel
    /// - Suitable for dashboards and gauges
    ///
    /// ## Visual Gauge Addition
    /// - SpeedometerGaugeView: Semi-circular speedometer
    /// - Color coding by speed range
    /// - Smooth animation
    private func speedGauge(speed: Double) -> some View {
        VStack(spacing: 8) {
            // Visual speedometer gauge
            SpeedometerGaugeView(speed: speed)
                .frame(width: 140, height: 90)

            Divider()
                .background(Color.white.opacity(0.3))
        }
    }

    // MARK: - GPS Coordinates

    /// @brief GPS coordinates display
    ///
    /// ## Structure
    /// ```
    /// ┌─────────────┐
    /// │ 📍 GPS      │  ← Icon + label
    /// │ 37.5665°    │  ← Latitude
    /// │ 126.9780°   │  ← Longitude
    /// │ 📡 12 sats  │  ← Satellite count
    /// └─────────────┘
    /// ```
    ///
    /// ## gpsPoint.decimalString
    /// ```swift
    /// Text(gpsPoint.decimalString)
    ///     .font(.system(.caption, design: .monospaced))
    /// ```
    ///
    /// **What is decimalString?**
    /// - Computed Property provided by GPSPoint
    /// - Returns latitude/longitude in decimal format
    /// - Example: "37.5665°, 126.9780°"
    ///
    /// **Why use monospaced font?**
    /// - Numbers have consistent width → Clean alignment
    /// - Layout remains stable even when coordinate values change
    ///
    /// ## Satellite Count Display
    /// ```swift
    /// if let satelliteCount = gpsPoint.satelliteCount {
    ///     HStack(spacing: 4) {
    ///         Image(systemName: "antenna.radiowaves.left.and.right")
    ///         Text("\(satelliteCount) satellites")
    ///     }
    ///     .foregroundColor(.white.opacity(0.6))
    /// }
    /// ```
    ///
    /// **Meaning of Satellite Count:**
    /// - 3 or less: Poor GPS (low accuracy)
    /// - 4~8: Fair (normal driving possible)
    /// - 9+: Good (high accuracy)
    /// - 12+: Excellent (highest accuracy)
    private func gpsCoordinates(gpsPoint: GPSPoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption)
                Text("GPS")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white.opacity(0.8))

            Text(gpsPoint.decimalString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)

            // Satellite count
            //
            // Display only when satellite count is available
            if let satelliteCount = gpsPoint.satelliteCount {
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption2)
                    Text("\(satelliteCount) satellites")
                        .font(.caption2)
                }
                .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - G-Force Display

    /// @brief G-Force display
    ///
    /// ## Structure
    /// ```
    /// ┌─────────────┐
    /// │  G-Force 📈 │  ← Label + icon
    /// │    2.3G     │  ← Magnitude (dynamic color)
    /// │   X: +1.2   │  ← X-axis value
    /// │   Y: +0.8   │  ← Y-axis value
    /// │   Z: -0.3   │  ← Z-axis value
    /// │             │
    /// │ ⚠️ IMPACT   │  ← Impact warning (4G or more)
    /// └─────────────┘
    /// ```
    ///
    /// ## Dynamic Color
    /// ```swift
    /// .foregroundColor(gforceColor(magnitude: accelData.magnitude))
    /// ```
    ///
    /// **Color Thresholds:**
    /// ```
    /// 0.0 ~ 1.5G  → Green (normal)
    /// 1.5 ~ 2.5G  → Yellow (warning)
    /// 2.5 ~ 4.0G  → Orange (caution)
    /// 4.0G+       → Red (danger)
    /// ```
    ///
    /// ## X, Y, Z Axis Values
    /// ```swift
    /// axisValue(label: "X", value: accelData.x)
    /// axisValue(label: "Y", value: accelData.y)
    /// axisValue(label: "Z", value: accelData.z)
    /// ```
    ///
    /// **Meaning of Each Axis:**
    /// - **X-axis**: Left-right direction (lane change, curves)
    /// - **Y-axis**: Front-back direction (acceleration, braking)
    /// - **Z-axis**: Up-down direction (speed bumps, jumps)
    ///
    /// **Real Examples:**
    /// ```
    /// Hard braking:
    /// X: +0.3 (slight shake)
    /// Y: -3.2 (strongly pushed backward)
    /// Z: +0.5 (slightly lifted)
    ///
    /// Left turn:
    /// X: +2.1 (pushed to the right)
    /// Y: +0.8 (speed decrease)
    /// Z: -0.2 (slightly tilted)
    /// ```
    ///
    /// ## Impact Warning
    /// ```swift
    /// if accelData.isImpact {
    ///     HStack {
    ///         Image(systemName: "exclamationmark.triangle.fill")
    ///         Text(accelData.impactSeverity.displayName.uppercased())
    ///     }
    ///     .foregroundColor(.red)
    ///     .background(Color.red.opacity(0.2))
    /// }
    /// ```
    ///
    /// **What is isImpact?**
    /// - Computed Property of AccelerationData
    /// - Returns true if magnitude exceeds threshold (4.0G)
    /// - Automatically detects accident moment
    ///
    /// **impactSeverity:**
    /// - `.minor`: Minor impact (4~6G)
    /// - `.moderate`: Moderate impact (6~8G)
    /// - `.severe`: Severe impact (8G or more)
    private func gforceDisplay(accelData: AccelerationData) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                Text("G-Force")
                    .font(.caption)
                    .fontWeight(.medium)
                Image(systemName: "waveform.path.ecg")
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.8))

            // Magnitude
            //
            // accelData.magnitudeString: "2.3G" format
            // Color changes dynamically based on magnitude
            Text(accelData.magnitudeString)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(gforceColor(magnitude: accelData.magnitude))

            // X, Y, Z values
            VStack(alignment: .trailing, spacing: 2) {
                axisValue(label: "X", value: accelData.x)
                axisValue(label: "Y", value: accelData.y)
                axisValue(label: "Z", value: accelData.z)
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundColor(.white.opacity(0.8))

            // Impact warning
            //
            // Display only when isImpact = true (4G or more)
            if accelData.isImpact {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(accelData.impactSeverity.displayName.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2))
                .cornerRadius(4)
            }
        }
    }

    /// @brief Axis value display
    ///
    /// ## Structure
    /// ```
    /// X: +1.23
    /// ^  ^
    /// │  └─ Value (with sign, 2 decimal places)
    /// └──── Label
    /// ```
    ///
    /// ## String(format: "%+.2f", value)
    /// ```swift
    /// Text(String(format: "%+.2f", value))
    /// ```
    ///
    /// **Meaning of %+.2f:**
    /// - `%`: Format start
    /// - `+`: Always show sign (+/-)
    /// - `.2`: 2 decimal places
    /// - `f`: float/double type
    ///
    /// **Real Examples:**
    /// ```
    /// value = 1.234   → "+1.23"
    /// value = -0.567  → "-0.57"
    /// value = 0.0     → "+0.00"
    /// ```
    ///
    /// **Why always show sign?**
    /// - Direction is clearly indicated
    /// - +: Positive direction (right, forward, up)
    /// - -: Negative direction (left, backward, down)
    private func axisValue(label: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .foregroundColor(.white.opacity(0.6))
            Text(String(format: "%+.2f", value))
                .foregroundColor(.white)
        }
    }

    /// @brief Color based on G-Force magnitude
    ///
    /// ## Color Thresholds
    /// ```
    /// 0.0 ~ 1.5G  → Green (normal)
    /// 1.5 ~ 2.5G  → Yellow (warning)
    /// 2.5 ~ 4.0G  → Orange (caution)
    /// 4.0G+       → Red (danger)
    /// ```
    ///
    /// ## Real Scenarios
    ///
    /// ### Normal Driving (0.5 ~ 1.0G) - Green
    /// ```
    /// - Constant speed on straight road
    /// - Gentle curves
    /// - Smooth acceleration/deceleration
    /// ```
    ///
    /// ### Warning (1.5 ~ 2.5G) - Yellow
    /// ```
    /// - Rapid acceleration (starting from signal)
    /// - Hard braking (sudden stop)
    /// - Sharp lane change
    /// ```
    ///
    /// ### Caution (2.5 ~ 4.0G) - Orange
    /// ```
    /// - Very hard braking (emergency situation)
    /// - High-speed turn
    /// - Speed bump at high speed
    /// ```
    ///
    /// ### Danger (4.0G+) - Red
    /// ```
    /// - Collision accident
    /// - Sharp rollover
    /// - Severe impact
    /// ```
    ///
    /// ## if-else Chain
    /// ```swift
    /// if magnitude > 4.0 { return .red }
    /// else if magnitude > 2.5 { return .orange }
    /// else if magnitude > 1.5 { return .yellow }
    /// else { return .green }
    /// ```
    ///
    /// **Why check from 4.0 first?**
    /// - Must check from largest value for accuracy
    /// - Reverse order gives wrong result:
    ///   ```
    ///   magnitude = 5.0
    ///   if magnitude > 1.5 { return .yellow }  // ❌ Returns yellow (wrong)
    ///   ```
    private func gforceColor(magnitude: Double) -> Color {
        if magnitude > 4.0 {
            return .red
        } else if magnitude > 2.5 {
            return .orange
        } else if magnitude > 1.5 {
            return .yellow
        } else {
            return .green
        }
    }

    // MARK: - Timestamp Display

    /// @brief Timestamp display
    ///
    /// ## Structure
    /// ```
    /// ┌─────────────┐
    /// │  14:23:45   │  ← Time (large text)
    /// │ 2024-01-15  │  ← Date (small text)
    /// └─────────────┘
    /// ```
    ///
    /// ## Time Calculation
    /// ```swift
    /// videoFile.timestamp.addingTimeInterval(currentTime)
    /// ```
    ///
    /// **Calculation Process:**
    /// ```
    /// videoFile.timestamp: 2024-01-15 14:23:00 (recording start time)
    /// currentTime: 45.0 (45 seconds)
    /// → Result: 2024-01-15 14:23:45
    /// ```
    ///
    /// **What is addingTimeInterval?**
    /// - Method of Date type
    /// - Adds time in seconds to current date/time
    /// - TimeInterval is a typealias for Double
    ///
    /// ## Text(date, style:) Usage
    /// ```swift
    /// Text(date, style: .time)  // 14:23:45
    /// Text(date, style: .date)  // 2024-01-15
    /// ```
    ///
    /// **Advantages:**
    /// - Simple usage without DateFormatter
    /// - Automatically formats according to locale
    /// - Automatically adapts to system settings (12/24 hour)
    ///
    /// **Other Styles:**
    /// ```swift
    /// .time       → 14:23:45
    /// .date       → 2024-01-15
    /// .timer      → 00:45:23 (timer format)
    /// .relative   → 45 seconds ago
    /// ```
    ///
    /// ## .rounded Design
    /// - Soft feel for time display
    /// - Numbers are easy to read
    private var timestampDisplay: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(videoFile.timestamp.addingTimeInterval(currentTime), style: .time)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.white)

            Text(videoFile.timestamp.addingTimeInterval(currentTime), style: .date)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Metadata Row

    /// @brief Metadata row
    ///
    /// ## Structure
    /// ```
    /// ┌──────────────────┐
    /// │ 🧭 Heading   270° │
    /// │ ^  ^         ^    │
    /// │ │  │         └─ Value
    /// │ │  └─────────── Label
    /// │ └──────────────── Icon
    /// └──────────────────┘
    /// ```
    ///
    /// ## Usage Examples
    /// ```swift
    /// metadataRow(
    ///     icon: "arrow.up.arrow.down",
    ///     label: "Altitude",
    ///     value: String(format: "%.0f m", 35.0)
    /// )
    /// // Result: "🔼 Altitude    35 m"
    ///
    /// metadataRow(
    ///     icon: "location.north.fill",
    ///     label: "Heading",
    ///     value: String(format: "%.0f°", 270.0)
    /// )
    /// // Result: "🧭 Heading    270°"
    /// ```
    ///
    /// ## .frame(width: 16)
    /// ```swift
    /// Image(systemName: icon)
    ///     .frame(width: 16)
    /// ```
    ///
    /// **Why fix icon width?**
    /// - Each icon has different width
    /// - Without fixing, text positions are inconsistent
    /// - Fixing to 16px ensures clean alignment
    ///
    /// **Example:**
    /// ```
    /// Width not fixed:
    /// 🔼 Altitude    35 m
    /// 🧭 Heading   270°  ← Text position inconsistent ❌
    ///
    /// Width fixed:
    /// 🔼 Altitude    35 m
    /// 🧭 Heading    270°  ← Text position aligned ✅
    /// ```
    ///
    /// ## Role of Spacer()
    /// ```swift
    /// HStack {
    ///     Image(...)
    ///     Text(label)
    ///     Spacer()  // Expands space here
    ///     Text(value)
    /// }
    /// ```
    ///
    /// **What Spacer() does:**
    /// - Takes up all remaining space
    /// - Pushes value to the right edge
    /// - Creates proper spacing between label and value
    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    // MARK: - Helper Methods

    /// @brief GPS point at current time
    ///
    /// ## What is a Computed Property?
    /// ```swift
    /// private var currentGPSPoint: GPSPoint? {
    ///     return videoFile.metadata.gpsPoint(at: currentTime)
    /// }
    /// ```
    ///
    /// **Characteristics:**
    /// - Calculates and returns value without storing it
    /// - Automatically recalculated when currentTime changes
    /// - Called every time the View is redrawn
    ///
    /// **Why use Computed Property instead of function?**
    /// ```swift
    /// // Function approach
    /// func currentGPSPoint() -> GPSPoint? { ... }
    /// if let gpsPoint = currentGPSPoint() { ... }  // Parentheses required
    ///
    /// // Computed Property approach
    /// var currentGPSPoint: GPSPoint? { ... }
    /// if let gpsPoint = currentGPSPoint { ... }  // No parentheses (more natural)
    /// ```
    ///
    /// ## videoFile.metadata.gpsPoint(at:)
    /// ```swift
    /// videoFile.metadata.gpsPoint(at: currentTime)
    /// ```
    ///
    /// **gpsPoint(at:) method:**
    /// - Method of VideoMetadata
    /// - Returns GPS data corresponding to given time (TimeInterval)
    /// - Calculates accurate position using interpolation
    ///
    /// **How it works:**
    /// ```
    /// GPS data:
    /// [0.0s: (37.5665, 126.9780)]
    /// [5.0s: (37.5670, 126.9785)]
    ///
    /// currentTime = 2.5s (middle)
    /// → Interpolation: (37.5667, 126.9782)
    /// ```
    ///
    /// ## Optional Return Type
    /// ```swift
    /// var currentGPSPoint: GPSPoint?  // Can be nil
    /// ```
    ///
    /// **When it becomes nil:**
    /// - No GPS data at all
    /// - GPS not received at that time (tunnel, indoors)
    /// - Metadata parsing failed
    private var currentGPSPoint: GPSPoint? {
        return videoFile.metadata.gpsPoint(at: currentTime)
    }

    /// @brief Acceleration data at current time
    ///
    /// ## Computed Property
    /// ```swift
    /// private var currentAccelerationData: AccelerationData? {
    ///     return videoFile.metadata.accelerationData(at: currentTime)
    /// }
    /// ```
    ///
    /// **Characteristics:**
    /// - Automatically recalculated when currentTime changes
    /// - Called every time View updates
    /// - Eliminates duplicate code (used in multiple places)
    ///
    /// ## videoFile.metadata.accelerationData(at:)
    /// ```swift
    /// videoFile.metadata.accelerationData(at: currentTime)
    /// ```
    ///
    /// **accelerationData(at:) method:**
    /// - Method of VideoMetadata
    /// - Returns acceleration data corresponding to given time
    /// - Calculates accurate value using interpolation
    ///
    /// **How it works:**
    /// ```
    /// Acceleration data:
    /// [0.0s: (x:0.5, y:0.8, z:-0.1)]
    /// [1.0s: (x:1.5, y:1.8, z:0.1)]
    ///
    /// currentTime = 0.5s (middle)
    /// → Interpolation:
    ///   x = 0.5 + (1.5-0.5)*0.5 = 1.0
    ///   y = 0.8 + (1.8-0.8)*0.5 = 1.3
    ///   z = -0.1 + (0.1-(-0.1))*0.5 = 0.0
    ///   → (x:1.0, y:1.3, z:0.0)
    /// ```
    ///
    /// ## Optional Return Type
    /// ```swift
    /// var currentAccelerationData: AccelerationData?  // Can be nil
    /// ```
    ///
    /// **When it becomes nil:**
    /// - No acceleration sensor data
    /// - Sensor error at that time
    /// - Metadata parsing failed
    private var currentAccelerationData: AccelerationData? {
        return videoFile.metadata.accelerationData(at: currentTime)
    }
}

// MARK: - Preview

/// @brief Preview Provider
///
/// ## Adding Black Background with ZStack
/// ```swift
/// ZStack {
///     Color.black          // Background (instead of video)
///     MetadataOverlayView  // Overlay
/// }
/// ```
///
/// **Why use ZStack?**
/// - Simulates overlay on actual video screen
/// - Check text readability with black background
/// - Verify effect of semi-transparent background (.opacity(0.6))
///
/// ## VideoFile.allSamples.first!
/// ```swift
/// videoFile: VideoFile.allSamples.first!
/// ```
///
/// **What is allSamples?**
/// - Static sample data provided by VideoFile
/// - Mock data for testing/Preview
/// - Includes GPS and acceleration sensor data
///
/// **Why use !:**
/// - Preview only runs in development environment
/// - Sample data is guaranteed to exist
/// - Force unwrap allowed as this is not production code
///
/// ## currentTime: 10.0
/// - 10 seconds after video start
/// - Display GPS and acceleration data at that time
/// - Change value to test different time points
struct MetadataOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black

            MetadataOverlayView(
                videoFile: VideoFile.allSamples.first!,
                currentTime: 10.0
            )
        }
        .frame(width: 800, height: 600)
    }
}
