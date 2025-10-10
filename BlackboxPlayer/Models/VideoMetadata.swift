//
//  VideoMetadata.swift
//  BlackboxPlayer
//
//  Model for video file metadata (GPS and G-Sensor data)
//

import Foundation

/// Metadata associated with a dashcam video file
struct VideoMetadata: Codable, Equatable {
    /// GPS data points throughout the recording
    let gpsPoints: [GPSPoint]

    /// G-Sensor acceleration data throughout the recording
    let accelerationData: [AccelerationData]

    /// Device/dashcam information (optional)
    let deviceInfo: DeviceInfo?

    // MARK: - Initialization

    init(
        gpsPoints: [GPSPoint] = [],
        accelerationData: [AccelerationData] = [],
        deviceInfo: DeviceInfo? = nil
    ) {
        self.gpsPoints = gpsPoints
        self.accelerationData = accelerationData
        self.deviceInfo = deviceInfo
    }

    // MARK: - GPS Methods

    /// Check if GPS data is available
    var hasGPSData: Bool {
        return !gpsPoints.isEmpty
    }

    /// Get GPS point at specific time offset
    /// - Parameter timeOffset: Time offset in seconds from start of video
    /// - Returns: Closest GPS point or nil
    func gpsPoint(at timeOffset: TimeInterval) -> GPSPoint? {
        guard !gpsPoints.isEmpty else { return nil }

        // Find closest GPS point by timestamp
        return gpsPoints.min(by: { point1, point2 in
            let diff1 = abs(point1.timestamp.timeIntervalSince(gpsPoints[0].timestamp) - timeOffset)
            let diff2 = abs(point2.timestamp.timeIntervalSince(gpsPoints[0].timestamp) - timeOffset)
            return diff1 < diff2
        })
    }

    /// Calculate total distance traveled
    var totalDistance: Double {
        guard gpsPoints.count >= 2 else { return 0 }

        var total: Double = 0
        for i in 0..<(gpsPoints.count - 1) {
            total += gpsPoints[i].distance(to: gpsPoints[i + 1])
        }
        return total
    }

    /// Calculate average speed from GPS data
    var averageSpeed: Double? {
        let speeds = gpsPoints.compactMap { $0.speed }
        guard !speeds.isEmpty else { return nil }
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    /// Calculate maximum speed from GPS data
    var maximumSpeed: Double? {
        return gpsPoints.compactMap { $0.speed }.max()
    }

    /// Get route as array of coordinates for map display
    var routeCoordinates: [GPSPoint] {
        return gpsPoints.filter { $0.isValid }
    }

    // MARK: - Acceleration Methods

    /// Check if G-Sensor data is available
    var hasAccelerationData: Bool {
        return !accelerationData.isEmpty
    }

    /// Get acceleration data at specific time offset
    /// - Parameter timeOffset: Time offset in seconds from start of video
    /// - Returns: Closest acceleration data or nil
    func accelerationData(at timeOffset: TimeInterval) -> AccelerationData? {
        guard !accelerationData.isEmpty else { return nil }

        // Find closest data point by timestamp
        return accelerationData.min(by: { data1, data2 in
            let diff1 = abs(data1.timestamp.timeIntervalSince(accelerationData[0].timestamp) - timeOffset)
            let diff2 = abs(data2.timestamp.timeIntervalSince(accelerationData[0].timestamp) - timeOffset)
            return diff1 < diff2
        })
    }

    /// Find all significant acceleration events
    var significantEvents: [AccelerationData] {
        return accelerationData.filter { $0.isSignificant }
    }

    /// Find all impact events
    var impactEvents: [AccelerationData] {
        return accelerationData.filter { $0.isImpact }
    }

    /// Calculate maximum G-force experienced
    var maximumGForce: Double? {
        return accelerationData.map { $0.magnitude }.max()
    }

    /// Check if video contains impact events
    var hasImpactEvents: Bool {
        return !impactEvents.isEmpty
    }

    // MARK: - Combined Analysis

    /// Analyze metadata and provide summary
    var summary: MetadataSummary {
        return MetadataSummary(
            hasGPS: hasGPSData,
            gpsPointCount: gpsPoints.count,
            totalDistance: totalDistance,
            averageSpeed: averageSpeed,
            maximumSpeed: maximumSpeed,
            hasAcceleration: hasAccelerationData,
            accelerationPointCount: accelerationData.count,
            impactEventCount: impactEvents.count,
            maximumGForce: maximumGForce
        )
    }
}

// MARK: - Supporting Types

/// Device/dashcam information
struct DeviceInfo: Codable, Equatable {
    /// Device manufacturer
    let manufacturer: String?

    /// Device model name
    let model: String?

    /// Firmware version
    let firmwareVersion: String?

    /// Device serial number
    let serialNumber: String?

    /// Recording settings/mode
    let recordingMode: String?
}

/// Metadata summary for quick overview
struct MetadataSummary: Codable, Equatable {
    let hasGPS: Bool
    let gpsPointCount: Int
    let totalDistance: Double
    let averageSpeed: Double?
    let maximumSpeed: Double?

    let hasAcceleration: Bool
    let accelerationPointCount: Int
    let impactEventCount: Int
    let maximumGForce: Double?

    /// Format distance as human-readable string
    var distanceString: String {
        if totalDistance >= 1000 {
            return String(format: "%.1f km", totalDistance / 1000)
        } else {
            return String(format: "%.0f m", totalDistance)
        }
    }

    /// Format average speed as string
    var averageSpeedString: String? {
        guard let speed = averageSpeed else { return nil }
        return String(format: "%.1f km/h", speed)
    }

    /// Format maximum speed as string
    var maximumSpeedString: String? {
        guard let speed = maximumSpeed else { return nil }
        return String(format: "%.1f km/h", speed)
    }

    /// Format maximum G-force as string
    var maximumGForceString: String? {
        guard let gForce = maximumGForce else { return nil }
        return String(format: "%.2f G", gForce)
    }
}

// MARK: - Sample Data

extension VideoMetadata {
    /// Sample metadata with GPS and acceleration data
    static let sample = VideoMetadata(
        gpsPoints: GPSPoint.sampleRoute,
        accelerationData: AccelerationData.sampleData,
        deviceInfo: DeviceInfo(
            manufacturer: "BlackVue",
            model: "DR900X-2CH",
            firmwareVersion: "1.010",
            serialNumber: "BV900X123456",
            recordingMode: "Normal"
        )
    )

    /// Empty metadata (no GPS or acceleration data)
    static let empty = VideoMetadata()

    /// Metadata with GPS only
    static let gpsOnly = VideoMetadata(
        gpsPoints: GPSPoint.sampleRoute,
        accelerationData: []
    )

    /// Metadata with acceleration only
    static let accelerationOnly = VideoMetadata(
        gpsPoints: [],
        accelerationData: AccelerationData.sampleData
    )

    /// Metadata with impact event
    static let withImpact = VideoMetadata(
        gpsPoints: GPSPoint.sampleRoute,
        accelerationData: [
            AccelerationData.normal,
            AccelerationData.braking,
            AccelerationData.impact,
            AccelerationData.normal
        ]
    )
}
