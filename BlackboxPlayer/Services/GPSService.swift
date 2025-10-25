/// @file GPSService.swift
/// @brief Service for managing and querying GPS data synchronized with video playback
/// @author BlackboxPlayer Development Team
/// @details
/// Provides real-time location, route, and speed information by synchronizing GPS data with video playback time.

/**
 # GPSService - GPS data management service

 ## 📍 What is GPS?

 **GPS (Global Positioning System)** is a satellite-based system for determining current location.

 ### GPS Components:
 ```
 GPS Satellites (in space)
 ↓ Signal transmission
 GPS Receiver (Dashcam)
 ↓ Calculate location
 Coordinate data (latitude, longitude, altitude)
 ```

 ### GPS coordinates:
 - **Latitude**: North-South position (-90° ~ +90°)
 - Equator: 0°
 - North Pole: +90°
 - South Pole: -90°

 - **Longitude**: East-West position (-180° ~ +180°)
 - Prime Meridian: 0°
 - East: Positive
 - West: Negative

 Example: Seoul = (37.5665° N, 126.9780° E)

 ## 🎯 GPS Usage in Dashcams

 ### 1. Record traveled route
 ```
 Time |  Latitude  |  Longitude  | Speed
 -----+-----------+-------------+-------
 0s   | 37.5665   | 126.978     | 30
 1s   | 37.5667   | 126.979     | 35
 2s   | 37.5669   | 126.980     | 40
 ...
 ```

 ### 2. Speed measurement
 - GPS receiver directly calculates speed
 - Or: Calculate from position changes (distance / time)

 ### 3. Specify accident location
 - Provides exact accident point GPS coordinates
 - Can be verified immediately on map apps

 ### 4. Video-location synchronization
 ```
 video frame          GPS data
 ┌──────────┐         ┌──────────┐
 │ 00:00:05 │   ←→   │ 37.5669  │
 │          │         │ 126.980  │
 └──────────┘         └──────────┘
 ```

 ## 💡 Role of GPSService

 ### 1. Load data
 ```swift
 service.loadGPSData(from: metadata, startTime: videoStart)
 // Extract GPS points from VideoMetadata and load into memory
 ```

 ### 2. Time-based query
 ```swift
 let location = service.getCurrentLocation(at: 5.0)
 // Return GPS location at 5 seconds of video playback
 ```

 ### 3. Calculate distance
 ```swift
 let distance = service.distanceTraveled(at: 60.0)
 // Distance traveled from video start to 1 minute (meters)
 ```

 ### 4. Split route
 ```swift
 let (past, future) = service.getRouteSegments(at: 30.0)
 // Already traveled route vs future route
 // Display in different colors on map
 ```

 ## 🔄 Time synchronization

 ### Principle:
 ```
 video start time: 2024-10-12 15:00:00
 GPS data time: 2024-10-12 15:00:03

 Calculate time offset:
 offset = GPS time - video start time
 = 15:00:03 - 15:00:00
 = 3 seconds

 video playback 3 seconds → Display GPS data
 ```

 ### Accuracy:
 - GPS: in seconds (typically 1Hz = 1 measurement per second)
 - Video: frame unit (30fps = 30 frames per second)
 - Interpolation: Linear interpolation between GPS points for smooth display

 ## 📚 Usage Examples

 ```swift
 // 1. Create service
 let gpsService = GPSService()

 // 2. Load GPS data when loading video
 gpsService.loadGPSData(
 from: videoFile.metadata,
 startTime: videoFile.timestamp
 )

 // 3. Query current location during playback
 Timer.publish(every: 0.1, on: .main, in: .common)
 .sink { _ in
 if let location = gpsService.getCurrentLocation(at: currentTime) {
 updateMapMarker(location)
 }
 }

 // 4. Display distance traveled
 Text("Distance traveled: \(gpsService.distanceTraveled(at: currentTime)) m")

 // 5. Display average speed
 if let speed = gpsService.averageSpeed(at: currentTime) {
 Text("Average speed: \(speed) km/h")
 }
 ```

 ---

 This service provides real-time location tracking by perfectly synchronizing video playback with GPS data.
 */

import Foundation
import Combine

// MARK: - GPS Service

/// @class GPSService
/// @brief GPS data management service
/// @details
/// Synchronizes video playback time with GPS data to provide real-time location, route, and speed information.
///
/// ### Key Features:
/// 1. Load and manage GPS data
/// 2. Query location based on playback time
/// 3. Calculate distance traveled
/// 4. Calculate average speed
/// 5. Split route segments (already traveled route vs future route)
///
/// ### What is ObservableObject?
/// - Protocol from the Combine framework
/// - Automatically notifies when @Published properties change
/// - SwiftUI Views automatically update
class GPSService: ObservableObject {

    // MARK: - Published Properties

    /// @var currentLocation
    /// @brief Current GPS location
    /// @details
    /// GPS coordinates corresponding to video playback time.
    ///
    /// ### What is @Published private(set)?
    /// - **@Published**: Automatically updates View when value changes
    /// - **private(set)**: External read-only, writable only within this class
    ///
    /// ### Example:
    /// ```swift
    /// // From outside:
    /// let location = gpsService.currentLocation  // OK (read)
    /// gpsService.currentLocation = ...           // Compile error (cannot write)
    ///
    /// // From inside (this class):
    /// self.currentLocation = newLocation         // OK (can write)
    /// ```
    ///
    /// ### What is GPSPoint?
    /// ```swift
    /// struct GPSPoint {
    ///     let latitude: Double   // Latitude
    ///     let longitude: Double  // Longitude
    ///     let altitude: Double?  // Altitude (optional)
    ///     let speed: Double?     // Speed (optional)
    ///     let timestamp: Date    // Measurement time
    /// }
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// if let location = gpsService.currentLocation {
    ///     print("Current location: \(location.latitude), \(location.longitude)")
    ///     print("Speed: \(location.speed ?? 0) km/h")
    /// }
    /// ```
    @Published private(set) var currentLocation: GPSPoint?

    /// @var routePoints
    /// @brief All route points
    /// @details
    /// Array of all GPS coordinates included in the video.
    ///
    /// ### Purpose:
    /// - Draw entire route on map
    /// - Route preview
    /// - Route analysis (total distance, average speed, etc.)
    ///
    /// ### Example data:
    /// ```
    /// routePoints = [
    ///     GPSPoint(lat: 37.5665, lon: 126.978, time: 0s),
    ///     GPSPoint(lat: 37.5667, lon: 126.979, time: 1s),
    ///     GPSPoint(lat: 37.5669, lon: 126.980, time: 2s),
    ///     ...
    /// ]
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// // Draw route on map
    /// for point in gpsService.routePoints {
    ///     mapView.addAnnotation(point)
    /// }
    /// ```
    @Published private(set) var routePoints: [GPSPoint] = []

    /// @var summary
    /// @brief Metadata summary
    /// @details
    /// Statistical information of GPS data.
    ///
    /// ### What is MetadataSummary?
    /// ```swift
    /// struct MetadataSummary {
    ///     let totalDistance: Double     // Total distance traveled (m)
    ///     let maxSpeed: Double           // Maximum speed (km/h)
    ///     let averageSpeed: Double       // Average speed (km/h)
    ///     let startLocation: GPSPoint    // Starting location
    ///     let endLocation: GPSPoint      // Ending location
    /// }
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// if let summary = gpsService.summary {
    ///     Text("Total distance: \(summary.totalDistance / 1000) km")
    ///     Text("Maximum speed: \(summary.maxSpeed) km/h")
    ///     Text("Average speed: \(summary.averageSpeed) km/h")
    /// }
    /// ```
    @Published private(set) var summary: MetadataSummary?

    // MARK: - Private Properties

    /// @var metadata
    /// @brief Video metadata
    /// @details
    /// All metadata of the video containing GPS data.
    ///
    /// ### What is VideoMetadata?
    /// ```swift
    /// struct VideoMetadata {
    ///     let gpsPoints: [GPSPoint]         // GPS coordinate array
    ///     let routeCoordinates: [GPSPoint]  // Route coordinates (optimized version)
    ///     let gsensorData: [GSensorPoint]   // G-Sensor data
    ///     let summary: MetadataSummary      // Summary information
    /// }
    /// ```
    ///
    /// ### What is private?
    /// - Accessible only from within this class
    /// - Cannot be accessed directly from outside
    /// - Principle of Encapsulation
    private var metadata: VideoMetadata?

    /// @var videoStartTime
    /// @brief Video start time
    /// @details
    /// Absolute time when video recording started.
    ///
    /// ### Purpose:
    /// Used for calculating time offset.
    ///
    /// ```
    /// Video start: 2024-10-12 15:00:00
    /// GPS time:  2024-10-12 15:00:05
    ///
    /// Offset = GPS time - video start
    ///        = 15:00:05 - 15:00:00
    ///        = 5 seconds
    ///
    /// → Display GPS data at 5 seconds of video playback
    /// ```
    ///
    /// ### What is Date?
    /// - Date/time type from Foundation
    /// - Represents absolute time (based on Unix Epoch 1970-01-01 00:00:00 UTC)
    /// - timeIntervalSince(_:) method calculates time difference
    private var videoStartTime: Date?

    // MARK: - Public Methods

    /// @brief Load GPS data
    /// @param metadata Video metadata containing GPS data
    /// @param startTime Video recording start time
    /// @details
    /// Extract GPS data from VideoMetadata and load it into the service.
    ///
    /// ### When to Call:
    /// ```swift
    /// // Right after loading video file:
    /// func loadVideo(_ file: VideoFile) {
    ///     // ... video decoder setup
    ///
    ///     gpsService.loadGPSData(
    ///         from: file.metadata,
    ///         startTime: file.timestamp
    ///     )
    ///
    ///     // ... GPS map UI update
    /// }
    /// ```
    ///
    /// ### Processing Steps:
    /// ```
    /// 1. Save metadata (including GPS points)
    /// 2. Save videoStartTime (for time offset calculation)
    /// 3. Set routePoints (@Published → UI automatically updates)
    /// 4. Set summary (statistical information)
    /// 5. Log
    /// ```
    ///
    /// ### Memory Impact:
    /// - 1 GPS point ≈ 50 bytes
    /// - 1 hour video (3600 seconds, 1Hz GPS) ≈ 180 KB
    /// - Can be safely stored in memory
    func loadGPSData(from metadata: VideoMetadata, startTime: Date) {
        // ===== Step 1: Save metadata =====
        self.metadata = metadata
        self.videoStartTime = startTime

        // ===== Step 2: Set route points =====
        // @Published automatically updates UI
        self.routePoints = metadata.routeCoordinates

        // ===== Step 3: Set summary information =====
        self.summary = metadata.summary

        // ===== Step 4: Log =====
        infoLog("[GPSService] Loaded GPS data: \(metadata.gpsPoints.count) points")
    }

    /// @brief Query GPS location at specific time
    /// @param time Video playback time (in seconds, elapsed from video start)
    /// @return GPS coordinates at that time, or nil if none
    /// @details
    /// Return GPS coordinates corresponding to video playback time.
    ///
    /// ### Time Matching Method:
    ///
    /// 1. **When exact GPS point exists:**
    /// ```
    /// GPS data: [0s, 1s, 2s, 3s, ...]
    /// Playback time: 2.0s
    /// → Return GPS point at 2s
    /// ```
    ///
    /// 2. **Intermediate time (interpolation):**
    /// ```
    /// GPS data: 5s(37.5665, 126.978), 6s(37.5667, 126.980)
    /// Playback time: 5.5s
    ///
    /// Linear interpolation:
    /// lat = 37.5665 + (37.5667 - 37.5665) × 0.5
    ///     = 37.5666
    /// lon = 126.978 + (126.980 - 126.978) × 0.5
    ///     = 126.979
    ///
    /// → GPSPoint(37.5666, 126.979)
    /// ```
    ///
    /// 3. **When no GPS data:**
    /// ```
    /// metadata == nil → Return nil
    /// ```
    ///
    /// ### What is weak self?
    /// ```swift
    /// DispatchQueue.main.async { [weak self] in
    ///     self?.currentLocation = location
    /// }
    /// ```
    ///
    /// - **weak**: Weak reference (prevents memory leak)
    /// - **self?**: self can be nil (Optional)
    ///
    /// **Why is it needed?**
    /// ```
    /// GPSService is released
    ///   ↓
    /// But closure is still waiting to execute
    ///   ↓
    /// Thanks to weak self, self becomes nil
    ///   ↓
    /// self?.currentLocation → safely ignored
    /// ```
    ///
    /// **If it were strong reference:**
    /// ```
    /// Attempting to release GPSService
    ///   ↓
    /// Closure holds strong self
    ///   ↓
    /// GPSService remains in memory (memory leak!)
    /// ```
    ///
    /// ### What is DispatchQueue.main.async?
    /// - **DispatchQueue.main**: Work queue on main thread
    /// - **async**: Asynchronous execution (returns immediately)
    ///
    /// **Why main thread?**
    /// - @Published properties trigger UI updates
    /// - SwiftUI/AppKit can only update UI from main thread
    ///
    /// ```
    /// Background thread (this method called)
    ///   ↓
    /// DispatchQueue.main.async
    ///   ↓
    /// Main thread (UI update safe)
    ///   ↓
    /// Change currentLocation
    ///   ↓
    /// SwiftUI View automatically updates
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// // Called from playback loop
    /// func updatePlayback() {
    ///     let time = syncController.currentTime
    ///
    ///     if let location = gpsService.getCurrentLocation(at: time) {
    ///         // Update map marker
    ///         mapView.updateMarker(location)
    ///
    ///         // Display speed
    ///         speedLabel.text = "\(location.speed ?? 0) km/h"
    ///     }
    /// }
    /// ```
    func getCurrentLocation(at time: TimeInterval) -> GPSPoint? {
        // ===== Step 1: Check metadata =====
        guard let metadata = metadata else {
            // GPS data not loaded
            return nil
        }

        // ===== Step 2: Query GPS point based on time =====
        // VideoMetadata.gpsPoint(at:) also handles interpolation
        let location = metadata.gpsPoint(at: time)

        // ===== Step 3: Update Published property (main thread) =====
        // weak self: prevents memory leak
        // main.async: UI updates only from main thread
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = location
        }

        return location
    }

    /// @brief Query GPS points within time range
    /// @param startTime Start time (in seconds)
    /// @param endTime End time (in seconds)
    /// @return Array of GPS points within that time range
    /// @details
    /// Return all GPS coordinates in a specific time range.
    ///
    /// ### Usage Example:
    ///
    /// 1. **Highlight specific route segment:**
    /// ```swift
    /// // Display 10s~20s segment in red
    /// let points = gpsService.getPoints(from: 10, to: 20)
    /// mapView.drawRoute(points, color: .red)
    /// ```
    ///
    /// 2. **Calculate distance for segment:**
    /// ```swift
    /// let points = gpsService.getPoints(from: 60, to: 120)
    /// let distance = calculateDistance(points)
    /// print("Distance traveled between 1min~2min: \(distance) m")
    /// ```
    ///
    /// 3. **Maximum speed in segment:**
    /// ```swift
    /// let points = gpsService.getPoints(from: 0, to: 60)
    /// let maxSpeed = points.compactMap { $0.speed }.max() ?? 0
    /// print("Maximum speed in first minute: \(maxSpeed) km/h")
    /// ```
    ///
    /// ### Filtering Logic:
    /// ```swift
    /// metadata.gpsPoints.filter { point in
    ///     let offset = point.timestamp.timeIntervalSince(videoStart)
    ///     return offset >= startTime && offset <= endTime
    /// }
    /// ```
    ///
    /// **Step-by-step explanation:**
    /// ```
    /// 1. point.timestamp: GPS measurement absolute time
    ///    Example: 2024-10-12 15:00:05
    ///
    /// 2. videoStart: Video start absolute time
    ///    Example: 2024-10-12 15:00:00
    ///
    /// 3. timeIntervalSince: Calculate time difference
    ///    offset = 15:00:05 - 15:00:00 = 5 seconds
    ///
    /// 4. Range check: offset >= 10 && offset <= 20
    ///    → Include if in 10s~20s range
    /// ```
    ///
    /// ### Performance:
    /// - O(n) time complexity (n = number of GPS points)
    /// - 1 hour video (3600 points) → very fast
    /// - Memory efficient (only filtering)
    func getPoints(from startTime: TimeInterval, to endTime: TimeInterval) -> [GPSPoint] {
        // ===== Step 1: Check data =====
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return []
        }

        // ===== Step 2: Filter by time range =====
        return metadata.gpsPoints.filter { point in
            // Calculate time offset of GPS point
            let offset = point.timestamp.timeIntervalSince(videoStart)

            // Check if within range
            return offset >= startTime && offset <= endTime
        }
    }

    /// @brief Split route segments
    /// @param time Current playback time (in seconds)
    /// @return (past: traveled route, future: upcoming route) tuple
    /// @details
    /// Split the route into two parts based on current time.
    /// - **Past**: Already traveled route
    /// - **Future**: Upcoming route
    ///
    /// ### Visual Example:
    ///
    /// ```
    /// Entire route:
    /// A ━━━━ B ━━━━ C ━━━━ D ━━━━ E
    ///
    /// Current location: C (30s)
    ///
    /// Split result:
    /// Past:   A ━━━━ B ━━━━ C  (Display in blue)
    /// Future:             C ━━━━ D ━━━━ E  (Display in gray)
    /// ```
    ///
    /// ### Map Display Example:
    /// ```swift
    /// let (past, future) = gpsService.getRouteSegments(at: currentTime)
    ///
    /// // Already traveled route: thick blue line
    /// mapView.drawRoute(past, color: .blue, width: 5)
    ///
    /// // Upcoming route: thin gray line
    /// mapView.drawRoute(future, color: .gray, width: 2)
    ///
    /// // Current location: red marker
    /// if let current = past.last {
    ///     mapView.addMarker(current, color: .red)
    /// }
    /// ```
    ///
    /// ### Filtering Logic:
    ///
    /// **Past (already traveled):**
    /// ```swift
    /// offset <= time
    ///
    /// Example: time = 30s
    /// - 0s point: 0 <= 30 → ✅ include
    /// - 15s point: 15 <= 30 → ✅ include
    /// - 30s point: 30 <= 30 → ✅ include
    /// - 45s point: 45 <= 30 → ❌ exclude
    /// ```
    ///
    /// **Future (upcoming):**
    /// ```swift
    /// offset > time
    ///
    /// Example: time = 30s
    /// - 30s point: 30 > 30 → ❌ exclude
    /// - 45s point: 45 > 30 → ✅ include
    /// - 60s point: 60 > 30 → ✅ include
    /// ```
    ///
    /// ### What is tuple?
    /// ```swift
    /// // Return multiple values bundled together
    /// let result = getRouteSegments(at: 30)
    ///
    /// // Access method 1: tuple label
    /// let past = result.past
    /// let future = result.future
    ///
    /// // Access method 2: Destructuring
    /// let (past, future) = getRouteSegments(at: 30)
    /// ```
    func getRouteSegments(at time: TimeInterval) -> (past: [GPSPoint], future: [GPSPoint]) {
        // ===== Step 1: Check data =====
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return ([], [])  // Return empty tuple
        }

        // ===== Step 2: Filter past route (already traveled) =====
        let past = metadata.gpsPoints.filter { point in
            let offset = point.timestamp.timeIntervalSince(videoStart)
            return offset <= time
        }

        // ===== Step 3: Filter future route (upcoming) =====
        let future = metadata.gpsPoints.filter { point in
            let offset = point.timestamp.timeIntervalSince(videoStart)
            return offset > time
        }

        // ===== Step 4: Return tuple =====
        return (past, future)
    }

    /// @brief Calculate distance traveled
    /// @param time Current playback time (in seconds)
    /// @return Distance traveled (meters)
    /// @details
    /// Calculate total distance traveled from video start to current time.
    ///
    /// ### Haversine Formula
    ///
    /// Formula to calculate distance between two GPS coordinates on Earth's surface.
    ///
    /// ```
    /// a = sin²(Δlat/2) + cos(lat1) × cos(lat2) × sin²(Δlon/2)
    /// c = 2 × atan2(√a, √(1−a))
    /// d = R × c
    ///
    /// Where:
    /// - R = Earth's radius (6,371 km)
    /// - lat = Latitude (radians)
    /// - lon = Longitude (radians)
    /// - Δlat = lat2 - lat1
    /// - Δlon = lon2 - lon1
    /// ```
    ///
    /// ### Distance Calculation Process:
    ///
    /// ```
    /// GPS points: A(0s) → B(10s) → C(20s) → D(30s)
    ///
    /// Distance AB = A.distance(to: B) = 100m
    /// Distance BC = B.distance(to: C) = 150m
    /// Distance CD = C.distance(to: D) = 120m
    ///
    /// When time = 30s:
    /// Total distance = 100 + 150 + 120 = 370m
    /// ```
    ///
    /// ### Cumulative calculation:
    /// ```swift
    /// var distance: Double = 0
    /// for i in 0..<(points.count - 1) {
    ///     distance += points[i].distance(to: points[i + 1])
    /// }
    /// ```
    ///
    /// **Step-by-step:**
    /// ```
    /// points = [A, B, C, D]
    ///
    /// i = 0: distance += A.distance(to: B)  → 100
    /// i = 1: distance += B.distance(to: C)  → 250
    /// i = 2: distance += C.distance(to: D)  → 370
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// let distance = gpsService.distanceTraveled(at: currentTime)
    ///
    /// // Convert to kilometers
    /// let km = distance / 1000.0
    ///
    /// // Display in UI
    /// Text(String(format: "Distance traveled: %.2f km", km))
    /// ```
    ///
    /// ### Accuracy:
    /// - GPS error: ±5~10m
    /// - Calculation error: within 0.1m
    /// - Practically sufficiently accurate
    func distanceTraveled(at time: TimeInterval) -> Double {
        // ===== Step 1: Check data =====
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return 0
        }

        // ===== Step 2: Filter GPS points up to current time =====
        let points = metadata.gpsPoints.filter { point in
            let offset = point.timestamp.timeIntervalSince(videoStart)
            return offset <= time
        }

        // ===== Step 3: Need at least 2 points (distance = gap between points) =====
        guard points.count >= 2 else {
            // Cannot calculate distance with 0~1 points
            return 0
        }

        // ===== Step 4: Calculate cumulative distance =====
        var distance: Double = 0

        // Sum distances between adjacent points
        for i in 0..<(points.count - 1) {
            // Calculate distance between two points using Haversine formula
            distance += points[i].distance(to: points[i + 1])
        }

        return distance
    }

    /// @brief Calculate average speed
    /// @param time Current playback time (in seconds)
    /// @return Average speed (km/h), or nil if no data
    /// @details
    /// Calculate average speed from video start to current time.
    ///
    /// ### Calculation method:
    ///
    /// **Method 1: Using GPS speed data (adopted)**
    /// ```
    /// speeds = [30, 35, 40, 45, 40] km/h
    /// averageSpeed = (30 + 35 + 40 + 45 + 40) / 5
    ///              = 190 / 5
    ///              = 38 km/h
    /// ```
    ///
    /// **Method 2: distance/time (alternative)**
    /// ```
    /// distance = 1000m
    /// time = 60s
    /// speed = (1000 / 60) × 3.6
    ///       = 60 km/h
    ///
    /// × 3.6: Convert m/s → km/h
    /// ```
    ///
    /// ### What is compactMap?
    ///
    /// `compactMap` = `map` + `remove nils`.
    ///
    /// ```swift
    /// let speeds = points.map { $0.speed }
    /// // [30, nil, 35, nil, 40]
    ///
    /// let speeds = points.compactMap { $0.speed }
    /// // [30, 35, 40]  ← nils automatically removed
    /// ```
    ///
    /// **How it works:**
    /// ```swift
    /// points = [
    ///     GPSPoint(speed: 30),
    ///     GPSPoint(speed: nil),
    ///     GPSPoint(speed: 35)
    /// ]
    ///
    /// compactMap { $0.speed }
    /// → [30?, nil, 35?]     (map result)
    /// → [30, 35]            (nils removed)
    /// ```
    ///
    /// ### What is reduce?
    ///
    /// Reduce all elements of array to a single value.
    ///
    /// ```swift
    /// speeds.reduce(0, +)
    ///
    /// = speeds.reduce(0) { total, speed in
    ///     return total + speed
    /// }
    /// ```
    ///
    /// **Step-by-step execution:**
    /// ```
    /// speeds = [30, 35, 40]
    ///
    /// Initial value = 0
    /// Step 1: 0 + 30 = 30
    /// Step 2: 30 + 35 = 65
    /// Step 3: 65 + 40 = 105
    /// Final = 105
    /// ```
    ///
    /// **Other reduce examples:**
    /// ```swift
    /// [1, 2, 3, 4].reduce(0, +)  → 10 (sum)
    /// [1, 2, 3, 4].reduce(1, *)  → 24 (product)
    /// ["a", "b"].reduce("", +)   → "ab" (concatenation)
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// if let avgSpeed = gpsService.averageSpeed(at: currentTime) {
    ///     Text(String(format: "Average speed: %.1f km/h", avgSpeed))
    /// } else {
    ///     Text("No speed data")
    /// }
    /// ```
    ///
    /// ### Returns nil when:
    /// - No GPS data
    /// - No speed data up to corresponding time (when GPS speed field is missing)
    func averageSpeed(at time: TimeInterval) -> Double? {
        // ===== Step 1: Check data =====
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return nil
        }

        // ===== Step 2: Filter GPS points up to current time =====
        let points = metadata.gpsPoints.filter { point in
            let offset = point.timestamp.timeIntervalSince(videoStart)
            return offset <= time
        }

        // ===== Step 3: Extract speed data (remove nils) =====
        // compactMap: extract only non-nil speeds
        let speeds = points.compactMap { $0.speed }

        // ===== Step 4: Return nil if no speed data =====
        guard !speeds.isEmpty else {
            return nil
        }

        // ===== Step 5: Calculate average =====
        // reduce(0, +): sum all speeds
        let sum = speeds.reduce(0, +)

        // average = total sum / count
        return sum / Double(speeds.count)
    }

    /// @brief Clear GPS data
    /// @details
    /// Remove all GPS data from memory and return to initial state.
    ///
    /// ### When to Call:
    ///
    /// 1. **When stopping video:**
    /// ```swift
    /// func stopPlayback() {
    ///     syncController.stop()
    ///     gpsService.clear()
    ///     gsensorService.clear()
    /// }
    /// ```
    ///
    /// 2. **Before loading new video:**
    /// ```swift
    /// func loadNewVideo(_ file: VideoFile) {
    ///     gpsService.clear()  // Remove previous data
    ///     gpsService.loadGPSData(from: file.metadata, startTime: file.timestamp)
    /// }
    /// ```
    ///
    /// 3. **Memory cleanup:**
    /// ```swift
    /// func didReceiveMemoryWarning() {
    ///     if !isPlaying {
    ///         gpsService.clear()
    ///     }
    /// }
    /// ```
    ///
    /// ### What is cleared:
    /// - metadata: All metadata (nil)
    /// - videoStartTime: Start time (nil)
    /// - routePoints: Route points (empty array)
    /// - currentLocation: Current location (nil)
    /// - summary: Summary information (nil)
    ///
    /// ### Effect on @Published properties:
    /// ```
    /// clear() called
    ///   ↓
    /// routePoints = []
    ///   ↓
    /// @Published detected
    ///   ↓
    /// SwiftUI View automatically updates
    ///   ↓
    /// Route disappears from map
    /// ```
    func clear() {
        // ===== Reset all data =====
        metadata = nil
        videoStartTime = nil
        routePoints = []          // @Published → UI update
        currentLocation = nil     // @Published → UI update
        summary = nil             // @Published → UI update

        // ===== Log =====
        debugLog("[GPSService] GPS data cleared")
    }

    // MARK: - Computed Properties

    /// @var hasData
    /// @brief Whether GPS data exists
    /// @return true if GPS data exists, false if none
    /// @details
    /// Check if GPS data is loaded and has at least 1 GPS point.
    ///
    /// ### Calculation logic:
    /// ```swift
    /// metadata?.gpsPoints.isEmpty ?? true
    ///
    /// = if let metadata = metadata {
    ///     return metadata.gpsPoints.isEmpty
    /// } else {
    ///     return true  // If metadata is nil, consider "empty"
    /// }
    ///
    /// hasData = !isEmpty  // If not empty, data exists
    /// ```
    ///
    /// ### nil-coalescing operator (??):
    /// ```swift
    /// optional ?? defaultValue
    ///
    /// Example:
    /// metadata?.gpsPoints.isEmpty ?? true
    ///
    /// If metadata is nil:     Return true
    /// If metadata exists:     Return isEmpty value
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// if gpsService.hasData {
    ///     // Display GPS map
    ///     mapView.isHidden = false
    ///     mapView.showRoute()
    /// } else {
    ///     // "No GPS data" message
    ///     mapView.isHidden = true
    ///     showAlert("This video has no GPS data")
    /// }
    /// ```
    ///
    /// ### Conditional UI display:
    /// ```swift
    /// // SwiftUI
    /// if gpsService.hasData {
    ///     MapView(points: gpsService.routePoints)
    /// } else {
    ///     Text("No GPS data")
    ///         .foregroundColor(.gray)
    /// }
    /// ```
    var hasData: Bool {
        // Return false if metadata is nil or gpsPoints is empty
        return !(metadata?.gpsPoints.isEmpty ?? true)
    }

    /// @var pointCount
    /// @brief Number of GPS points
    /// @return Total count of loaded GPS data points
    /// @details
    /// Return total count of loaded GPS data points.
    ///
    /// ### Calculation logic:
    /// ```swift
    /// metadata?.gpsPoints.count ?? 0
    ///
    /// = if let metadata = metadata {
    ///     return metadata.gpsPoints.count
    /// } else {
    ///     return 0  // If metadata is nil, 0 points
    /// }
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// // Display info
    /// Text("GPS data: \(gpsService.pointCount) points")
    ///
    /// // Calculate sampling rate
    /// if let duration = videoDuration {
    ///     let sampleRate = Double(gpsService.pointCount) / duration
    ///     print("GPS sampling: \(sampleRate) Hz")
    ///     // Example: 3600 points / 3600 seconds = 1 Hz (once per second)
    /// }
    ///
    /// // Estimate memory usage
    /// let memoryUsage = gpsService.pointCount * 50  // ~50 bytes per point
    /// print("GPS memory: \(memoryUsage / 1024) KB")
    /// ```
    ///
    /// ### Sampling rate examples:
    /// ```
    /// 1 hour video:
    /// - 3600 points → 1 Hz (once per second)
    /// - 7200 points → 2 Hz (once per 0.5 seconds)
    /// - 1800 points → 0.5 Hz (once per 2 seconds)
    /// ```
    var pointCount: Int {
        // Return 0 if metadata is nil
        return metadata?.gpsPoints.count ?? 0
    }
}

/**
 # GPSService Integration Guide

 ## Map Integration Example:

 ```swift
 import MapKit

 class VideoMapView: UIView, MKMapViewDelegate {
 let gpsService = GPSService()
 let mapView = MKMapView()

 // Load GPS data and initialize map
 func setupMap(with videoFile: VideoFile) {
 // Load GPS data
 gpsService.loadGPSData(
 from: videoFile.metadata,
 startTime: videoFile.timestamp
 )

 guard gpsService.hasData else {
 showNoDataMessage()
 return
 }

 // Display entire route
 drawFullRoute()

 // Set map area (to show entire route)
 zoomToRoute()
 }

 // Draw entire route
 func drawFullRoute() {
 let coordinates = gpsService.routePoints.map {
 CLLocationCoordinate2D(
 latitude: $0.latitude,
 longitude: $0.longitude
 )
 }

 let polyline = MKPolyline(
 coordinates: coordinates,
 count: coordinates.count
 )

 mapView.addOverlay(polyline)
 }

 // Update during playback
 func updateForPlayback(time: TimeInterval) {
 // Current location marker
 if let location = gpsService.getCurrentLocation(at: time) {
 updateMarker(location)
 }

 // Past route vs future route
 let (past, future) = gpsService.getRouteSegments(at: time)
 updateRouteColors(past: past, future: future)

 // Display info
 updateInfoPanel(time: time)
 }

 // Update info panel
 func updateInfoPanel(time: TimeInterval) {
 let distance = gpsService.distanceTraveled(at: time)
 let avgSpeed = gpsService.averageSpeed(at: time) ?? 0

 infoLabel.text = """
 Distance traveled: \(String(format: "%.2f", distance / 1000)) km
 Average speed: \(String(format: "%.1f", avgSpeed)) km/h
 GPS points: \(gpsService.pointCount)
 """
 }
 }
 ```

 ## SwiftUI Example:

 ```swift
 import SwiftUI
 import MapKit

 struct VideoMapView: View {
 @ObservedObject var gpsService: GPSService
 @Binding var currentTime: TimeInterval

 @State private var region = MKCoordinateRegion()

 var body: some View {
 VStack {
 if gpsService.hasData {
 // Map
 Map(coordinateRegion: $region, annotationItems: [gpsService.currentLocation].compactMap { $0 }) { location in
 MapMarker(
 coordinate: CLLocationCoordinate2D(
 latitude: location.latitude,
 longitude: location.longitude
 ),
 tint: .red
 )
 }

 // Info panel
 InfoPanel(
 distance: gpsService.distanceTraveled(at: currentTime),
 avgSpeed: gpsService.averageSpeed(at: currentTime),
 pointCount: gpsService.pointCount
 )
 } else {
 Text("No GPS data")
 .foregroundColor(.gray)
 }
 }
 .onChange(of: currentTime) { _ in
 // Update current location
 _ = gpsService.getCurrentLocation(at: currentTime)
 }
 }
 }

 struct InfoPanel: View {
 let distance: Double
 let avgSpeed: Double?
 let pointCount: Int

 var body: some View {
 HStack(spacing: 20) {
 VStack {
 Text("Distance traveled")
 Text(String(format: "%.2f km", distance / 1000))
 .bold()
 }

 if let speed = avgSpeed {
 VStack {
 Text("Average speed")
 Text(String(format: "%.1f km/h", speed))
 .bold()
 }
 }

 VStack {
 Text("GPS points")
 Text("\(pointCount)")
 .bold()
 }
 }
 .padding()
 .background(Color.black.opacity(0.7))
 .cornerRadius(10)
 }
 }
 ```

 ## Performance Optimization Tips:

 1. **Control update frequency**
 ```swift
 // Don't update too frequently
 var lastUpdateTime: TimeInterval = 0

 func updateIfNeeded(time: TimeInterval) {
 if abs(time - lastUpdateTime) > 0.5 {  // Every 0.5 seconds
 _ = gpsService.getCurrentLocation(at: time)
 lastUpdateTime = time
 }
 }
 ```

 2. **Simplify route (Douglas-Peucker)**
 ```swift
 // Reduce point count for display
 let simplifiedRoute = simplifyRoute(
 gpsService.routePoints,
 tolerance: 0.0001  // About 10m
 )
 ```

 3. **Memory monitoring**
 ```swift
 // For very long videos (10+ hours)
 if gpsService.pointCount > 100000 {
 // Save memory with sampling
 let sampledPoints = samplePoints(gpsService.routePoints, every: 10)
 }
 ```
 */
