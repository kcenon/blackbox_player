//
//  GSensorService.swift
//  BlackboxPlayer
//
//  Service for managing and querying G-Sensor data synchronized with video playback
//

import Foundation
import Combine

/// Service for managing G-Sensor acceleration data synchronized with video playback
class GSensorService: ObservableObject {
    // MARK: - Published Properties

    /// Current acceleration data based on playback time
    @Published private(set) var currentAcceleration: AccelerationData?

    /// All acceleration data for the current video
    @Published private(set) var allData: [AccelerationData] = []

    /// Detected impact events (filtered from all data)
    @Published private(set) var impactEvents: [AccelerationData] = []

    /// Current G-force magnitude
    @Published private(set) var currentGForce: Double = 0.0

    /// Peak G-force in current session
    @Published private(set) var peakGForce: Double = 0.0

    // MARK: - Private Properties

    /// Video metadata containing acceleration data
    private var metadata: VideoMetadata?

    /// Video start timestamp (for calculating offsets)
    private var videoStartTime: Date?

    // MARK: - Public Methods

    /// Load G-Sensor data from video metadata
    /// - Parameters:
    ///   - metadata: Video metadata containing acceleration data
    ///   - startTime: Video recording start time
    func loadAccelerationData(from metadata: VideoMetadata, startTime: Date) {
        self.metadata = metadata
        self.videoStartTime = startTime
        self.allData = metadata.accelerationData
        self.impactEvents = metadata.accelerationData.filter { $0.isImpact }

        // Calculate peak G-force
        self.peakGForce = metadata.accelerationData.map { $0.magnitude }.max() ?? 0.0

        infoLog("[GSensorService] Loaded G-Sensor data: \(metadata.accelerationData.count) points, \(impactEvents.count) impacts")
    }

    /// Get acceleration data at specific playback time
    /// - Parameter time: Playback time in seconds from video start
    /// - Returns: Acceleration data at that time, or nil if no data
    func getCurrentAcceleration(at time: TimeInterval) -> AccelerationData? {
        guard let metadata = metadata else {
            return nil
        }

        let acceleration = metadata.accelerationData(at: time)

        // Update published properties on main thread
        DispatchQueue.main.async { [weak self] in
            self?.currentAcceleration = acceleration
            self?.currentGForce = acceleration?.magnitude ?? 0.0
        }

        return acceleration
    }

    /// Get all acceleration data in time range
    /// - Parameters:
    ///   - startTime: Start time in seconds
    ///   - endTime: End time in seconds
    /// - Returns: Array of acceleration data in range
    func getData(from startTime: TimeInterval, to endTime: TimeInterval) -> [AccelerationData] {
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return []
        }

        return metadata.accelerationData.filter { data in
            let offset = data.timestamp.timeIntervalSince(videoStart)
            return offset >= startTime && offset <= endTime
        }
    }

    /// Get impact events in time range
    /// - Parameters:
    ///   - startTime: Start time in seconds
    ///   - endTime: End time in seconds
    ///   - minSeverity: Minimum severity level (default: .moderate)
    /// - Returns: Array of impact events in range
    func getImpacts(
        from startTime: TimeInterval,
        to endTime: TimeInterval,
        minSeverity: ImpactSeverity = .moderate
    ) -> [AccelerationData] {
        guard let videoStart = videoStartTime else {
            return []
        }

        return impactEvents.filter { impact in
            let offset = impact.timestamp.timeIntervalSince(videoStart)
            return offset >= startTime && offset <= endTime &&
                   severityLevel(impact.impactSeverity) >= severityLevel(minSeverity)
        }
    }

    /// Get maximum G-force in time range
    /// - Parameters:
    ///   - startTime: Start time in seconds
    ///   - endTime: End time in seconds
    /// - Returns: Maximum G-force magnitude
    func maxGForce(from startTime: TimeInterval, to endTime: TimeInterval) -> Double {
        let data = getData(from: startTime, to: endTime)
        return data.map { $0.magnitude }.max() ?? 0.0
    }

    /// Get average G-force in time range
    /// - Parameters:
    ///   - startTime: Start time in seconds
    ///   - endTime: End time in seconds
    /// - Returns: Average G-force magnitude
    func averageGForce(from startTime: TimeInterval, to endTime: TimeInterval) -> Double {
        let data = getData(from: startTime, to: endTime)
        guard !data.isEmpty else { return 0.0 }

        let total = data.map { $0.magnitude }.reduce(0, +)
        return total / Double(data.count)
    }

    /// Get all impact events grouped by severity
    /// - Returns: Dictionary mapping severity to impact events
    func impactsBySeverity() -> [ImpactSeverity: [AccelerationData]] {
        var grouped: [ImpactSeverity: [AccelerationData]] = [:]

        for impact in impactEvents {
            let severity = impact.impactSeverity
            if grouped[severity] == nil {
                grouped[severity] = []
            }
            grouped[severity]?.append(impact)
        }

        return grouped
    }

    /// Get all impact events grouped by direction
    /// - Returns: Dictionary mapping direction to impact events
    func impactsByDirection() -> [ImpactDirection: [AccelerationData]] {
        var grouped: [ImpactDirection: [AccelerationData]] = [:]

        for impact in impactEvents {
            let direction = impact.primaryDirection
            if grouped[direction] == nil {
                grouped[direction] = []
            }
            grouped[direction]?.append(impact)
        }

        return grouped
    }

    /// Check if there's significant acceleration at current time
    /// - Parameter time: Playback time in seconds
    /// - Returns: True if acceleration exceeds 1.5 G
    func hasSignificantAcceleration(at time: TimeInterval) -> Bool {
        guard let acceleration = getCurrentAcceleration(at: time) else {
            return false
        }
        return acceleration.isSignificant
    }

    /// Find nearest impact event to specified time
    /// - Parameter time: Target time in seconds
    /// - Returns: Nearest impact event and time offset, or nil if no impacts
    func nearestImpact(to time: TimeInterval) -> (impact: AccelerationData, offset: TimeInterval)? {
        guard let videoStart = videoStartTime,
              !impactEvents.isEmpty else {
            return nil
        }

        let impactsWithOffsets = impactEvents.map { impact -> (AccelerationData, TimeInterval) in
            let offset = impact.timestamp.timeIntervalSince(videoStart)
            return (impact, abs(offset - time))
        }

        guard let nearest = impactsWithOffsets.min(by: { $0.1 < $1.1 }) else {
            return nil
        }

        return nearest
    }

    /// Clear all G-Sensor data
    func clear() {
        metadata = nil
        videoStartTime = nil
        allData = []
        impactEvents = []
        currentAcceleration = nil
        currentGForce = 0.0
        peakGForce = 0.0

        debugLog("[GSensorService] G-Sensor data cleared")
    }

    /// Check if G-Sensor data is available
    var hasData: Bool {
        return !(metadata?.accelerationData.isEmpty ?? true)
    }

    /// Number of data points available
    var dataPointCount: Int {
        return metadata?.accelerationData.count ?? 0
    }

    /// Number of impact events detected
    var impactCount: Int {
        return impactEvents.count
    }

    // MARK: - Private Helpers

    /// Convert severity enum to comparable level
    private func severityLevel(_ severity: ImpactSeverity) -> Int {
        switch severity {
        case .none: return 0
        case .low: return 1
        case .moderate: return 2
        case .high: return 3
        case .severe: return 4
        }
    }
}
