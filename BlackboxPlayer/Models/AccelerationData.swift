/// @file AccelerationData.swift
/// @brief Blackbox G-Sensor (Accelerometer) data model
/// @author BlackboxPlayer Development Team
///
/// Model for G-Sensor (accelerometer) data

/*
 ┌──────────────────────────────────────────────────────────────────────────┐
 │                   AccelerationData Model Overview                        │
 │                                                                          │
 │  Acceleration data point measured by the dashcam's G-sensor              │
 │  (accelerometer).                                                        │
 │                                                                          │
 │  【3-Axis Acceleration】                                                 │
 │                                                                          │
 │                    Z (Vertical)                                          │
 │                      ↑                                                   │
 │                      │                                                   │
 │                      │                                                   │
 │       Y (Forward) ───┼─── X (Lateral)                                   │
 │                    / │                                                   │
 │                   /  │                                                   │
 │                  ↙   ↓                                                   │
 │                                                                          │
 │  X-axis (Lateral/Left-Right):                                            │
 │    - Positive (+): Acceleration to the right (right turn, right impact)  │
 │    - Negative (-): Acceleration to the left (left turn, left impact)     │
 │                                                                          │
 │  Y-axis (Longitudinal/Forward-Backward):                                 │
 │    - Positive (+): Forward acceleration (accelerating, rear impact)      │
 │    - Negative (-): Backward acceleration (braking, front impact)         │
 │                                                                          │
 │  Z-axis (Vertical/Up-Down):                                              │
 │    - Positive (+): Upward acceleration (jump, downward impact)           │
 │    - Negative (-): Downward acceleration (falling, upward impact)        │
 │    - Normal driving: ~1.0G (gravity)                                     │
 │                                                                          │
 │  【Impact Severity Classification】                                      │
 │                                                                          │
 │  Total acceleration magnitude = √(x² + y² + z²)                          │
 │                                                                          │
 │  - None:     < 1.0G  (normal driving)           Green                    │
 │  - Low:      1.0-1.5G (minor acceleration)      Light Green              │
 │  - Moderate: 1.5-2.5G (significant acceleration) Amber                   │
 │  - High:     2.5-4.0G (impact/accident)         Orange                   │
 │  - Severe:   > 4.0G   (severe impact)           Red                      │
 │                                                                          │
 │  【Data Source】                                                         │
 │                                                                          │
 │  Dashcam SD Card                                                         │
 │      │                                                                   │
 │      ├─ 20250115_100000_F.mp4 (video)                                   │
 │      └─ 20250115_100000.gsn (G-sensor data)                              │
 │           │                                                              │
 │           ├─ Timestamp                                                   │
 │           ├─ X-axis acceleration (G)                                     │
 │           ├─ Y-axis acceleration (G)                                     │
 │           └─ Z-axis acceleration (G)                                     │
 │                │                                                         │
 │                ▼                                                         │
 │           AccelerationParser                                             │
 │                │                                                         │
 │                ▼                                                         │
 │           AccelerationData (this struct)                                 │
 │                                                                          │
 └──────────────────────────────────────────────────────────────────────────┘

 【What is a G-Sensor (Accelerometer)?】

 A sensor that measures vehicle acceleration in three axes.

 Principle:
 - MEMS (Micro-Electro-Mechanical Systems) technology
 - Detects movement of microscopic mass
 - Converts to electrical signals

 Role in dashcam:
 1. Impact detection: Triggers event recording when accident occurs
 2. Parking mode: Detects impacts while parked
 3. Hard braking/acceleration warnings
 4. Driving habit analysis

 Measurement unit: G (gravitational acceleration)
 - 1G = 9.8 m/s² (Earth's gravity)
 - Example: 2G = 19.6 m/s² (twice gravity)

 【What is G-Force?】

 G is an acceleration unit based on gravitational acceleration.

 Reference values:
 - 0G: Weightless state (space)
 - 1G: Stationary (Earth's surface)
 - 2G: Hard braking, sharp turn
 - 3-4G: Minor collision
 - 5-10G: Severe collision
 - >15G: Fatal collision

 Everyday examples:
 - Elevator start: ~1.2G
 - Roller coaster: 3-5G
 - Fighter jet maneuver: 9G
 - Car hard braking: 0.8-1.5G
 - Car collision: 20-100G (momentary)

 【Vector Magnitude Calculation】

 To express 3-axis acceleration as a single value, calculate vector magnitude.

 Mathematical formula:
 ```
 magnitude = √(x² + y² + z²)
 ```

 Example:
 ```swift
 // Hard braking (Y-axis -1.8G)
 x = 0.0
 y = -1.8
 z = 1.0 (gravity)

 magnitude = √(0² + (-1.8)² + 1²)
 = √(0 + 3.24 + 1)
 = √4.24
 = 2.06G
 ```

 Why square root?:
 - 3D extension of Pythagorean theorem
 - 2D: √(x² + y²)
 - 3D: √(x² + y² + z²)

 【Direction Detection Algorithm】

 The axis with the largest absolute value is the primary impact direction.

 Algorithm:
 ```
 1. Calculate |x|, |y|, |z|
 2. Find maximum value
 3. Check sign of corresponding axis
 - x > 0: right
 - x < 0: left
 - y > 0: forward
 - y < 0: backward
 - z > 0: up
 - z < 0: down
 ```

 Example:
 ```swift
 x = 1.5  (right)
 y = -3.5 (backward, i.e., front impact)
 z = 0.8  (up)

 |x| = 1.5
 |y| = 3.5  ← maximum!
 |z| = 0.8

 y < 0, so → backward (braking/front impact)
 ```
 */

import Foundation

/*
 【AccelerationData Struct】

 3-axis acceleration data point measured by the dashcam's G-sensor.

 Data structure:
 - Value type (struct) - Immutability and thread safety
 - Codable - JSON serialization/deserialization
 - Equatable - Comparison operations (==, !=)
 - Hashable - Can be used as Set, Dictionary key
 - Identifiable - Used in SwiftUI List

 Usage example:
 ```swift
 // 1. Parse G-sensor data
 let parser = AccelerationParser()
 let dataPoints = try parser.parseAccelerationData(from: gsnFileURL)

 // 2. Detect impacts
 for data in dataPoints {
 if data.isImpact {
 print("Impact detected: \(data.magnitudeString)")
 print("Direction: \(data.primaryDirection.displayName)")
 print("Severity: \(data.impactSeverity.displayName)")
 }
 }

 // 3. Chart visualization
 Chart(dataPoints) { point in
 LineMark(x: .value("Time", point.timestamp),
 y: .value("G-Force", point.magnitude))
 }
 ```
 */
/// @struct AccelerationData
/// @brief Dashcam G-sensor acceleration data point
///
/// G-Sensor acceleration data point from dashcam recording
struct AccelerationData: Codable, Equatable, Hashable {
    /*
     【Timestamp】

     The time when this acceleration measurement was taken.

     Type: Date
     - UTC based (Coordinated Universal Time)
     - Synchronized with video frames

     Usage:
     - Display acceleration at specific time during video playback
     - Draw time-based charts
     - Time synchronization with GPS data
     */
    /// @var timestamp
    /// @brief Measurement timestamp
    ///
    /// Timestamp of this reading
    let timestamp: Date

    /*
     【X-axis Acceleration (Lateral)】

     Lateral (left-right) acceleration in G-force units.

     Direction:
     - Positive (+): Acceleration to the right
     * Pull to the right from centrifugal force during left turn
     * Impact from the left (pushed to the right)
     - Negative (-): Acceleration to the left
     * Pull to the left from centrifugal force during right turn
     * Impact from the right (pushed to the left)

     Example values:
     - 0.0G: Straight ahead
     - +0.5G: Gentle left turn
     - -1.2G: Sharp right turn
     - +2.0G: Left side impact

     Usage:
     ```swift
     if data.x > 1.5 {
     print("Sharp left turn or left side impact")
     } else if data.x < -1.5 {
     print("Sharp right turn or right side impact")
     }
     ```
     */
    /// @var x
    /// @brief X-axis acceleration (lateral direction, G-force)
    ///
    /// X-axis acceleration in G-force (lateral/side-to-side)
    /// Positive: right, Negative: left
    let x: Double

    /*
     【Y-axis Acceleration (Longitudinal)】

     Longitudinal (forward-backward) acceleration in G-force units.

     Direction:
     - Positive (+): Forward acceleration
     * Pressing accelerator pedal
     * Impact from rear (pushed forward)
     - Negative (-): Backward acceleration
     * Pressing brake pedal (braking)
     * Impact from front (pushed backward)

     Example values:
     - 0.0G: Constant speed driving
     - +0.8G: Normal acceleration
     - -1.5G: Hard braking
     - -3.0G: Front collision

     Usage:
     ```swift
     if data.y < -2.0 {
     print("Hard braking or front collision!")
     triggerEventRecording()
     } else if data.y > 1.5 {
     print("Rapid acceleration or rear collision")
     }
     ```

     Note:
     - Y-axis direction definition may vary between dashcam models
     - Some models have opposite positive/negative signs
     */
    /// @var y
    /// @brief Y-axis acceleration (longitudinal direction, G-force)
    ///
    /// Y-axis acceleration in G-force (longitudinal/forward-backward)
    /// Positive: forward, Negative: backward
    let y: Double

    /*
     【Z-axis Acceleration (Vertical)】

     Vertical (up-down) acceleration in G-force units.

     Direction:
     - Positive (+): Upward acceleration
     * Bouncing up from pothole
     * Crossing speed bump
     * Impact from below (pushed upward)
     - Negative (-): Downward acceleration
     * Sudden drop
     * Landing after jump

     Normal driving: ~1.0G
     - Acceleration due to gravity
     - When driving on flat surface: Z ≈ 1.0G

     Example values:
     - 1.0G: Flat surface driving (gravity)
     - 1.5G: Passing small bump
     - 2.0G: Large pothole
     - 0.5G: Descending or jumping

     Usage:
     ```swift
     let verticalDeviation = abs(data.z - 1.0)
     if verticalDeviation > 0.5 {
     print("Poor road condition or impact")
     }

     if data.z > 2.0 {
     print("Speed bump or pothole")
     }
     ```

     Why 1.0G?:
     - Earth's gravity = 1G = 9.8 m/s²
     - Z-axis measures 1G even when stationary
     */
    /// @var z
    /// @brief Z-axis acceleration (vertical direction, G-force)
    ///
    /// Z-axis acceleration in G-force (vertical/up-down)
    /// Positive: up, Negative: down
    let z: Double

    // MARK: - Initialization

    /*
     【Initialization Method】

     Creates an AccelerationData instance.

     Parameters:
     - timestamp: Measurement time
     - x: X-axis acceleration (lateral)
     - y: Y-axis acceleration (longitudinal)
     - z: Z-axis acceleration (vertical)

     Usage example:
     ```swift
     // 1. Normal driving (gravity only)
     let normal = AccelerationData(
     timestamp: Date(),
     x: 0.0,
     y: 0.0,
     z: 1.0  // gravity
     )

     // 2. Hard braking
     let braking = AccelerationData(
     timestamp: Date(),
     x: 0.0,
     y: -1.8,  // backward acceleration (braking)
     z: 1.0
     )

     // 3. Collision
     let impact = AccelerationData(
     timestamp: Date(),
     x: 1.5,   // pushed to the right
     y: -3.5,  // pushed backward (front impact)
     z: 0.8    // slightly downward
     )

     // 4. Created during parsing
     let data = AccelerationData(
     timestamp: baseDate.addingTimeInterval(timeOffset),
     x: parsedX,
     y: parsedY,
     z: parsedZ
     )
     ```
     */
    init(timestamp: Date, x: Double, y: Double, z: Double) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.z = z
    }

    // MARK: - Calculations

    /*
     【Total Acceleration Magnitude】

     Calculates the vector magnitude of 3-axis acceleration.

     Mathematical formula:
     ```
     magnitude = √(x² + y² + z²)
     ```

     Return value:
     - Double: Total acceleration (G units)

     Calculation example:
     ```
     x = 1.5
     y = -3.5
     z = 0.8

     magnitude = √(1.5² + (-3.5)² + 0.8²)
     = √(2.25 + 12.25 + 0.64)
     = √15.14
     = 3.89G
     ```

     Usage example:
     ```swift
     let data = AccelerationData(timestamp: Date(), x: 1.5, y: -3.5, z: 0.8)
     let mag = data.magnitude  // 3.89

     if mag > 2.5 {
     print("Impact detected! \(mag)G")
     triggerEventRecording()
     }

     // Display in chart
     Chart(dataPoints) { point in
     LineMark(
     x: .value("Time", point.timestamp),
     y: .value("G-Force", point.magnitude)
     )
     }
     ```

     Why use vector magnitude?:
     - Total acceleration regardless of direction
     - Useful for determining impact severity
     - Can be judged with a single threshold
     */
    /// @brief Calculate total acceleration magnitude (vector length)
    /// @return Vector magnitude of 3-axis acceleration (G units)
    ///
    /// Total acceleration magnitude (vector length)
    var magnitude: Double {
        return sqrt(x * x + y * y + z * z)  // √(x² + y² + z²)
    }

    /*
     【Horizontal Plane Acceleration Magnitude (Lateral Magnitude)】

     Calculates acceleration magnitude in X-Y plane (excluding Z-axis).

     Mathematical formula:
     ```
     lateralMagnitude = √(x² + y²)
     ```

     Return value:
     - Double: Horizontal plane acceleration (G units)

     Purpose:
     - Analyze driving patterns (excluding vertical movement)
     - Measure turning/braking intensity
     - Minimize road surface condition effects

     Calculation example:
     ```
     x = 2.0  (left turn)
     y = -1.5 (braking)
     z = 1.2  (road bumps)

     lateralMagnitude = √(2.0² + (-1.5)²)
     = √(4.0 + 2.25)
     = √6.25
     = 2.5G

     magnitude = √(2.0² + (-1.5)² + 1.2²) = 2.74G
     ```

     Usage example:
     ```swift
     let lateral = data.lateralMagnitude

     // Analyze driving pattern
     if lateral > 1.5 {
     print("Sudden steering or braking")
     }

     // Driving habit score (excluding Z-axis road effects)
     let drivingScore = 100 - (lateral * 10)
     ```
     */
    /// @brief Horizontal plane acceleration magnitude (X-Y plane)
    /// @return Acceleration magnitude in X-Y plane (G units)
    ///
    /// Lateral acceleration magnitude (X-Y plane)
    var lateralMagnitude: Double {
        return sqrt(x * x + y * y)  // √(x² + y²)
    }

    /*
     【Check for Significant Acceleration】

     Checks if total acceleration exceeds 1.5G.

     Threshold: 1.5G
     - Normal driving: < 1.5G
     - Significant acceleration: > 1.5G

     Return value:
     - Bool: true if exceeds 1.5G

     Usage example:
     ```swift
     if data.isSignificant {
     print("Significant acceleration detected: \(data.magnitudeString)")
     highlightOnChart()
     }

     // Filter only significant data
     let significantEvents = allData.filter { $0.isSignificant }
     print("Total \(significantEvents.count) significant events")
     ```

     Why 1.5G?:
     - Normal driving: 0.5-1.2G
     - Sudden maneuver: 1.2-1.5G
     - Abnormal situation: > 1.5G
     */
    /// @brief Check for significant acceleration (> 1.5G)
    /// @return true if exceeds 1.5G
    ///
    /// Check if this reading indicates significant acceleration
    /// Threshold: > 1.5 G-force
    var isSignificant: Bool {
        return magnitude > 1.5
    }

    /*
     【Check for Impact】

     Checks if total acceleration exceeds 2.5G (impact/accident).

     Threshold: 2.5G
     - Normal driving: < 2.5G
     - Impact/accident: > 2.5G

     Return value:
     - Bool: true if exceeds 2.5G

     Usage example:
     ```swift
     if data.isImpact {
     print("Impact detected! \(data.magnitudeString)")
     print("Direction: \(data.primaryDirection.displayName)")

     // Trigger event recording
     triggerEventRecording(before: 10, after: 20)

     // Send notification
     sendEmergencyNotification()

     // Protect file (prevent auto-deletion)
     protectCurrentRecording()
     }

     // Display only impact events
     let impacts = allData.filter { $0.isImpact }
     print("Impact events: \(impacts.count)")
     ```

     Real-world examples:
     - Hard braking: ~1.5-2.0G (not impact)
     - Minor contact: 2.5-3.5G (impact)
     - Medium collision: 3.5-5.0G (impact)
     - Severe collision: > 5.0G (severe impact)
     */
    /// @brief Check for impact event (> 2.5G)
    /// @return true if exceeds 2.5G
    ///
    /// Check if this reading indicates an impact/collision
    /// Threshold: > 2.5 G-force
    var isImpact: Bool {
        return magnitude > 2.5
    }

    /*
     【Check for Severe Impact】

     Checks if total acceleration exceeds 4.0G (severe impact).

     Threshold: 4.0G
     - Normal impact: 2.5-4.0G
     - Severe impact: > 4.0G

     Return value:
     - Bool: true if exceeds 4.0G

     Usage example:
     ```swift
     if data.isSevereImpact {
     print("SEVERE IMPACT DETECTED! \(data.magnitudeString)")

     // Emergency measures
     triggerEmergencyMode()

     // Auto-call 911 (some dashcams)
     callEmergencyServices()

     // Send SMS to emergency contacts
     sendEmergencySMS(location: currentGPS)

     // Airbag deployment possibility
     if data.magnitude > 10.0 {
     print("Airbag deployment-level impact")
     }
     }
     ```

     Real-world scenarios:
     - 4-6G: Medium-speed collision
     - 6-10G: High-speed collision
     - >10G: Very severe collision
     - >20G: Fatal collision (momentary)
     */
    /// @brief Check for severe impact (> 4.0G)
    /// @return true if exceeds 4.0G
    ///
    /// Check if this reading indicates a severe impact
    /// Threshold: > 4.0 G-force
    var isSevereImpact: Bool {
        return magnitude > 4.0
    }

    /*
     【Impact Severity Classification】

     Classifies impact severity into 5 levels based on total acceleration magnitude.

     Classification criteria:
     - None:     < 1.0G  (normal driving)
     - Low:      1.0-1.5G (minor acceleration)
     - Moderate: 1.5-2.5G (significant acceleration)
     - High:     2.5-4.0G (impact)
     - Severe:   > 4.0G   (severe impact)

     Return value:
     - ImpactSeverity: Impact severity enum

     Usage example:
     ```swift
     let severity = data.impactSeverity

     switch severity {
     case .none:
     statusLabel.text = "Normal"
     statusLabel.textColor = .systemGreen
     case .low:
     statusLabel.text = "Minor"
     statusLabel.textColor = .systemYellow
     case .moderate:
     statusLabel.text = "Caution"
     statusLabel.textColor = .systemOrange
     case .high:
     statusLabel.text = "Impact"
     statusLabel.textColor = .systemRed
     triggerEventRecording()
     case .severe:
     statusLabel.text = "Severe"
     statusLabel.textColor = .systemRed
     triggerEmergencyMode()
     }

     // Apply UI color
     circle.fill(Color(hex: severity.colorHex))

     // Filter
     let severeImpacts = allData.filter { $0.impactSeverity == .severe }
     ```

     Color codes:
     - None: Green (#4CAF50)
     - Low: Light Green (#8BC34A)
     - Moderate: Amber (#FFC107)
     - High: Orange (#FF9800)
     - Severe: Red (#F44336)
     */
    /// @brief Classify impact severity (5 levels)
    /// @return ImpactSeverity enum (none, low, moderate, high, severe)
    ///
    /// Classify the impact severity
    var impactSeverity: ImpactSeverity {
        let mag = magnitude  // Total acceleration magnitude

        if mag > 4.0 {
            return .severe  // Severe (> 4.0G)
        } else if mag > 2.5 {
            return .high  // High (2.5-4.0G)
        } else if mag > 1.5 {
            return .moderate  // Moderate (1.5-2.5G)
        } else if mag > 1.0 {
            return .low  // Low (1.0-1.5G)
        } else {
            return .none  // None (< 1.0G)
        }
    }

    /*
     【Determine Primary Impact Direction】

     Determines impact direction based on the axis with the largest absolute value.

     Algorithm:
     1. Calculate |x|, |y|, |z|
     2. Find maximum value
     3. Check sign of corresponding axis

     Return value:
     - ImpactDirection: Impact direction enum

     Usage example:
     ```swift
     let direction = data.primaryDirection

     print("Primary impact direction: \(direction.displayName)")
     // "Forward", "Backward", "Left", "Right", "Up", "Down"

     // Display icon
     let icon = Image(systemName: direction.iconName)
     // arrow.up, arrow.down, arrow.left, arrow.right, etc.

     // Handle by direction
     switch direction {
     case .forward:
     print("Forward acceleration or rear impact")
     case .backward:
     print("Braking or front impact")
     case .left:
     print("Right turn or right side impact")
     case .right:
     print("Left turn or left side impact")
     case .up:
     print("Pothole or downward impact")
     case .down:
     print("Drop or upward impact")
     }

     // Rotate UI arrow
     arrowView.transform = CGAffineTransform(rotationAngle: direction.angle)
     ```

     Example calculation:
     ```
     x = 1.5, y = -3.5, z = 0.8

     |x| = 1.5
     |y| = 3.5  ← maximum!
     |z| = 0.8

     y < 0 → backward (braking/front impact)
     ```
     */
    /// @brief Determine primary impact direction
    /// @return ImpactDirection enum (forward, backward, left, right, up, down)
    ///
    /// Determine primary impact direction
    var primaryDirection: ImpactDirection {
        let absX = abs(x)  // X-axis absolute value
        let absY = abs(y)  // Y-axis absolute value
        let absZ = abs(z)  // Z-axis absolute value

        let maxValue = max(absX, absY, absZ)  // Find maximum

        // Return direction of axis with maximum value
        if maxValue == absX {
            return x > 0 ? .right : .left  // X-axis is maximum
        } else if maxValue == absY {
            return y > 0 ? .forward : .backward  // Y-axis is maximum
        } else {
            return z > 0 ? .up : .down  // Z-axis is maximum
        }
    }

    // MARK: - Formatting

    /*
     【Acceleration String Format】

     Converts X, Y, Z axis accelerations into a readable string.

     Format: "X: XXX.XXG, Y: XXX.XXG, Z: XXX.XXG"

     Return value:
     - String: Formatted 3-axis acceleration string

     Usage example:
     ```swift
     let data = AccelerationData(timestamp: Date(), x: 1.5, y: -3.5, z: 0.8)
     print(data.formattedString)
     // "X: 1.50G, Y: -3.50G, Z: 0.80G"

     // UI label
     detailLabel.text = data.formattedString

     // Log output
     print("[\(data.timestamp)] \(data.formattedString)")

     // Data export
     let csv = "\(data.timestamp),\(data.formattedString)"
     ```

     Format description:
     - %.2f: 2 decimal places
     - G: G-force unit indicator
     */
    /// @brief Format acceleration as string
    /// @return "X: XXX.XXG, Y: XXX.XXG, Z: XXX.XXG" format
    ///
    /// Format acceleration as string with G-force units
    var formattedString: String {
        return String(format: "X: %.2fG, Y: %.2fG, Z: %.2fG", x, y, z)
    }

    /*
     【Total Acceleration Magnitude String】

     Converts vector magnitude into a readable string.

     Format: "XXX.XX G"

     Return value:
     - String: Formatted total acceleration string

     Usage example:
     ```swift
     let data = AccelerationData(timestamp: Date(), x: 1.5, y: -3.5, z: 0.8)
     print(data.magnitudeString)
     // "3.89 G"

     // Chart label
     Text(data.magnitudeString)
     .font(.caption)

     // Alert message
     if data.isImpact {
     showAlert(title: "Impact Detected", message: "Severity: \(data.magnitudeString)")
     }

     // Statistics
     let maxG = allData.map { $0.magnitude }.max() ?? 0
     print("Maximum acceleration: \(String(format: "%.2f G", maxG))")
     ```
     */
    /// @brief Format total acceleration magnitude as string
    /// @return "XXX.XX G" format
    ///
    /// Format magnitude as string
    var magnitudeString: String {
        return String(format: "%.2f G", magnitude)
    }
}

// MARK: - Supporting Types

/*
 【ImpactSeverity Enum】

 Enum that classifies impact severity into 5 levels.

 Protocols:
 - String: Uses string as Raw Value
 - Codable: JSON serialization

 Levels:
 - none: Normal driving (< 1.0G)
 - low: Minor (1.0-1.5G)
 - moderate: Moderate (1.5-2.5G)
 - high: High (2.5-4.0G)
 - severe: Severe (> 4.0G)
 */
/// @enum ImpactSeverity
/// @brief Impact severity classification (5 levels)
///
/// Impact severity classification
enum ImpactSeverity: String, Codable {
    case none = "none"          // Normal driving
    case low = "low"            // Minor acceleration
    case moderate = "moderate"  // Significant acceleration
    case high = "high"          // Impact
    case severe = "severe"      // Severe impact

    /*
     【Display Name】

     Returns the name with first letter capitalized.

     Return value:
     - String: "None", "Low", "Moderate", "High", "Severe"

     Usage example:
     ```swift
     let severity = ImpactSeverity.high
     print(severity.displayName)  // "High"

     // UI label
     severityLabel.text = severity.displayName
     ```
     */
    var displayName: String {
        return rawValue.capitalized  // First letter capitalized
    }

    /*
     【Color Code】

     Returns the color code corresponding to impact severity.

     Colors:
     - None: Green (#4CAF50) - Safe
     - Low: Light Green (#8BC34A) - Minor
     - Moderate: Amber (#FFC107) - Caution
     - High: Orange (#FF9800) - Danger
     - Severe: Red (#F44336) - Severe

     Return value:
     - String: Hex color code

     Usage example:
     ```swift
     let severity = data.impactSeverity
     let color = Color(hex: severity.colorHex)

     Circle()
     .fill(color)
     .frame(width: 50, height: 50)

     // Chart color
     LineMark(...)
     .foregroundStyle(Color(hex: severity.colorHex))
     ```
     */
    var colorHex: String {
        switch self {
        case .none:
            return "#4CAF50"  // Green - Safe
        case .low:
            return "#8BC34A"  // Light Green - Minor
        case .moderate:
            return "#FFC107"  // Amber - Caution
        case .high:
            return "#FF9800"  // Orange - Danger
        case .severe:
            return "#F44336"  // Red - Severe
        }
    }
}

/*
 【ImpactDirection Enum】

 Enum that classifies impact direction into 6 directions.

 Protocols:
 - String: Uses string as Raw Value
 - Codable: JSON serialization

 Directions:
 - forward: Forward (Y+)
 - backward: Backward (Y-)
 - left: Left (X-)
 - right: Right (X+)
 - up: Up (Z+)
 - down: Down (Z-)
 */
/// @enum ImpactDirection
/// @brief Impact direction (6 directions)
///
/// Impact direction
enum ImpactDirection: String, Codable {
    case forward = "forward"    // Forward acceleration / rear impact
    case backward = "backward"  // Braking / front impact
    case left = "left"          // Left acceleration / right impact
    case right = "right"        // Right acceleration / left impact
    case up = "up"              // Upward acceleration / downward impact
    case down = "down"          // Downward acceleration / upward impact

    /*
     【Display Name】

     Returns the name with first letter capitalized.

     Return value:
     - String: "Forward", "Backward", "Left", "Right", "Up", "Down"
     */
    var displayName: String {
        return rawValue.capitalized  // First letter capitalized
    }

    /*
     【Icon Name】

     Returns SF Symbols icon name.

     Return value:
     - String: SF Symbols name

     Icons:
     - Forward: arrow.up
     - Backward: arrow.down
     - Left: arrow.left
     - Right: arrow.right
     - Up: arrow.up.circle
     - Down: arrow.down.circle

     Usage example:
     ```swift
     let direction = data.primaryDirection

     // SwiftUI
     Image(systemName: direction.iconName)
     .font(.largeTitle)

     // UIKit
     let image = UIImage(systemName: direction.iconName)
     imageView.image = image
     ```
     */
    var iconName: String {
        switch self {
        case .forward:
            return "arrow.up"           // ↑
        case .backward:
            return "arrow.down"         // ↓
        case .left:
            return "arrow.left"         // ←
        case .right:
            return "arrow.right"        // →
        case .up:
            return "arrow.up.circle"    // ⊙↑
        case .down:
            return "arrow.down.circle"  // ⊙↓
        }
    }
}

// MARK: - Identifiable

/*
 【Identifiable Protocol Extension】

 Provides unique identifier for use in SwiftUI List, ForEach, etc.

 Usage example:
 ```swift
 List(accelerationData) { point in
 HStack {
 Text(point.magnitudeString)
 Spacer()
 Circle()
 .fill(Color(hex: point.impactSeverity.colorHex))
 .frame(width: 20, height: 20)
 }
 }
 ```
 */
extension AccelerationData: Identifiable {
    var id: Date { timestamp }  // Use timestamp as unique identifier
}

// MARK: - Sample Data

/*
 【Sample Data Extension】

 Provides sample acceleration data for testing and SwiftUI previews.

 Scenarios:
 - normal: Normal driving
 - braking: Hard braking
 - sharpTurn: Sharp turn
 - impact: Impact
 - severeImpact: Severe impact
 */
extension AccelerationData {
    /*
     【Normal Driving】

     Flat surface driving with only gravity (1G) applied.

     Values:
     - X: 0.0G (no lateral)
     - Y: 0.0G (no longitudinal)
     - Z: 1.0G (gravity)
     */
    /// Normal driving (minimal acceleration)
    static let normal = AccelerationData(
        timestamp: Date(),
        x: 0.0,
        y: 0.0,
        z: 1.0  // Gravity
    )

    /*
     【Hard Braking】

     1.8G backward acceleration (braking).

     Values:
     - X: 0.0G (no lateral)
     - Y: -1.8G (braking)
     - Z: 1.0G (gravity)

     Total acceleration: √(0² + 1.8² + 1²) = 2.06G (Moderate)
     */
    /// Moderate braking
    static let braking = AccelerationData(
        timestamp: Date(),
        x: 0.0,
        y: -1.8,  // Braking
        z: 1.0
    )

    /*
     【Sharp Turn】

     2.2G to the right + slight forward acceleration.

     Values:
     - X: 2.2G (right, left turn)
     - Y: 0.5G (forward acceleration)
     - Z: 1.0G (gravity)

     Total acceleration: √(2.2² + 0.5² + 1²) = 2.44G (Moderate)
     */
    /// Sharp turn
    static let sharpTurn = AccelerationData(
        timestamp: Date(),
        x: 2.2,   // Right (left turn)
        y: 0.5,   // Slight acceleration
        z: 1.0
    )

    /*
     【Impact Event】

     Front collision scenario.

     Values:
     - X: 1.5G (pushed to the right)
     - Y: -3.5G (pushed backward, front impact)
     - Z: 0.8G (slightly downward)

     Total acceleration: √(1.5² + 3.5² + 0.8²) = 3.89G (High)
     Direction: Backward (Y-axis is maximum, negative)
     */
    /// Impact event
    static let impact = AccelerationData(
        timestamp: Date(),
        x: 1.5,   // Right
        y: -3.5,  // Front impact
        z: 0.8    // Slightly downward
    )

    /*
     【Severe Impact】

     Severe front collision scenario.

     Values:
     - X: 2.8G (strongly pushed to the right)
     - Y: -5.2G (strongly pushed backward)
     - Z: 1.5G (bounced upward)

     Total acceleration: √(2.8² + 5.2² + 1.5²) = 6.08G (Severe)
     */
    /// Severe impact
    static let severeImpact = AccelerationData(
        timestamp: Date(),
        x: 2.8,   // Strongly to the right
        y: -5.2,  // Severe front impact
        z: 1.5    // Bounced upward
    )

    /*
     【Sample Data Array】

     Array containing scenarios from normal driving to impact.

     Usage example:
     ```swift
     // Chart preview
     Chart(AccelerationData.sampleData) { point in
     LineMark(
     x: .value("Time", point.timestamp),
     y: .value("G-Force", point.magnitude)
     )
     }

     // Testing
     func testImpactDetection() {
     let sample = AccelerationData.sampleData
     let impacts = sample.filter { $0.isImpact }
     XCTAssertEqual(impacts.count, 1)
     }
     ```
     */
    /// Array of sample data points
    static let sampleData: [AccelerationData] = [
        normal,
        AccelerationData(timestamp: Date().addingTimeInterval(1), x: 0.2, y: 0.5, z: 1.0),
        AccelerationData(timestamp: Date().addingTimeInterval(2), x: -0.3, y: 1.2, z: 1.0),
        braking,
        AccelerationData(timestamp: Date().addingTimeInterval(4), x: 0.1, y: 0.3, z: 1.0),
        sharpTurn,
        impact
    ]
}
