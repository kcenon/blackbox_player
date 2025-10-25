/// @file GSensorService.swift
/// @brief Service for managing and querying G-Sensor data synchronized with video playback
/// @author BlackboxPlayer Development Team
/// @details
/// Provides real-time acceleration and impact event information by synchronizing G-Sensor data with video playback time.

/**
 # GSensorService - G-Sensor Data Management Service

 ## 📱 What is a G-Sensor?

 **G-Sensor** is a sensor that measures acceleration (accelerometer).

 ### Meaning of G:
 - **G = Gravitational Acceleration** (Gravity)
 - 1G = 9.8 m/s² (Earth's gravitational acceleration)
 - 2G = 19.6 m/s² (2 times gravity)

 ### Role of G-Sensor:
 ```
 Detect vehicle movement
 ↓
 Measure 3-axis acceleration (X, Y, Z)
 ↓
 Detect impact/sudden braking/rapid acceleration
 ```

 ## 🎯 G-Sensor Usage in Dashcams

 ### 1. Accident Detection
 ```
 Normal:       0.5G ~ 1.5G  (Normal driving)
 Hard Brake:   2.0G ~ 3.0G
 Minor Impact: 3.0G ~ 5.0G
 Severe Impact: > 5.0G
 ```

 ### 2. Automatic Event Recording
 - Impact detected → Automatically save event video
 - Impact while parked → Activate parking surveillance mode

 ### 3. Impact Direction Analysis
 ```
 X-axis: Left/Right (Left ←→ Right)
 Y-axis: Front/Rear (Forward ↑↓ Backward)
 Z-axis: Up/Down (Up ↑↓ Down)

 Example: Rear-end collision
 - Y-axis: -3.0G (Impact from rear)
 - X-axis: 0.1G (No lateral movement)
 - Z-axis: 0.2G (Slightly bounced up)
 ```

 ### 4. Driving Pattern Analysis
 - Frequency of rapid acceleration/braking
 - Frequency of sharp turns
 - Safe driving score

 ## 💡 3-Axis Acceleration Measurement

 ### Coordinate System:
 ```
 Z (Up)
 ↑
 │
 │
 └────→ X (Right)
 ╱
 ╱
 Y (Forward)
 ```

 ### Stationary State:
 ```
 X: 0G (No lateral movement)
 Y: 0G (No forward/backward movement)
 Z: 1G (Gravitational effect)
 ```

 ### Acceleration State:
 ```
 Rapid acceleration:
 - Y: +2.0G (Forward acceleration)

 Hard braking:
 - Y: -3.0G (Pushed backward)

 Right turn:
 - X: +1.5G (Leaning right)
 ```

 ## 🔍 Acceleration Magnitude Calculation

 ### Vector Magnitude:
 ```
 magnitude = √(X² + Y² + Z²)

 Example: X=2.0, Y=1.0, Z=0.5
 magnitude = √(4 + 1 + 0.25)
 = √5.25
 = 2.29 G
 ```

 ### Euclidean Distance:
 The straight-line distance from the origin (0,0,0) to point (X,Y,Z) in 3D space.

 ## 📊 Impact Severity Classification

 ```
 None:        < 1.5G  Normal driving
 Low:    1.5G ~ 2.5G  Speed bump
 Moderate: 2.5G ~ 4.0G  Hard braking, minor contact
 High:   4.0G ~ 6.0G  Medium impact
 Severe:      > 6.0G  Serious accident
 ```

 ## 📚 Usage Examples

 ```swift
 // 1. Create service
 let gsensorService = GSensorService()

 // 2. Load G-Sensor data when loading video
 gsensorService.loadAccelerationData(
 from: videoFile.metadata,
 startTime: videoFile.timestamp
 )

 // 3. Query current acceleration during playback
 if let accel = gsensorService.getCurrentAcceleration(at: currentTime) {
 print("Current acceleration: \(accel.magnitude) G")
 print("Direction: \(accel.primaryDirection)")
 }

 // 4. Find impact events
 let impacts = gsensorService.getImpacts(
 from: 0,
 to: videoDuration,
 minSeverity: .moderate
 )
 print("Impact events: \(impacts.count)")

 // 5. Jump to impact point
 if let nearest = gsensorService.nearestImpact(to: currentTime) {
 seekToTime(nearest.impact.timestamp)
 }
 ```

 ---

 This service provides real-time impact monitoring by synchronizing video playback with G-Sensor data.
 */

import Foundation
import Combine

// MARK: - G-Sensor Service

/// @class GSensorService
/// @brief G-Sensor data management service
/// @details
/// Provides real-time acceleration and impact event information by synchronizing G-Sensor data with video playback time.
///
/// ### Key Features:
/// 1. Load and manage G-Sensor data
/// 2. Query acceleration based on playback time
/// 3. Detect and classify impact events
/// 4. Group impacts by severity/direction
/// 5. Calculate max/average G-force
///
/// ### What is ObservableObject?
/// - Protocol from the Combine framework
/// - Automatically notifies when @Published properties change
/// - SwiftUI Views automatically update
class GSensorService: ObservableObject {

    // MARK: - Published Properties

    /// @var currentAcceleration
    /// @brief Current acceleration data
    /// @details
    /// G-Sensor measurement value corresponding to video playback time.
    ///
    /// ### What is @Published private(set)?
    /// - **@Published**: Automatically updates View when value changes
    /// - **private(set)**: External read-only, writable only within this class
    ///
    /// ### Reason:
    /// ```swift
    /// // From outside:
    /// let accel = gsensorService.currentAcceleration  // OK (read)
    /// gsensorService.currentAcceleration = ...        // Compile error (cannot write)
    ///
    /// // From inside (this class):
    /// self.currentAcceleration = newData              // OK (can write)
    /// ```
    ///
    /// ### What is AccelerationData?
    /// ```swift
    /// struct AccelerationData {
    ///     let x: Double              // X-axis acceleration (left/right)
    ///     let y: Double              // Y-axis acceleration (front/back)
    ///     let z: Double              // Z-axis acceleration (up/down)
    ///     let magnitude: Double      // Acceleration magnitude (√(x²+y²+z²))
    ///     let timestamp: Date        // Measurement time
    ///     let isImpact: Bool         // Whether it's an impact event
    ///     let impactSeverity: ImpactSeverity    // Impact severity
    ///     let primaryDirection: ImpactDirection  // Primary impact direction
    /// }
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// if let accel = gsensorService.currentAcceleration {
    ///     print("X: \(accel.x)G, Y: \(accel.y)G, Z: \(accel.z)G")
    ///     print("Magnitude: \(accel.magnitude)G")
    ///
    ///     if accel.isImpact {
    ///         print("⚠️ Impact detected! Severity: \(accel.impactSeverity)")
    ///     }
    /// }
    /// ```
    @Published private(set) var currentAcceleration: AccelerationData?

    /// @var allData
    /// @brief All acceleration data
    /// @details
    /// Array of all G-Sensor measurement values included in the video.
    ///
    /// ### Purpose:
    /// - Analyze overall driving patterns
    /// - Graph visualization (acceleration vs time)
    /// - Calculate statistics (max/average/standard deviation)
    ///
    /// ### Data Rate:
    /// ```
    /// Dashcam G-Sensors typically:
    /// - 10Hz (once per 0.1 seconds)
    /// - 50Hz (once per 0.02 seconds)
    /// - 100Hz (once per 0.01 seconds)
    ///
    /// 1-hour video (10Hz):
    /// - 3,600 seconds × 10 = 36,000 data points
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// // Draw graph
    /// for data in gsensorService.allData {
    ///     chartView.addPoint(
    ///         x: data.timestamp,
    ///         y: data.magnitude
    ///     )
    /// }
    ///
    /// // Calculate statistics
    /// let magnitudes = gsensorService.allData.map { $0.magnitude }
    /// let average = magnitudes.reduce(0, +) / Double(magnitudes.count)
    /// let max = magnitudes.max() ?? 0
    /// ```
    @Published private(set) var allData: [AccelerationData] = []

    /// @var impactEvents
    /// @brief Impact events list
    /// @details
    /// Events classified as impacts from all data.
    ///
    /// ### Impact Detection Criteria:
    /// ```
    /// magnitude > 1.5G  →  Classified as impact
    ///
    /// Example:
    /// - 1.0G: Normal driving → Not an impact
    /// - 2.0G: Speed bump → Impact (Low)
    /// - 4.5G: Hard braking → Impact (High)
    /// ```
    ///
    /// ### Filtering logic:
    /// ```swift
    /// allData.filter { $0.isImpact }
    ///
    /// = Extract only data where isImpact == true from allData
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// // Display impact markers
    /// for impact in gsensorService.impactEvents {
    ///     timelineView.addMarker(
    ///         at: impact.timestamp,
    ///         color: severityColor(impact.impactSeverity),
    ///         icon: .warning
    ///     )
    /// }
    ///
    /// // Impact list UI
    /// List(gsensorService.impactEvents) { impact in
    ///     HStack {
    ///         Image(systemName: "exclamationmark.triangle")
    ///         Text(impact.impactSeverity.displayName)
    ///         Text("\(impact.magnitude, specifier: "%.2f")G")
    ///     }
    /// }
    /// ```
    @Published private(set) var impactEvents: [AccelerationData] = []

    /// @var currentGForce
    /// @brief Current G-force magnitude
    /// @details
    /// Acceleration magnitude at current time point.
    ///
    /// ### What is G-force?
    /// - G-force = Acceleration relative to gravity
    /// - 1G = Earth's gravity (9.8 m/s²)
    /// - 2G = 2 times gravity acceleration
    ///
    /// ### How it feels:
    /// ```
    /// 1.0G: Normal (sitting still feeling)
    /// 2.0G: Speed bump (slight jolt)
    /// 3.0G: Hard braking (pushed forward)
    /// 5.0G: Collision (strong impact)
    /// 10.0G: Severe accident (life threatening)
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// // Display real-time gauge
    /// CircularGauge(
    ///     value: gsensorService.currentGForce,
    ///     minimum: 0,
    ///     maximum: 5,
    ///     warningThreshold: 2.0,
    ///     dangerThreshold: 4.0
    /// )
    ///
    /// // Color change
    /// let color = gsensorService.currentGForce > 3.0 ? .red :
    ///             gsensorService.currentGForce > 1.5 ? .orange : .green
    /// ```
    @Published private(set) var currentGForce: Double = 0.0

    /// @var peakGForce
    /// @brief Maximum G-force (peak)
    /// @details
    /// Maximum acceleration magnitude recorded during current session.
    ///
    /// ### Calculation time:
    /// - Calculate maximum value from all data when loading data
    /// - Magnitude of largest impact in entire video
    ///
    /// ### Purpose:
    /// ```swift
    /// // Display summary information
    /// Text("Maximum impact: \(gsensorService.peakGForce, specifier: "%.2f")G")
    ///
    /// // Danger warning
    /// if gsensorService.peakGForce > 5.0 {
    ///     Text("⚠️ Severe impact recorded")
    ///         .foregroundColor(.red)
    /// }
    ///
    /// // Adjust gauge range
    /// let maxScale = max(5.0, gsensorService.peakGForce + 1.0)
    /// CircularGauge(value: current, maximum: maxScale)
    /// ```
    ///
    /// ### Examples:
    /// ```
    /// Video A: peakGForce = 2.1G (Speed bump)
    /// Video B: peakGForce = 6.5G (Accident occurred)
    /// ```
    @Published private(set) var peakGForce: Double = 0.0

    // MARK: - Private Properties

    /// @var metadata
    /// @brief Video metadata
    /// @details
    /// All metadata of the video containing G-Sensor data.
    ///
    /// ### What is VideoMetadata?
    /// ```swift
    /// struct VideoMetadata {
    ///     let accelerationData: [AccelerationData]  // G-Sensor measurements
    ///     let gpsPoints: [GPSPoint]                 // GPS coordinate array
    ///     let summary: MetadataSummary              // Summary information
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
    /// G-Sensor measurement: 2024-10-12 15:00:05
    ///
    /// Offset = G-Sensor time - video start
    ///        = 15:00:05 - 15:00:00
    ///        = 5 seconds
    ///
    /// → Display G-Sensor data at 5 seconds of video playback
    /// ```
    ///
    /// ### What is Date?
    /// - Date/time type from Foundation
    /// - Represents absolute time (based on Unix Epoch 1970-01-01 00:00:00 UTC)
    /// - timeIntervalSince(_:) method calculates time difference
    private var videoStartTime: Date?

    // MARK: - Public Methods

    /// @brief Load G-Sensor data
    /// @param metadata Video metadata containing G-Sensor data
    /// @param startTime Video recording start time
    /// @details
    /// Extract G-Sensor data from VideoMetadata and load it into the service.
    ///
    /// ### When to Call:
    /// ```swift
    /// // Right after loading video file:
    /// func loadVideo(_ file: VideoFile) {
    ///     // ... video decoder setup
    ///
    ///     gsensorService.loadAccelerationData(
    ///         from: file.metadata,
    ///         startTime: file.timestamp
    ///     )
    ///
    ///     // ... G-Sensor UI update
    /// }
    /// ```
    ///
    /// ### Processing Steps:
    /// ```
    /// 1. Save metadata (containing G-Sensor data)
    /// 2. Save videoStartTime (for time offset calculation)
    /// 3. Set allData (@Published → UI automatically updates)
    /// 4. Filter impactEvents (impacts only)
    /// 5. Calculate peakGForce (maximum value)
    /// 6. Log
    /// ```
    ///
    /// ### Impact filtering:
    /// ```swift
    /// metadata.accelerationData.filter { $0.isImpact }
    ///
    /// = Extract only data where isImpact == true from accelerationData
    /// ```
    ///
    /// ### Maximum value calculation:
    /// ```swift
    /// metadata.accelerationData.map { $0.magnitude }.max() ?? 0.0
    ///
    /// Steps:
    /// 1. map { $0.magnitude }: Extract only magnitudes from all data
    ///    → [1.0, 2.5, 3.2, 1.8, ...]
    /// 2. .max(): Find maximum value from array
    ///    → 3.2
    /// 3. ?? 0.0: Use 0.0 if nil (when no data)
    /// ```
    ///
    /// ### Memory Impact:
    /// - 1 acceleration point ≈ 60 bytes
    /// - 1 hour video (3600 seconds, 10Hz G-Sensor) ≈ 2.2 MB
    /// - Can be safely stored in memory
    func loadAccelerationData(from metadata: VideoMetadata, startTime: Date) {
        // ===== Step 1: Save metadata =====
        self.metadata = metadata
        self.videoStartTime = startTime

        // ===== Step 2: Set all data =====
        self.allData = metadata.accelerationData

        // ===== Step 3: Filter impact events =====
        // Extract only data where isImpact == true
        self.impactEvents = metadata.accelerationData.filter { $0.isImpact }

        // ===== Step 4: Calculate maximum G-force =====
        // Largest magnitude among all data
        self.peakGForce = metadata.accelerationData.map { $0.magnitude }.max() ?? 0.0

        // ===== Step 5: Log =====
        infoLog("[GSensorService] Loaded G-Sensor data: \(metadata.accelerationData.count) points, \(impactEvents.count) impacts")
    }

    /// @brief Query acceleration data at specific time
    /// @param time Video playback time (in seconds, elapsed from video start)
    /// @return Acceleration data at corresponding time, or nil if none
    /// @details
    /// Return G-Sensor measurement corresponding to video playback time.
    ///
    /// ### Time Matching Method:
    ///
    /// 1. **When exact G-Sensor point exists:**
    /// ```
    /// G-Sensor data: [0.0s, 0.1s, 0.2s, 0.3s, ...]
    /// Playback time: 0.2s
    /// → Return G-Sensor point at 0.2s
    /// ```
    ///
    /// 2. **Intermediate time (interpolation):**
    /// ```
    /// G-Sensor data: 0.2s(x=1.0, y=0.5), 0.3s(x=1.2, y=0.6)
    /// Playback time: 0.25s
    ///
    /// Linear interpolation:
    /// x = 1.0 + (1.2 - 1.0) × 0.5 = 1.1
    /// y = 0.5 + (0.6 - 0.5) × 0.5 = 0.55
    ///
    /// → AccelerationData(x=1.1, y=0.55, ...)
    /// ```
    ///
    /// 3. **When no G-Sensor data:**
    /// ```
    /// metadata == nil → Return nil
    /// ```
    ///
    /// ### What is weak self?
    /// ```swift
    /// DispatchQueue.main.async { [weak self] in
    ///     self?.currentAcceleration = acceleration
    /// }
    /// ```
    ///
    /// - **weak**: Weak reference (prevents memory leak)
    /// - **self?**: self can be nil (Optional)
    ///
    /// **Why is it needed?**
    /// ```
    /// GSensorService is released
    ///   ↓
    /// But closure is still waiting to execute
    ///   ↓
    /// Thanks to weak self, self becomes nil
    ///   ↓
    /// self?.currentAcceleration → safely ignored
    /// ```
    ///
    /// **If it were strong reference:**
    /// ```
    /// Attempting to release GSensorService
    ///   ↓
    /// Closure holds strong self
    ///   ↓
    /// GSensorService remains in memory (memory leak!)
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
    /// Change currentAcceleration
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
    ///     if let accel = gsensorService.getCurrentAcceleration(at: time) {
    ///         // Update G-force gauge
    ///         gforceGauge.value = accel.magnitude
    ///
    ///         // Impact warning
    ///         if accel.isImpact {
    ///             showImpactWarning(accel)
    ///         }
    ///
    ///         // Update 3-axis graph
    ///         xAxisChart.addPoint(accel.x)
    ///         yAxisChart.addPoint(accel.y)
    ///         zAxisChart.addPoint(accel.z)
    ///     }
    /// }
    /// ```
    func getCurrentAcceleration(at time: TimeInterval) -> AccelerationData? {
        // ===== Step 1: Check metadata =====
        guard let metadata = metadata else {
            return nil
        }

        // ===== Step 2: Query acceleration data based on time =====
        // VideoMetadata.accelerationData(at:) handles interpolation
        let acceleration = metadata.accelerationData(at: time)

        // ===== Step 3: Update Published properties (main thread) =====
        DispatchQueue.main.async { [weak self] in
            self?.currentAcceleration = acceleration
            self?.currentGForce = acceleration?.magnitude ?? 0.0
        }

        return acceleration
    }

    /// @brief Query acceleration data within time range
    /// @param startTime Start time (in seconds)
    /// @param endTime End time (in seconds)
    /// @return Array of acceleration data in corresponding time range
    /// @details
    /// Return all G-Sensor measurements in a specific time range.
    ///
    /// ### Usage Example:
    ///
    /// 1. **Analyze segment:**
    /// ```swift
    /// // Analyze 10 seconds before and after impact
    /// let impactTime = 30.0
    /// let data = gsensorService.getData(from: impactTime - 10, to: impactTime + 10)
    /// analyzeAccelerationPattern(data)
    /// ```
    ///
    /// 2. **Draw segment graph:**
    /// ```swift
    /// // Draw graph for specific segment
    /// let data = gsensorService.getData(from: 60, to: 120)
    /// for point in data {
    ///     chart.addPoint(x: point.timestamp, y: point.magnitude)
    /// }
    /// ```
    ///
    /// 3. **Event search:**
    /// ```swift
    /// // Maximum acceleration between 2min~3min
    /// let data = gsensorService.getData(from: 120, to: 180)
    /// let maxAccel = data.map { $0.magnitude }.max() ?? 0
    /// ```
    ///
    /// ### Filtering logic:
    /// ```swift
    /// metadata.accelerationData.filter { data in
    ///     let offset = data.timestamp.timeIntervalSince(videoStart)
    ///     return offset >= startTime && offset <= endTime
    /// }
    /// ```
    ///
    /// **Step-by-step explanation:**
    /// ```
    /// 1. data.timestamp: G-Sensor measurement absolute time
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
    /// - O(n) time complexity (n = number of G-Sensor points)
    /// - 1 hour video (36000 points) → very fast
    /// - Memory efficient (only filtering)
    func getData(from startTime: TimeInterval, to endTime: TimeInterval) -> [AccelerationData] {
        // ===== Step 1: Check data =====
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return []
        }

        // ===== Step 2: Filter by time range =====
        return metadata.accelerationData.filter { data in
            let offset = data.timestamp.timeIntervalSince(videoStart)
            return offset >= startTime && offset <= endTime
        }
    }

    /// @brief Query impact events within time range
    /// @param startTime Start time (in seconds)
    /// @param endTime End time (in seconds)
    /// @param minSeverity Minimum severity (default: .moderate)
    /// @return Array of filtered impact events
    /// @details
    /// Return impact events in specific time range filtered by severity.
    ///
    /// ### Filtering logic:
    /// ```
    /// 1. Time range filtering: startTime <= offset <= endTime
    /// 2. Severity filtering: severityLevel >= minSeverity
    /// ```
    ///
    /// ### severityLevel function:
    /// ```swift
    /// enum ImpactSeverity {
    ///     case none     // 0
    ///     case low      // 1
    ///     case moderate // 2
    ///     case high     // 3
    ///     case severe   // 4
    /// }
    ///
    /// severityLevel(impact.impactSeverity) >= severityLevel(minSeverity)
    ///
    /// Example: minSeverity = .moderate (2)
    /// - low (1) >= 2 → ❌ exclude
    /// - moderate (2) >= 2 → ✅ include
    /// - high (3) >= 2 → ✅ include
    /// - severe (4) >= 2 → ✅ include
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// // 1. Query only severe impacts
    /// let severeImpacts = gsensorService.getImpacts(
    ///     from: 0,
    ///     to: videoDuration,
    ///     minSeverity: .high
    /// )
    ///
    /// // 2. All impacts between 1min~2min
    /// let impacts = gsensorService.getImpacts(
    ///     from: 60,
    ///     to: 120,
    ///     minSeverity: .low
    /// )
    ///
    /// // 3. Impact list UI
    /// ForEach(impacts) { impact in
    ///     ImpactRow(
    ///         time: impact.timestamp,
    ///         severity: impact.impactSeverity,
    ///         direction: impact.primaryDirection,
    ///         magnitude: impact.magnitude
    ///     )
    /// }
    /// ```
    func getImpacts(
        from startTime: TimeInterval,
        to endTime: TimeInterval,
        minSeverity: ImpactSeverity = .moderate
    ) -> [AccelerationData] {
        // ===== Step 1: Check data =====
        guard let videoStart = videoStartTime else {
            return []
        }

        // ===== Step 2: Filter by time and severity =====
        return impactEvents.filter { impact in
            // Calculate time offset
            let offset = impact.timestamp.timeIntervalSince(videoStart)

            // Check conditions:
            // 1. Within time range
            // 2. severity >= minSeverity
            return offset >= startTime && offset <= endTime &&
                severityLevel(impact.impactSeverity) >= severityLevel(minSeverity)
        }
    }

    /// @brief Maximum G-force within time range
    /// @param startTime Start time (in seconds)
    /// @param endTime End time (in seconds)
    /// @return Maximum G-force magnitude
    /// @details
    /// Return maximum acceleration magnitude in a specific segment.
    ///
    /// ### Calculation Process:
    /// ```
    /// 1. Call getData(from:to:) → Get segment data
    /// 2. map { $0.magnitude } → Extract only magnitudes
    /// 3. max() → Find maximum value
    /// 4. ?? 0.0 → Use 0.0 if no data
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// // 1. Maximum acceleration by segment
    /// let max1min = gsensorService.maxGForce(from: 0, to: 60)
    /// let max2min = gsensorService.maxGForce(from: 60, to: 120)
    ///
    /// // 2. Compare before and after impact
    /// let impactTime = 30.0
    /// let beforeMax = gsensorService.maxGForce(from: impactTime - 5, to: impactTime)
    /// let afterMax = gsensorService.maxGForce(from: impactTime, to: impactTime + 5)
    ///
    /// // 3. Determine graph scale
    /// let maxInView = gsensorService.maxGForce(from: viewStartTime, to: viewEndTime)
    /// chart.yAxisMax = maxInView + 1.0
    /// ```
    func maxGForce(from startTime: TimeInterval, to endTime: TimeInterval) -> Double {
        // Get segment data
        let data = getData(from: startTime, to: endTime)

        // Extract magnitudes and return maximum value
        return data.map { $0.magnitude }.max() ?? 0.0
    }

    /// @brief Average G-force within time range
    /// @param startTime Start time (in seconds)
    /// @param endTime End time (in seconds)
    /// @return Average G-force magnitude
    /// @details
    /// Return average acceleration magnitude in a specific segment.
    ///
    /// ### Calculation Process:
    /// ```
    /// 1. getData(from:to:) → Get segment data
    /// 2. map { $0.magnitude } → magnitude array
    /// 3. reduce(0, +) → Sum all
    /// 4. / count → Divide by count
    /// ```
    ///
    /// ### Example calculation:
    /// ```
    /// data magnitudes = [1.0, 2.0, 1.5, 3.0, 2.5]
    ///
    /// total = 1.0 + 2.0 + 1.5 + 3.0 + 2.5 = 10.0
    /// average = 10.0 / 5 = 2.0G
    /// ```
    ///
    /// ### What is reduce?
    ///
    /// Reduce all elements of array to a single value.
    ///
    /// ```swift
    /// magnitudes.reduce(0, +)
    ///
    /// = magnitudes.reduce(0) { total, magnitude in
    ///     return total + magnitude
    /// }
    /// ```
    ///
    /// **Step-by-step execution:**
    /// ```
    /// magnitudes = [1.0, 2.0, 1.5]
    ///
    /// Initial value = 0
    /// Step 1: 0 + 1.0 = 1.0
    /// Step 2: 1.0 + 2.0 = 3.0
    /// Step 3: 3.0 + 1.5 = 4.5
    /// Final = 4.5
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// // 1. Average acceleration for traveled segment
    /// let avgNormal = gsensorService.averageGForce(from: 0, to: 600)  // 10 minutes
    ///
    /// // 2. Compare before and after impact
    /// let avgBefore = gsensorService.averageGForce(from: 20, to: 30)
    /// let avgImpact = gsensorService.averageGForce(from: 30, to: 40)
    ///
    /// // 3. Safe driving score
    /// let avgGforce = gsensorService.averageGForce(from: 0, to: duration)
    /// let safetyScore = calculateSafetyScore(avgGforce)
    /// // Lower is safer driving
    /// ```
    func averageGForce(from startTime: TimeInterval, to endTime: TimeInterval) -> Double {
        // ===== Step 1: Get segment data =====
        let data = getData(from: startTime, to: endTime)

        // ===== Step 2: Return 0.0 if no data =====
        guard !data.isEmpty else { return 0.0 }

        // ===== Step 3: Calculate average =====
        // Sum all magnitudes
        let total = data.map { $0.magnitude }.reduce(0, +)

        // Divide by count and return average
        return total / Double(data.count)
    }

    /// @brief Group impact events by severity
    /// @return Dictionary of impact events grouped by severity
    /// @details
    /// Return dictionary that classifies all impact events by severity (ImpactSeverity).
    ///
    /// ### Return format:
    /// ```swift
    /// [ImpactSeverity: [AccelerationData]]
    ///
    /// Example:
    /// {
    ///     .low: [impact1, impact2],
    ///     .moderate: [impact3, impact4, impact5],
    ///     .high: [impact6],
    ///     .severe: []
    /// }
    /// ```
    ///
    /// ### Grouping logic:
    /// ```
    /// for impact in impactEvents {
    ///     severity = impact.impactSeverity
    ///
    ///     if grouped[severity] == nil {
    ///         grouped[severity] = []  // Create empty array
    ///     }
    ///
    ///     grouped[severity]?.append(impact)  // Add
    /// }
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// // 1. Count by severity
    /// let grouped = gsensorService.impactsBySeverity()
    ///
    /// print("Minor: \(grouped[.low]?.count ?? 0) events")
    /// print("Moderate: \(grouped[.moderate]?.count ?? 0) events")
    /// print("High: \(grouped[.high]?.count ?? 0) events")
    /// print("Severe: \(grouped[.severe]?.count ?? 0) events")
    ///
    /// // 2. UI by section
    /// ForEach(ImpactSeverity.allCases) { severity in
    ///     Section(header: Text(severity.displayName)) {
    ///         ForEach(grouped[severity] ?? []) { impact in
    ///             ImpactRow(impact: impact)
    ///         }
    ///     }
    /// }
    ///
    /// // 3. Statistics chart
    /// PieChart(data: [
    ///     ("Low", grouped[.low]?.count ?? 0),
    ///     ("Moderate", grouped[.moderate]?.count ?? 0),
    ///     ("High", grouped[.high]?.count ?? 0),
    ///     ("Severe", grouped[.severe]?.count ?? 0)
    /// ])
    /// ```
    func impactsBySeverity() -> [ImpactSeverity: [AccelerationData]] {
        // Create empty dictionary
        var grouped: [ImpactSeverity: [AccelerationData]] = [:]

        // Iterate all impact events
        for impact in impactEvents {
            let severity = impact.impactSeverity

            // Create empty array if severity key doesn't exist
            if grouped[severity] == nil {
                grouped[severity] = []
            }

            // Add impact event
            grouped[severity]?.append(impact)
        }

        return grouped
    }

    /// @brief Group impact events by direction
    /// @return Dictionary of impact events grouped by direction
    /// @details
    /// Return dictionary that classifies all impact events by impact direction (ImpactDirection).
    ///
    /// ### ImpactDirection:
    /// ```swift
    /// enum ImpactDirection {
    ///     case front      // Front impact (Hard braking)
    ///     case rear       // Rear impact (Collision from behind)
    ///     case left       // Left impact
    ///     case right      // Right impact
    ///     case top        // Top impact (Falling object from above)
    ///     case bottom     // Bottom impact (Speed bump)
    ///     case multiple   // Multiple directions
    /// }
    /// ```
    ///
    /// ### Return format:
    /// ```swift
    /// [ImpactDirection: [AccelerationData]]
    ///
    /// Example:
    /// {
    ///     .front: [impact1, impact2, impact3],
    ///     .rear: [impact4],
    ///     .left: [],
    ///     .right: [impact5, impact6],
    ///     ...
    /// }
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// // 1. Count by direction
    /// let grouped = gsensorService.impactsByDirection()
    ///
    /// print("Front: \(grouped[.front]?.count ?? 0) events")
    /// print("Rear: \(grouped[.rear]?.count ?? 0) events")
    /// print("Left: \(grouped[.left]?.count ?? 0) events")
    /// print("Right: \(grouped[.right]?.count ?? 0) events")
    ///
    /// // 2. Display direction arrows
    /// for (direction, impacts) in grouped {
    ///     let arrow = directionArrow(direction)
    ///     Text("\(arrow) \(impacts.count) events")
    /// }
    ///
    /// // 3. Accident pattern analysis
    /// let rearImpacts = grouped[.rear]?.count ?? 0
    /// if rearImpacts > 0 {
    ///     Text("⚠️ Rear impact detected: Possible rear-end collision")
    /// }
    /// ```
    func impactsByDirection() -> [ImpactDirection: [AccelerationData]] {
        // Create empty dictionary
        var grouped: [ImpactDirection: [AccelerationData]] = [:]

        // Iterate all impact events
        for impact in impactEvents {
            let direction = impact.primaryDirection

            // Create empty array if direction key doesn't exist
            if grouped[direction] == nil {
                grouped[direction] = []
            }

            // Add impact event
            grouped[direction]?.append(impact)
        }

        return grouped
    }

    /// @brief Check if significant acceleration exists at current time
    /// @param time Playback time (in seconds)
    /// @return Whether significant acceleration exists (true/false)
    /// @details
    /// Check if acceleration at current time point exceeds threshold (1.5G).
    ///
    /// ### Determination criteria:
    /// ```
    /// isSignificant = magnitude > 1.5G
    ///
    /// Example:
    /// - 1.0G → false (normal)
    /// - 1.8G → true (significant)
    /// - 3.0G → true (impact)
    /// ```
    ///
    /// ### AccelerationData.isSignificant:
    /// ```swift
    /// var isSignificant: Bool {
    ///     return magnitude > 1.5
    /// }
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// // 1. Display warning
    /// if gsensorService.hasSignificantAcceleration(at: currentTime) {
    ///     warningIcon.isHidden = false
    ///     warningIcon.startAnimating()
    /// }
    ///
    /// // 2. Event marker
    /// if gsensorService.hasSignificantAcceleration(at: time) {
    ///     timeline.addMarker(at: time, color: .orange)
    /// }
    ///
    /// // 3. Statistics
    /// var significantCount = 0
    /// for time in stride(from: 0, to: duration, by: 1.0) {
    ///     if gsensorService.hasSignificantAcceleration(at: time) {
    ///         significantCount += 1
    ///     }
    /// }
    /// print("Significant acceleration points: \(significantCount) seconds")
    /// ```
    func hasSignificantAcceleration(at time: TimeInterval) -> Bool {
        // Get acceleration data at current time
        guard let acceleration = getCurrentAcceleration(at: time) else {
            return false
        }

        // Check isSignificant property (magnitude > 1.5G)
        return acceleration.isSignificant
    }

    /// @brief Find nearest impact event to specified time
    /// @param time Target time (in seconds)
    /// @return (impact event, time difference) tuple, or nil if no impacts
    /// @details
    /// Return the nearest impact event from the given time and its time difference.
    ///
    /// ### Algorithm:
    /// ```
    /// 1. Calculate time offset for all impact events
    /// 2. Calculate difference (absolute value) from target time
    /// 3. Select one with smallest difference
    /// ```
    ///
    /// ### Example:
    /// ```
    /// Impact events: [10s, 25s, 50s, 75s]
    /// Target time: 30s
    ///
    /// Calculate differences:
    /// - 10s: |10 - 30| = 20s
    /// - 25s: |25 - 30| = 5s  ← minimum
    /// - 50s: |50 - 30| = 20s
    /// - 75s: |75 - 30| = 45s
    ///
    /// Result: 25s impact event (difference 5s)
    /// ```
    ///
    /// ### Using map:
    /// ```swift
    /// impactEvents.map { impact -> (AccelerationData, TimeInterval) in
    ///     let offset = impact.timestamp.timeIntervalSince(videoStart)
    ///     return (impact, abs(offset - time))
    /// }
    ///
    /// = Convert each impact event to (impact data, time difference) tuple
    /// ```
    ///
    /// ### Using min(by:):
    /// ```swift
    /// .min(by: { $0.1 < $1.1 })
    ///
    /// = Compare second element of tuple ($0.1, $1.1 = time difference) to find minimum value
    /// ```
    ///
    /// ### What is tuple?
    /// ```swift
    /// // Return multiple values bundled together
    /// let result = nearestImpact(to: 30)
    ///
    /// // Access method 1: tuple label
    /// let impact = result.impact
    /// let offset = result.offset
    ///
    /// // Access method 2: Destructuring
    /// let (impact, offset) = nearestImpact(to: 30)
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// // 1. "Jump to nearest impact" button
    /// Button("Jump to impact point") {
    ///     if let (impact, offset) = gsensorService.nearestImpact(to: currentTime) {
    ///         let impactTime = impact.timestamp.timeIntervalSince(videoStart)
    ///         seekToTime(impactTime)
    ///     }
    /// }
    ///
    /// // 2. Display impact time
    /// if let (impact, offset) = gsensorService.nearestImpact(to: currentTime) {
    ///     Text("Nearest impact: \(offset, specifier: "%.1f")s \(offset > 0 ? "ahead" : "behind")")
    /// }
    ///
    /// // 3. Auto playback
    /// func autoPlayImpacts() {
    ///     if let (impact, _) = gsensorService.nearestImpact(to: currentTime) {
    ///         seekTo(impact.timestamp)
    ///         Timer.scheduledTimer(withTimeInterval: 10.0) { _ in
    ///             autoPlayImpacts()  // Go to next impact
    ///         }
    ///     }
    /// }
    /// ```
    func nearestImpact(to time: TimeInterval) -> (impact: AccelerationData, offset: TimeInterval)? {
        // ===== Step 1: Check data =====
        guard let videoStart = videoStartTime,
              !impactEvents.isEmpty else {
            return nil
        }

        // ===== Step 2: Calculate difference between each impact event and target time =====
        let impactsWithOffsets = impactEvents.map { impact -> (AccelerationData, TimeInterval) in
            // Impact occurrence time (offset from video start)
            let offset = impact.timestamp.timeIntervalSince(videoStart)

            // Difference from target time (absolute value)
            let difference = abs(offset - time)

            return (impact, difference)
        }

        // ===== Step 3: Find one with smallest difference =====
        // min(by:): Select minimum value using comparison function
        // $0.1, $1.1: Second element of tuple (TimeInterval = difference)
        guard let nearest = impactsWithOffsets.min(by: { $0.1 < $1.1 }) else {
            return nil
        }

        return nearest
    }

    /// @brief Clear G-Sensor data
    /// @details
    /// Remove all G-Sensor data from memory and return to initial state.
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
    ///     gsensorService.clear()  // Remove previous data
    ///     gsensorService.loadAccelerationData(from: file.metadata, startTime: file.timestamp)
    /// }
    /// ```
    ///
    /// 3. **Memory cleanup:**
    /// ```swift
    /// func didReceiveMemoryWarning() {
    ///     if !isPlaying {
    ///         gsensorService.clear()
    ///     }
    /// }
    /// ```
    ///
    /// ### What is cleared:
    /// - metadata: All metadata (nil)
    /// - videoStartTime: Start time (nil)
    /// - allData: All acceleration data (empty array)
    /// - impactEvents: Impact events list (empty array)
    /// - currentAcceleration: Current acceleration (nil)
    /// - currentGForce: Current G-force (0.0)
    /// - peakGForce: Maximum G-force (0.0)
    ///
    /// ### Effect on @Published properties:
    /// ```
    /// clear() called
    ///   ↓
    /// allData = []
    ///   ↓
    /// @Published detected
    ///   ↓
    /// SwiftUI View automatically updates
    ///   ↓
    /// Data disappears from graph/gauge
    /// ```
    func clear() {
        // ===== Reset all data =====
        metadata = nil
        videoStartTime = nil
        allData = []                  // @Published → UI update
        impactEvents = []             // @Published → UI update
        currentAcceleration = nil     // @Published → UI update
        currentGForce = 0.0           // @Published → UI update
        peakGForce = 0.0              // @Published → UI update

        // ===== Log =====
        debugLog("[GSensorService] G-Sensor data cleared")
    }

    // MARK: - Computed Properties

    /// @var hasData
    /// @brief Whether G-Sensor data exists
    /// @return true if G-Sensor data exists, false if none
    /// @details
    /// Check if G-Sensor data is loaded and has at least 1 measurement.
    ///
    /// ### Calculation logic:
    /// ```swift
    /// metadata?.accelerationData.isEmpty ?? true
    ///
    /// = if let metadata = metadata {
    ///     return metadata.accelerationData.isEmpty
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
    /// metadata?.accelerationData.isEmpty ?? true
    ///
    /// If metadata is nil:     Return true
    /// If metadata exists:     Return isEmpty value
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// if gsensorService.hasData {
    ///     // Display G-Sensor graph
    ///     chartView.isHidden = false
    ///     chartView.showGraph()
    /// } else {
    ///     // "No G-Sensor data" message
    ///     chartView.isHidden = true
    ///     showAlert("This video has no G-Sensor data")
    /// }
    /// ```
    var hasData: Bool {
        // Return false if metadata is nil or accelerationData is empty
        return !(metadata?.accelerationData.isEmpty ?? true)
    }

    /// @var dataPointCount
    /// @brief Number of data points
    /// @return Total count of loaded G-Sensor data points
    /// @details
    /// Return total count of loaded G-Sensor measurements.
    ///
    /// ### Calculation logic:
    /// ```swift
    /// metadata?.accelerationData.count ?? 0
    ///
    /// = if let metadata = metadata {
    ///     return metadata.accelerationData.count
    /// } else {
    ///     return 0  // If metadata is nil, 0 points
    /// }
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// // Display info
    /// Text("G-Sensor data: \(gsensorService.dataPointCount) points")
    ///
    /// // Calculate sampling rate
    /// if let duration = videoDuration {
    ///     let sampleRate = Double(gsensorService.dataPointCount) / duration
    ///     print("G-Sensor sampling: \(sampleRate) Hz")
    ///     // Example: 36000 points / 3600 seconds = 10 Hz (once per 0.1 seconds)
    /// }
    ///
    /// // Estimate memory usage
    /// let memoryUsage = gsensorService.dataPointCount * 60  // ~60 bytes per point
    /// print("G-Sensor memory: \(memoryUsage / 1024) KB")
    /// ```
    ///
    /// ### Sampling rate examples:
    /// ```
    /// 1 hour video:
    /// - 36000 points → 10 Hz (once per 0.1 seconds)
    /// - 180000 points → 50 Hz (once per 0.02 seconds)
    /// - 360000 points → 100 Hz (once per 0.01 seconds)
    /// ```
    var dataPointCount: Int {
        // Return 0 if metadata is nil
        return metadata?.accelerationData.count ?? 0
    }

    /// @var impactCount
    /// @brief Number of impact events
    /// @return Total count of detected impact events
    /// @details
    /// Return total count of detected impact events.
    ///
    /// ### Usage Example:
    /// ```swift
    /// // Display impact count
    /// Text("Impacts detected: \(gsensorService.impactCount) events")
    ///
    /// // Conditional UI
    /// if gsensorService.impactCount > 0 {
    ///     ImpactListView(impacts: gsensorService.impactEvents)
    /// } else {
    ///     Text("No impact events")
    ///         .foregroundColor(.gray)
    /// }
    ///
    /// // Risk level
    /// let riskLevel = gsensorService.impactCount > 10 ? "High" :
    ///                 gsensorService.impactCount > 5 ? "Medium" : "Low"
    /// ```
    var impactCount: Int {
        return impactEvents.count
    }

    // MARK: - Private Helpers

    /// @brief Convert severity to comparable level
    /// @param severity Severity enum
    /// @return Integer level (0~4)
    /// @details
    /// Convert ImpactSeverity enum to integer for magnitude comparison.
    ///
    /// ### Conversion table:
    /// ```
    /// .none     → 0
    /// .low      → 1
    /// .moderate → 2
    /// .high     → 3
    /// .severe   → 4
    /// ```
    ///
    /// ### Usage Example:
    /// ```swift
    /// severityLevel(.high) >= severityLevel(.moderate)
    /// → 3 >= 2
    /// → true
    ///
    /// severityLevel(.low) >= severityLevel(.moderate)
    /// → 1 >= 2
    /// → false
    /// ```
    ///
    /// ### Why is it needed?
    /// ```swift
    /// // Cannot compare enum directly
    /// if impact.impactSeverity >= .moderate  // Compile error!
    ///
    /// // Can compare when converted to integer
    /// if severityLevel(impact.impactSeverity) >= severityLevel(.moderate)  // OK
    /// ```
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

/**
 # GSensorService Integration Guide

 ## Impact Detection Algorithm:

 ```swift
 extension AccelerationData {
 // Calculate acceleration magnitude (vector magnitude)
 var magnitude: Double {
 return sqrt(x * x + y * y + z * z)
 }

 // Determine if impact
 var isImpact: Bool {
 return magnitude > 1.5  // Exceeds 1.5G → impact
 }

 // Classify severity
 var impactSeverity: ImpactSeverity {
 if magnitude < 1.5 {
 return .none
 } else if magnitude < 2.5 {
 return .low
 } else if magnitude < 4.0 {
 return .moderate
 } else if magnitude < 6.0 {
 return .high
 } else {
 return .severe
 }
 }

 // Determine primary impact direction
 var primaryDirection: ImpactDirection {
 let absX = abs(x)
 let absY = abs(y)
 let absZ = abs(z)

 // Find largest axis
 let maxAxis = max(absX, absY, absZ)

 if maxAxis == absX {
 return x > 0 ? .right : .left
 } else if maxAxis == absY {
 return y > 0 ? .front : .rear
 } else {
 return z > 0 ? .top : .bottom
 }
 }
 }
 ```

 ## Real-time G-force Gauge UI:

 ```swift
 struct GForceGaugeView: View {
 @ObservedObject var gsensorService: GSensorService

 var body: some View {
 VStack {
 // Circular gauge
 ZStack {
 // Background circle
 Circle()
 .stroke(Color.gray.opacity(0.3), lineWidth: 20)

 // G-force gauge
 Circle()
 .trim(from: 0, to: CGFloat(min(gsensorService.currentGForce / 5.0, 1.0)))
 .stroke(
 gforceColor(gsensorService.currentGForce),
 style: StrokeStyle(lineWidth: 20, lineCap: .round)
 )
 .rotationEffect(.degrees(-90))

 // Numeric display
 VStack {
 Text(String(format: "%.2f", gsensorService.currentGForce))
 .font(.system(size: 48, weight: .bold))
 Text("G")
 .font(.system(size: 24))
 .foregroundColor(.gray)
 }
 }
 .frame(width: 200, height: 200)

 // Maximum value
 Text("Peak: \(String(format: "%.2f", gsensorService.peakGForce))G")
 .font(.caption)
 .foregroundColor(.secondary)
 }
 }

 func gforceColor(_ gforce: Double) -> Color {
 if gforce < 1.5 {
 return .green
 } else if gforce < 3.0 {
 return .orange
 } else {
 return .red
 }
 }
 }
 ```

 ## 3-axis Acceleration Graph:

 ```swift
 struct AccelerationChartView: View {
 @ObservedObject var gsensorService: GSensorService
 let timeRange: ClosedRange<TimeInterval>

 var body: some View {
 Chart {
 // X-axis (Left/Right)
 ForEach(gsensorService.allData) { data in
 LineMark(
 x: .value("Time", data.timestamp),
 y: .value("X", data.x)
 )
 .foregroundStyle(.red)
 }

 // Y-axis (Forward/Backward)
 ForEach(gsensorService.allData) { data in
 LineMark(
 x: .value("Time", data.timestamp),
 y: .value("Y", data.y)
 )
 .foregroundStyle(.green)
 }

 // Z-axis (Up/Down)
 ForEach(gsensorService.allData) { data in
 LineMark(
 x: .value("Time", data.timestamp),
 y: .value("Z", data.z)
 )
 .foregroundStyle(.blue)
 }

 // Impact event markers
 ForEach(gsensorService.impactEvents) { impact in
 RuleMark(x: .value("Impact", impact.timestamp))
 .foregroundStyle(.red.opacity(0.5))
 .annotation(position: .top) {
 Image(systemName: "exclamationmark.triangle.fill")
 .foregroundColor(.red)
 }
 }
 }
 .chartXScale(domain: timeRange)
 .chartYScale(domain: -6...6)
 .chartYAxis {
 AxisMarks(position: .leading)
 }
 .chartLegend(position: .bottom) {
 HStack {
 LegendItem(color: .red, label: "X (Left/Right)")
 LegendItem(color: .green, label: "Y (Forward/Backward)")
 LegendItem(color: .blue, label: "Z (Up/Down)")
 }
 }
 }
 }
 ```

 ## Impact Events List UI:

 ```swift
 struct ImpactEventsListView: View {
 @ObservedObject var gsensorService: GSensorService
 let onSelectImpact: (AccelerationData) -> Void

 var body: some View {
 List {
 // Section by severity
 ForEach(ImpactSeverity.allCases, id: \.self) { severity in
 let impacts = gsensorService.impactsBySeverity()[severity] ?? []

 if !impacts.isEmpty {
 Section(header: Text(severity.displayName)) {
 ForEach(impacts) { impact in
 ImpactRow(impact: impact)
 .onTapGesture {
 onSelectImpact(impact)
 }
 }
 }
 }
 }
 }
 .navigationTitle("Impact Events (\(gsensorService.impactCount))")
 }
 }

 struct ImpactRow: View {
 let impact: AccelerationData

 var body: some View {
 HStack {
 // severity icon
 Image(systemName: severityIcon(impact.impactSeverity))
 .foregroundColor(severityColor(impact.impactSeverity))

 VStack(alignment: .leading) {
 // hours
 Text(formatTime(impact.timestamp))
 .font(.headline)

 // direction
 Text(directionText(impact.primaryDirection))
 .font(.caption)
 .foregroundColor(.secondary)
 }

 Spacer()

 // G-force
 VStack(alignment: .trailing) {
 Text(String(format: "%.2f", impact.magnitude))
 .font(.title3)
 .bold()
 Text("G")
 .font(.caption)
 .foregroundColor(.secondary)
 }
 }
 }

 func severityIcon(_ severity: ImpactSeverity) -> String {
 switch severity {
 case .none: return "checkmark.circle"
 case .low: return "info.circle"
 case .moderate: return "exclamationmark.circle"
 case .high: return "exclamationmark.triangle"
 case .severe: return "xmark.octagon"
 }
 }

 func severityColor(_ severity: ImpactSeverity) -> Color {
 switch severity {
 case .none: return .green
 case .low: return .blue
 case .moderate: return .orange
 case .high: return .red
 case .severe: return .purple
 }
 }

 func directionText(_ direction: ImpactDirection) -> String {
 switch direction {
 case .front: return "↑ Front impact"
 case .rear: return "↓ Rear impact"
 case .left: return "← Left impact"
 case .right: return "→ Right impact"
 case .top: return "⬆ Top impact"
 case .bottom: return "⬇ Bottom impact"
 case .multiple: return "⊕ Multiple impact"
 }
 }
 }
 ```

 ## Timeline impact markers:

 ```swift
 struct TimelineWithImpactsView: View {
 @ObservedObject var gsensorService: GSensorService
 @Binding var currentTime: TimeInterval
 let duration: TimeInterval

 var body: some View {
 GeometryReader { geometry in
 ZStack(alignment: .leading) {
 // Timeline background
 Rectangle()
 .fill(Color.gray.opacity(0.3))
 .frame(height: 40)

 // impact marker
 ForEach(gsensorService.impactEvents) { impact in
 let offset = impact.timestamp.timeIntervalSince(videoStart)
 let x = (offset / duration) * geometry.size.width

 Rectangle()
 .fill(severityColor(impact.impactSeverity))
 .frame(width: 3, height: 40)
 .offset(x: x)
 }

 // Playback head
 Rectangle()
 .fill(Color.white)
 .frame(width: 2, height: 50)
 .offset(x: (currentTime / duration) * geometry.size.width)
 }
 }
 }
 }
 ```
 */
