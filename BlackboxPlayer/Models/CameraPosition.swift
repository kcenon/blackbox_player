//
//  CameraPosition.swift
//  BlackboxPlayer
//
//  Enum for camera position/channel identification
//

import Foundation

/// Camera position/channel in a multi-camera dashcam system
enum CameraPosition: String, Codable, CaseIterable {
    /// Front-facing camera (main camera)
    case front = "F"

    /// Rear-facing camera
    case rear = "R"

    /// Left side camera
    case left = "L"

    /// Right side camera
    case right = "Ri"

    /// Interior camera (cabin view)
    case interior = "I"

    /// Unknown or unrecognized position
    case unknown = "U"

    // MARK: - Display Properties

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .front:
            return "Front"
        case .rear:
            return "Rear"
        case .left:
            return "Left"
        case .right:
            return "Right"
        case .interior:
            return "Interior"
        case .unknown:
            return "Unknown"
        }
    }

    /// Short name for UI display
    var shortName: String {
        return rawValue
    }

    /// Full descriptive name
    var fullName: String {
        switch self {
        case .front:
            return "Front Camera"
        case .rear:
            return "Rear Camera"
        case .left:
            return "Left Side Camera"
        case .right:
            return "Right Side Camera"
        case .interior:
            return "Interior Camera"
        case .unknown:
            return "Unknown Camera"
        }
    }

    /// Channel index (0-based) for array indexing
    var channelIndex: Int {
        switch self {
        case .front:
            return 0
        case .rear:
            return 1
        case .left:
            return 2
        case .right:
            return 3
        case .interior:
            return 4
        case .unknown:
            return -1
        }
    }

    /// Priority for display ordering
    var displayPriority: Int {
        switch self {
        case .front:
            return 1
        case .rear:
            return 2
        case .left:
            return 3
        case .right:
            return 4
        case .interior:
            return 5
        case .unknown:
            return 99
        }
    }

    // MARK: - Detection

    /// Detect camera position from filename
    /// - Parameter filename: Filename to analyze (e.g., "2025_01_10_09_00_00_F.mp4")
    /// - Returns: Detected camera position
    static func detect(from filename: String) -> CameraPosition {
        // Extract the camera identifier (usually before the extension)
        // Format: YYYY_MM_DD_HH_MM_SS_[Position].mp4
        let components = filename.components(separatedBy: "_")

        // Check last component before extension
        if let lastComponent = components.last {
            let withoutExtension = lastComponent.components(separatedBy: ".").first ?? ""

            // Try exact match first
            for position in CameraPosition.allCases {
                if withoutExtension == position.rawValue {
                    return position
                }
            }

            // Try partial match
            if withoutExtension.contains("F") {
                return .front
            } else if withoutExtension.contains("R") && !withoutExtension.contains("Ri") {
                return .rear
            } else if withoutExtension.contains("L") {
                return .left
            } else if withoutExtension.contains("Ri") {
                return .right
            } else if withoutExtension.contains("I") {
                return .interior
            }
        }

        return .unknown
    }

    /// Create camera position from channel index
    /// - Parameter index: Channel index (0-4)
    /// - Returns: Camera position or nil if invalid
    static func from(channelIndex index: Int) -> CameraPosition? {
        return CameraPosition.allCases.first { $0.channelIndex == index }
    }
}

// MARK: - Comparable

extension CameraPosition: Comparable {
    static func < (lhs: CameraPosition, rhs: CameraPosition) -> Bool {
        return lhs.displayPriority < rhs.displayPriority
    }
}
