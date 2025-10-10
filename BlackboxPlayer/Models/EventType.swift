//
//  EventType.swift
//  BlackboxPlayer
//
//  Enum for dashcam recording event types
//

import Foundation

/// Event type classification for dashcam recordings
enum EventType: String, Codable, CaseIterable {
    /// Normal continuous recording
    case normal = "normal"

    /// Impact/collision event recording (triggered by G-sensor)
    case impact = "impact"

    /// Parking mode recording (motion/impact detection while parked)
    case parking = "parking"

    /// Manual recording (user-triggered)
    case manual = "manual"

    /// Emergency recording
    case emergency = "emergency"

    /// Unknown or unrecognized event type
    case unknown = "unknown"

    // MARK: - Display Properties

    /// Human-readable display name for the event type
    var displayName: String {
        switch self {
        case .normal:
            return "Normal"
        case .impact:
            return "Impact"
        case .parking:
            return "Parking"
        case .manual:
            return "Manual"
        case .emergency:
            return "Emergency"
        case .unknown:
            return "Unknown"
        }
    }

    /// Color associated with the event type for UI display
    var colorHex: String {
        switch self {
        case .normal:
            return "#4CAF50"  // Green
        case .impact:
            return "#F44336"  // Red
        case .parking:
            return "#2196F3"  // Blue
        case .manual:
            return "#FF9800"  // Orange
        case .emergency:
            return "#9C27B0"  // Purple
        case .unknown:
            return "#9E9E9E"  // Gray
        }
    }

    /// Priority for sorting (higher priority first)
    var priority: Int {
        switch self {
        case .emergency:
            return 5
        case .impact:
            return 4
        case .manual:
            return 3
        case .parking:
            return 2
        case .normal:
            return 1
        case .unknown:
            return 0
        }
    }

    // MARK: - Detection

    /// Detect event type from file path
    /// - Parameter path: File path to analyze
    /// - Returns: Detected event type
    static func detect(from path: String) -> EventType {
        let lowercasedPath = path.lowercased()

        if lowercasedPath.contains("/normal/") || lowercasedPath.hasPrefix("normal/") {
            return .normal
        } else if lowercasedPath.contains("/event/") || lowercasedPath.hasPrefix("event/") ||
                  lowercasedPath.contains("/impact/") || lowercasedPath.hasPrefix("impact/") {
            return .impact
        } else if lowercasedPath.contains("/parking/") || lowercasedPath.hasPrefix("parking/") ||
                  lowercasedPath.contains("/park/") || lowercasedPath.hasPrefix("park/") {
            return .parking
        } else if lowercasedPath.contains("/manual/") || lowercasedPath.hasPrefix("manual/") {
            return .manual
        } else if lowercasedPath.contains("/emergency/") || lowercasedPath.hasPrefix("emergency/") ||
                  lowercasedPath.contains("/sos/") || lowercasedPath.hasPrefix("sos/") {
            return .emergency
        }

        return .unknown
    }
}

// MARK: - Comparable

extension EventType: Comparable {
    static func < (lhs: EventType, rhs: EventType) -> Bool {
        return lhs.priority < rhs.priority
    }
}
