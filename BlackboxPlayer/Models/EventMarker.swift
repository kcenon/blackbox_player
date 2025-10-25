/// @file EventMarker.swift
/// @brief Video event marker model
/// @author BlackboxPlayer Development Team
/// @details
/// Model representing events detected in blackbox video (rapid acceleration, hard braking, sharp turns, etc.).
/// Automatically detects events through GPS data analysis and displays them on the timeline.

import Foundation

/// @enum DrivingEventType
/// @brief Driving event type
///
/// @details
/// Types of driving events that can be detected through GPS data analysis.
///
/// ## Detection Criteria
/// - **hardBraking**: Deceleration of 20km/h or more within 0.5 seconds (impact risk)
/// - **rapidAcceleration**: Acceleration of 20km/h or more within 0.5 seconds (sudden start)
/// - **sharpTurn**: Sudden direction change of 45 degrees or more while maintaining speed (rollover risk)
///
/// ## Color Coding
/// - hardBraking → Red (danger)
/// - rapidAcceleration → Orange (warning)
/// - sharpTurn → Yellow (caution)
enum DrivingEventType: String, Codable {
    /// Hard braking (emergency stop)
    case hardBraking = "hard_braking"

    /// Rapid acceleration
    case rapidAcceleration = "rapid_acceleration"

    /// Sharp turn
    case sharpTurn = "sharp_turn"

    /// @brief Event display name
    var displayName: String {
        switch self {
        case .hardBraking:
            return "Hard Braking"
        case .rapidAcceleration:
            return "Rapid Acceleration"
        case .sharpTurn:
            return "Sharp Turn"
        }
    }

    /// @brief Event description
    var description: String {
        switch self {
        case .hardBraking:
            return "Sudden speed decrease"
        case .rapidAcceleration:
            return "Sudden speed increase"
        case .sharpTurn:
            return "Sudden direction change"
        }
    }

    /// @brief Event severity (0.0 ~ 1.0)
    ///
    /// @details
    /// Risk ranking:
    /// 1. hardBraking: 1.0 (collision risk)
    /// 2. sharpTurn: 0.7 (rollover risk)
    /// 3. rapidAcceleration: 0.5 (sudden start)
    var severity: Double {
        switch self {
        case .hardBraking:
            return 1.0
        case .sharpTurn:
            return 0.7
        case .rapidAcceleration:
            return 0.5
        }
    }
}

/// @struct EventMarker
/// @brief Video event marker
///
/// @details
/// Marker that displays events occurring at specific points during video playback.
///
/// ## Usage Example
/// ```swift
/// let marker = EventMarker(
///     timestamp: 15.5,
///     type: .hardBraking,
///     magnitude: 0.8,
///     metadata: ["speed_before": 80.0, "speed_after": 50.0]
/// )
///
/// print(marker.displayName)  // "Hard Braking"
/// print(marker.description)  // "15.5s: Sudden speed decrease (magnitude: 80%)"
/// ```
struct EventMarker: Identifiable, Codable {
    // MARK: - Properties

    /// @var id
    /// @brief Unique identifier
    let id: UUID

    /// @var timestamp
    /// @brief Event occurrence time (seconds)
    ///
    /// @details
    /// Based on video playback time (starting from 0 seconds)
    /// Determines the position on the timeline.
    let timestamp: TimeInterval

    /// @var type
    /// @brief Event type
    let type: DrivingEventType

    /// @var magnitude
    /// @brief Event magnitude (0.0 ~ 1.0)
    ///
    /// @details
    /// Value in the range of 0~1 representing the severity of the event.
    /// - 0.0 ~ 0.3: Minor
    /// - 0.3 ~ 0.7: Moderate
    /// - 0.7 ~ 1.0: Severe
    ///
    /// **Calculation Example (Hard Braking):**
    /// ```
    /// Speed change = |speed_after - speed_before|
    /// magnitude = min(1.0, speed_change / 50.0)
    ///
    /// Example: 80km/h → 30km/h (50km/h decrease)
    /// magnitude = 50 / 50 = 1.0 (very severe)
    /// ```
    let magnitude: Double

    /// @var metadata
    /// @brief Additional metadata
    ///
    /// @details
    /// Stores additional information related to the event.
    ///
    /// **Storable Information:**
    /// - "speed_before": Speed before event (km/h)
    /// - "speed_after": Speed after event (km/h)
    /// - "heading_before": Previous heading (degrees)
    /// - "heading_after": New heading (degrees)
    /// - "gps_lat": GPS latitude
    /// - "gps_lon": GPS longitude
    let metadata: [String: Double]?

    // MARK: - Initialization

    /// @brief EventMarker initialization
    /// @param timestamp Event occurrence time (seconds)
    /// @param type Event type
    /// @param magnitude Event magnitude (0.0 ~ 1.0)
    /// @param metadata Additional metadata (optional)
    init(
        timestamp: TimeInterval,
        type: DrivingEventType,
        magnitude: Double,
        metadata: [String: Double]? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.type = type
        self.magnitude = min(1.0, max(0.0, magnitude))  // Clamp to 0~1 range
        self.metadata = metadata
    }

    // MARK: - Computed Properties

    /// @brief Event display name
    var displayName: String {
        return type.displayName
    }

    /// @brief Event detailed description
    var description: String {
        let magnitudePercent = Int(magnitude * 100)
        return "\(String(format: "%.1f", timestamp))s: \(type.description) (magnitude: \(magnitudePercent)%)"
    }

    /// @brief Time format string (MM:SS)
    var timeString: String {
        let totalSeconds = Int(timestamp)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Comparable

extension EventMarker: Comparable {
    /// @brief Sort by timestamp
    static func < (lhs: EventMarker, rhs: EventMarker) -> Bool {
        return lhs.timestamp < rhs.timestamp
    }
}

// MARK: - Sample Data

extension EventMarker {
    /// @brief Sample event marker (hard braking)
    static let sampleHardBraking = EventMarker(
        timestamp: 15.5,
        type: .hardBraking,
        magnitude: 0.8,
        metadata: [
            "speed_before": 80.0,
            "speed_after": 30.0,
            "gps_lat": 37.5665,
            "gps_lon": 126.9780
        ]
    )

    /// @brief Sample event marker (rapid acceleration)
    static let sampleRapidAcceleration = EventMarker(
        timestamp: 32.0,
        type: .rapidAcceleration,
        magnitude: 0.6,
        metadata: [
            "speed_before": 20.0,
            "speed_after": 60.0
        ]
    )

    /// @brief Sample event marker (sharp turn)
    static let sampleSharpTurn = EventMarker(
        timestamp: 48.5,
        type: .sharpTurn,
        magnitude: 0.7,
        metadata: [
            "heading_before": 45.0,
            "heading_after": 135.0
        ]
    )

    /// @brief Sample event marker array
    static let samples: [EventMarker] = [
        sampleHardBraking,
        sampleRapidAcceleration,
        sampleSharpTurn
    ]
}
