//
//  AccelerationData.swift
//  BlackboxPlayer
//
//  Model for G-Sensor (accelerometer) data
//

import Foundation

/// G-Sensor acceleration data point from dashcam recording
struct AccelerationData: Codable, Equatable, Hashable {
    /// Timestamp of this reading
    let timestamp: Date

    /// X-axis acceleration in G-force (lateral/side-to-side)
    /// Positive: right, Negative: left
    let x: Double

    /// Y-axis acceleration in G-force (longitudinal/forward-backward)
    /// Positive: forward, Negative: backward
    let y: Double

    /// Z-axis acceleration in G-force (vertical/up-down)
    /// Positive: up, Negative: down
    let z: Double

    // MARK: - Initialization

    init(timestamp: Date, x: Double, y: Double, z: Double) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.z = z
    }

    // MARK: - Calculations

    /// Total acceleration magnitude (vector length)
    var magnitude: Double {
        return sqrt(x * x + y * y + z * z)
    }

    /// Lateral acceleration magnitude (X-Y plane)
    var lateralMagnitude: Double {
        return sqrt(x * x + y * y)
    }

    /// Check if this reading indicates significant acceleration
    /// Threshold: > 1.5 G-force
    var isSignificant: Bool {
        return magnitude > 1.5
    }

    /// Check if this reading indicates an impact/collision
    /// Threshold: > 2.5 G-force
    var isImpact: Bool {
        return magnitude > 2.5
    }

    /// Check if this reading indicates a severe impact
    /// Threshold: > 4.0 G-force
    var isSevereImpact: Bool {
        return magnitude > 4.0
    }

    /// Classify the impact severity
    var impactSeverity: ImpactSeverity {
        let mag = magnitude
        if mag > 4.0 {
            return .severe
        } else if mag > 2.5 {
            return .high
        } else if mag > 1.5 {
            return .moderate
        } else if mag > 1.0 {
            return .low
        } else {
            return .none
        }
    }

    /// Determine primary impact direction
    var primaryDirection: ImpactDirection {
        let absX = abs(x)
        let absY = abs(y)
        let absZ = abs(z)

        let maxValue = max(absX, absY, absZ)

        if maxValue == absX {
            return x > 0 ? .right : .left
        } else if maxValue == absY {
            return y > 0 ? .forward : .backward
        } else {
            return z > 0 ? .up : .down
        }
    }

    // MARK: - Formatting

    /// Format acceleration as string with G-force units
    var formattedString: String {
        return String(format: "X: %.2fG, Y: %.2fG, Z: %.2fG", x, y, z)
    }

    /// Format magnitude as string
    var magnitudeString: String {
        return String(format: "%.2f G", magnitude)
    }
}

// MARK: - Supporting Types

/// Impact severity classification
enum ImpactSeverity: String, Codable {
    case none = "none"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case severe = "severe"

    var displayName: String {
        return rawValue.capitalized
    }

    var colorHex: String {
        switch self {
        case .none:
            return "#4CAF50"  // Green
        case .low:
            return "#8BC34A"  // Light Green
        case .moderate:
            return "#FFC107"  // Amber
        case .high:
            return "#FF9800"  // Orange
        case .severe:
            return "#F44336"  // Red
        }
    }
}

/// Impact direction
enum ImpactDirection: String, Codable {
    case forward = "forward"
    case backward = "backward"
    case left = "left"
    case right = "right"
    case up = "up"
    case down = "down"

    var displayName: String {
        return rawValue.capitalized
    }

    var iconName: String {
        switch self {
        case .forward:
            return "arrow.up"
        case .backward:
            return "arrow.down"
        case .left:
            return "arrow.left"
        case .right:
            return "arrow.right"
        case .up:
            return "arrow.up.circle"
        case .down:
            return "arrow.down.circle"
        }
    }
}

// MARK: - Identifiable

extension AccelerationData: Identifiable {
    var id: Date { timestamp }
}

// MARK: - Sample Data

extension AccelerationData {
    /// Normal driving (minimal acceleration)
    static let normal = AccelerationData(
        timestamp: Date(),
        x: 0.0,
        y: 0.0,
        z: 1.0  // Gravity
    )

    /// Moderate braking
    static let braking = AccelerationData(
        timestamp: Date(),
        x: 0.0,
        y: -1.8,
        z: 1.0
    )

    /// Sharp turn
    static let sharpTurn = AccelerationData(
        timestamp: Date(),
        x: 2.2,
        y: 0.5,
        z: 1.0
    )

    /// Impact event
    static let impact = AccelerationData(
        timestamp: Date(),
        x: 1.5,
        y: -3.5,
        z: 0.8
    )

    /// Severe impact
    static let severeImpact = AccelerationData(
        timestamp: Date(),
        x: 2.8,
        y: -5.2,
        z: 1.5
    )

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
