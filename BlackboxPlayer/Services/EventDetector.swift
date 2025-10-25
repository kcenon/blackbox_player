/// @file EventDetector.swift
/// @brief Video event auto-detection service
/// @author BlackboxPlayer Development Team
/// @details
/// Service that automatically detects events such as rapid acceleration, hard braking, and sharp turns by analyzing GPS data.
/// Generates event markers by analyzing speed change rates and direction changes.

import Foundation

/// @class EventDetector
/// @brief Event auto-detection service
///
/// @details
/// Automatically detects driving events by analyzing GPS data.
///
/// ## Detection Algorithms
///
/// ### 1. Hard Braking
/// ```
/// Conditions:
/// - Speed decrease ≥ 20 km/h
/// - Time interval ≤ 0.5s
/// - Current speed > 10 km/h (not stopped)
///
/// Magnitude calculation:
/// magnitude = min(1.0, speed decrease / 50.0)
/// ```
///
/// ### 2. Rapid Acceleration
/// ```
/// Conditions:
/// - Speed increase ≥ 20 km/h
/// - Time interval ≤ 0.5s
/// - Previous speed < 100 km/h (not already at high speed)
///
/// Magnitude calculation:
/// magnitude = min(1.0, speed increase / 60.0)
/// ```
///
/// ### 3. Sharp Turn
/// ```
/// Conditions:
/// - Heading change ≥ 45 degrees
/// - Speed > 20 km/h (above certain speed)
/// - Speed change < 10 km/h (not hard braking)
///
/// Magnitude calculation:
/// magnitude = min(1.0, heading change / 90.0)
/// ```
///
/// ## Usage Example
/// ```swift
/// let detector = EventDetector()
/// let gpsPoints = loadGPSData()
///
/// // Detect events
/// let events = detector.detectEvents(from: gpsPoints)
///
/// // Print results
/// for event in events {
///     print(event.description)
/// }
/// ```
class EventDetector {
    // MARK: - Constants

    /// Hard braking detection threshold (km/h)
    private let hardBrakingThreshold: Double = 20.0

    /// Rapid acceleration detection threshold (km/h)
    private let rapidAccelerationThreshold: Double = 20.0

    /// Sharp turn detection threshold (degrees)
    private let sharpTurnThreshold: Double = 45.0

    /// Maximum time interval for event detection (seconds)
    private let maxTimeInterval: TimeInterval = 0.5

    /// Minimum speed for sharp turn detection (km/h)
    private let minSpeedForTurn: Double = 20.0

    // MARK: - Public Methods

    /// @brief Detect events from GPS data
    /// @param gpsPoints GPS point array (sorted by time)
    /// @return Array of detected event markers
    ///
    /// @details
    /// Detects rapid acceleration, hard braking, and sharp turn events by analyzing GPS data.
    ///
    /// **Prerequisites:**
    /// - gpsPoints must be sorted by timestamp
    /// - Minimum of 2 GPS points required
    ///
    /// **Return Value:**
    /// - Array of all detected event markers (sorted by timestamp)
    /// - Returns empty array if insufficient GPS data
    func detectEvents(from gpsPoints: [GPSPoint]) -> [EventMarker] {
        // Need at least 2 GPS points
        guard gpsPoints.count >= 2 else {
            return []
        }

        var events: [EventMarker] = []

        // Analyze consecutive GPS point pairs
        for i in 1..<gpsPoints.count {
            let previousPoint = gpsPoints[i - 1]
            let currentPoint = gpsPoints[i]

            // Calculate time interval
            let timeInterval = currentPoint.timestamp.timeIntervalSince(previousPoint.timestamp)

            // Skip if time interval is too large (missing data)
            guard timeInterval > 0 && timeInterval <= maxTimeInterval else {
                continue
            }

            // Analyze speed changes
            if let eventMarker = detectSpeedChangeEvent(
                previous: previousPoint,
                current: currentPoint,
                timeInterval: timeInterval
            ) {
                events.append(eventMarker)
            }

            // Analyze heading changes (sharp turns)
            if let eventMarker = detectTurnEvent(
                previous: previousPoint,
                current: currentPoint,
                timeInterval: timeInterval
            ) {
                events.append(eventMarker)
            }
        }

        // Sort by timestamp
        return events.sorted()
    }

    // MARK: - Private Methods

    /// @brief Detect speed change events (rapid acceleration/hard braking)
    /// @param previous Previous GPS point
    /// @param current Current GPS point
    /// @param timeInterval Time interval (seconds)
    /// @return EventMarker or nil
    private func detectSpeedChangeEvent(
        previous: GPSPoint,
        current: GPSPoint,
        timeInterval: TimeInterval
    ) -> EventMarker? {
        // Skip if no speed information
        guard let previousSpeed = previous.speed,
              let currentSpeed = current.speed else {
            return nil
        }

        // Calculate speed change (km/h)
        let speedChange = currentSpeed - previousSpeed

        // Detect hard braking
        if speedChange <= -hardBrakingThreshold && currentSpeed > 10.0 {
            // Calculate magnitude: proportional to speed decrease (max 50km/h baseline)
            let magnitude = min(1.0, abs(speedChange) / 50.0)

            return EventMarker(
                timestamp: current.timestamp.timeIntervalSince1970,
                type: .hardBraking,
                magnitude: magnitude,
                metadata: [
                    "speed_before": previousSpeed,
                    "speed_after": currentSpeed,
                    "speed_change": speedChange,
                    "time_interval": timeInterval,
                    "gps_lat": current.latitude,
                    "gps_lon": current.longitude
                ]
            )
        }

        // Detect rapid acceleration
        if speedChange >= rapidAccelerationThreshold && previousSpeed < 100.0 {
            // Calculate magnitude: proportional to speed increase (max 60km/h baseline)
            let magnitude = min(1.0, speedChange / 60.0)

            return EventMarker(
                timestamp: current.timestamp.timeIntervalSince1970,
                type: .rapidAcceleration,
                magnitude: magnitude,
                metadata: [
                    "speed_before": previousSpeed,
                    "speed_after": currentSpeed,
                    "speed_change": speedChange,
                    "time_interval": timeInterval,
                    "gps_lat": current.latitude,
                    "gps_lon": current.longitude
                ]
            )
        }

        return nil
    }

    /// @brief Detect heading change events (sharp turns)
    /// @param previous Previous GPS point
    /// @param current Current GPS point
    /// @param timeInterval Time interval (seconds)
    /// @return EventMarker or nil
    private func detectTurnEvent(
        previous: GPSPoint,
        current: GPSPoint,
        timeInterval: TimeInterval
    ) -> EventMarker? {
        // Skip if no heading or speed information
        guard let previousHeading = previous.heading,
              let currentHeading = current.heading,
              let previousSpeed = previous.speed,
              let currentSpeed = current.speed else {
            return nil
        }

        // Skip if speed is too low (stopped or very slow)
        guard previousSpeed > minSpeedForTurn && currentSpeed > minSpeedForTurn else {
            return nil
        }

        // Calculate heading change (0 ~ 180 degree range)
        let headingChange = calculateHeadingChange(from: previousHeading, to: currentHeading)

        // Detect sharp turn
        if headingChange >= sharpTurnThreshold {
            // Speed change (don't classify as sharp turn if simultaneous hard braking)
            let speedChange = abs(currentSpeed - previousSpeed)

            // Only classify as sharp turn if not hard braking
            guard speedChange < 10.0 else {
                return nil
            }

            // Calculate magnitude: proportional to heading change (max 90 degree baseline)
            let magnitude = min(1.0, headingChange / 90.0)

            return EventMarker(
                timestamp: current.timestamp.timeIntervalSince1970,
                type: .sharpTurn,
                magnitude: magnitude,
                metadata: [
                    "heading_before": previousHeading,
                    "heading_after": currentHeading,
                    "heading_change": headingChange,
                    "speed": currentSpeed,
                    "time_interval": timeInterval,
                    "gps_lat": current.latitude,
                    "gps_lon": current.longitude
                ]
            )
        }

        return nil
    }

    /// @brief Calculate heading change (0 ~ 180 degree range)
    /// @param fromHeading Starting heading (0 ~ 360 degrees)
    /// @param toHeading Ending heading (0 ~ 360 degrees)
    /// @return Heading change (0 ~ 180 degrees)
    ///
    /// @details
    /// Calculates the minimum angle between two headings.
    ///
    /// **Examples:**
    /// ```
    /// from: 10°, to: 350° → 20° (counterclockwise)
    /// from: 350°, to: 10° → 20° (clockwise)
    /// from: 0°, to: 180° → 180°
    /// from: 0°, to: 90° → 90°
    /// ```
    private func calculateHeadingChange(from fromHeading: Double, to toHeading: Double) -> Double {
        // Calculate heading difference
        var diff = abs(toHeading - fromHeading)

        // If over 180 degrees, calculate via opposite direction (minimum angle)
        if diff > 180 {
            diff = 360 - diff
        }

        return diff
    }

    /// @brief Filter events (remove duplicates)
    /// @param events Original event array
    /// @param minInterval Minimum interval (seconds)
    /// @return Filtered event array
    ///
    /// @details
    /// When multiple events of the same type are detected in a short time,
    /// keeps only the strongest event and removes the rest.
    ///
    /// **Usage Example:**
    /// ```swift
    /// let filtered = detector.filterDuplicateEvents(events, minInterval: 2.0)
    /// ```
    func filterDuplicateEvents(_ events: [EventMarker], minInterval: TimeInterval = 2.0) -> [EventMarker] {
        guard !events.isEmpty else {
            return []
        }

        var filteredEvents: [EventMarker] = []
        var lastEventByType: [DrivingEventType: EventMarker] = [:]

        for event in events.sorted() {
            // Check for previous event of same type
            if let lastEvent = lastEventByType[event.type] {
                // Check time interval
                let interval = event.timestamp - lastEvent.timestamp

                if interval < minInterval {
                    // If interval is short, keep only the stronger event
                    if event.magnitude > lastEvent.magnitude {
                        // Current event is stronger
                        if let index = filteredEvents.firstIndex(where: { $0.id == lastEvent.id }) {
                            filteredEvents.remove(at: index)
                        }
                        filteredEvents.append(event)
                        lastEventByType[event.type] = event
                    }
                    // Skip current event if previous event is stronger
                    continue
                }
            }

            // Add new event
            filteredEvents.append(event)
            lastEventByType[event.type] = event
        }

        return filteredEvents.sorted()
    }
}
