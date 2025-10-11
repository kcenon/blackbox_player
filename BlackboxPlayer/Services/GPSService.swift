//
//  GPSService.swift
//  BlackboxPlayer
//
//  Service for managing and querying GPS data synchronized with video playback
//

import Foundation
import Combine

/// Service for managing GPS data synchronized with video playback
class GPSService: ObservableObject {
    // MARK: - Published Properties

    /// Current GPS location based on playback time
    @Published private(set) var currentLocation: GPSPoint?

    /// All GPS points for the current video
    @Published private(set) var routePoints: [GPSPoint] = []

    /// Metadata summary
    @Published private(set) var summary: MetadataSummary?

    // MARK: - Private Properties

    /// Video metadata containing GPS data
    private var metadata: VideoMetadata?

    /// Video start timestamp (for calculating offsets)
    private var videoStartTime: Date?

    // MARK: - Public Methods

    /// Load GPS data from video metadata
    /// - Parameters:
    ///   - metadata: Video metadata containing GPS points
    ///   - startTime: Video recording start time
    func loadGPSData(from metadata: VideoMetadata, startTime: Date) {
        self.metadata = metadata
        self.videoStartTime = startTime
        self.routePoints = metadata.routeCoordinates
        self.summary = metadata.summary

        infoLog("[GPSService] Loaded GPS data: \(metadata.gpsPoints.count) points")
    }

    /// Get GPS location at specific playback time
    /// - Parameter time: Playback time in seconds from video start
    /// - Returns: GPS point at that time, or nil if no data
    func getCurrentLocation(at time: TimeInterval) -> GPSPoint? {
        guard let metadata = metadata else {
            return nil
        }

        let location = metadata.gpsPoint(at: time)

        // Update published property on main thread
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = location
        }

        return location
    }

    /// Get all GPS points in time range
    /// - Parameters:
    ///   - startTime: Start time in seconds
    ///   - endTime: End time in seconds
    /// - Returns: Array of GPS points in range
    func getPoints(from startTime: TimeInterval, to endTime: TimeInterval) -> [GPSPoint] {
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return []
        }

        return metadata.gpsPoints.filter { point in
            let offset = point.timestamp.timeIntervalSince(videoStart)
            return offset >= startTime && offset <= endTime
        }
    }

    /// Calculate route segment from current time
    /// - Parameter time: Current playback time
    /// - Returns: Tuple of (past route, future route)
    func getRouteSegments(at time: TimeInterval) -> (past: [GPSPoint], future: [GPSPoint]) {
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return ([], [])
        }

        let past = metadata.gpsPoints.filter { point in
            let offset = point.timestamp.timeIntervalSince(videoStart)
            return offset <= time
        }

        let future = metadata.gpsPoints.filter { point in
            let offset = point.timestamp.timeIntervalSince(videoStart)
            return offset > time
        }

        return (past, future)
    }

    /// Calculate distance traveled up to current time
    /// - Parameter time: Current playback time in seconds
    /// - Returns: Distance in meters
    func distanceTraveled(at time: TimeInterval) -> Double {
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return 0
        }

        let points = metadata.gpsPoints.filter { point in
            let offset = point.timestamp.timeIntervalSince(videoStart)
            return offset <= time
        }

        guard points.count >= 2 else { return 0 }

        var distance: Double = 0
        for i in 0..<(points.count - 1) {
            distance += points[i].distance(to: points[i + 1])
        }

        return distance
    }

    /// Get average speed up to current time
    /// - Parameter time: Current playback time in seconds
    /// - Returns: Average speed in km/h, or nil if no data
    func averageSpeed(at time: TimeInterval) -> Double? {
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return nil
        }

        let points = metadata.gpsPoints.filter { point in
            let offset = point.timestamp.timeIntervalSince(videoStart)
            return offset <= time
        }

        let speeds = points.compactMap { $0.speed }
        guard !speeds.isEmpty else { return nil }

        return speeds.reduce(0, +) / Double(speeds.count)
    }

    /// Clear all GPS data
    func clear() {
        metadata = nil
        videoStartTime = nil
        routePoints = []
        currentLocation = nil
        summary = nil

        debugLog("[GPSService] GPS data cleared")
    }

    /// Check if GPS data is available
    var hasData: Bool {
        return !(metadata?.gpsPoints.isEmpty ?? true)
    }

    /// Number of GPS points available
    var pointCount: Int {
        return metadata?.gpsPoints.count ?? 0
    }
}
