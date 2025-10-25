/**
 * @file DataModelsTests.swift
 * @brief Data Model Unit Tests
 * @author BlackboxPlayer Team
 *
 * @details
 * A comprehensive unit test suite that systematically tests all data models in BlackboxPlayer.
 * Verifies business logic, data integrity, serialization/deserialization, and computed property accuracy.
 *
 * @section test_targets Target Models for Testing
 *
 * 1. **EventType** - Event Types
 *    - Normal/Impact/Parking/Manual/Emergency classification
 *    - Automatic detection based on file path
 *    - Priority comparison
 *
 * 2. **CameraPosition** - Camera Position
 *    - Front/Rear/Left/Right/Interior
 *    - Detection based on filename suffix (_F, _R, _L, _Ri, _I)
 *    - Channel index mapping
 *
 * 3. **GPSPoint** - GPS Location Data
 *    - Latitude/longitude validation
 *    - Distance calculation based on Haversine formula
 *    - Signal strength determination
 *
 * 4. **AccelerationData** - Acceleration Sensor Data
 *    - 3-axis (X, Y, Z) vector magnitude calculation
 *    - Impact detection (2.5G threshold)
 *    - Impact severity classification
 *
 * 5. **ChannelInfo** - Video Channel Information
 *    - Resolution and aspect ratio
 *    - Channel validity verification
 *
 * 6. **VideoMetadata** - Video Metadata
 *    - GPS data statistics (total distance, average/maximum speed)
 *    - Acceleration data statistics (maximum G-force)
 *    - Impact event detection
 *
 * 7. **VideoFile** - Video File Model
 *    - Multi-channel access
 *    - File properties (duration, size, timestamp)
 *    - Favorite/memo features
 *
 * @section test_importance Importance of Data Model Testing
 *
 * - **Business Logic Accuracy**: Verify domain rules are correctly implemented
 * - **Data Integrity**: Ensure invalid data doesn't enter the system
 * - **Codable Serialization**: Verify JSON encoding/decoding works without data loss
 * - **Computed Properties**: Validate that derived data is calculated correctly
 * - **Performance**: Measure and optimize bulk data processing performance
 *
 * @section test_strategy Testing Strategy
 *
 * **Unit Test Characteristics:**
 * - Fast execution in milliseconds without UI
 * - Remove external dependencies using Mock data
 * - Independent execution (order-independent)
 * - High coverage goal (90%+)
 *
 * **Using Given-When-Then Pattern:**
 * ```swift
 * func testEventTypeDetection() {
 *     // Given: Prepare file path
 *     let normalPath = "normal/video.mp4"
 *
 *     // When: Detect event type
 *     let eventType = EventType.detect(from: normalPath)
 *
 *     // Then: Verify .normal type
 *     XCTAssertEqual(eventType, .normal)
 * }
 * ```
 *
 * @section performance_tests Performance Tests
 *
 * - GPS distance calculation (Haversine formula)
 * - Video metadata summary generation
 * - 10 repeated measurements with measure { } block
 * - Performance regression detection with Baseline setting
 *
 * @note These tests don't depend on actual file system or network,
 * so they can be executed quickly at any time.
 */

// ============================================================================
// DataModelsTests.swift
// BlackboxPlayerTests
//
// Data Model Unit Tests
// ============================================================================
//
// Purpose of this file:
//    Systematically test all data models in BlackboxPlayer.
//
// Target Models:
//    1. EventType        - Event types (Normal/Impact/Parking/Manual/Emergency)
//    2. CameraPosition   - Camera position (Front/Rear/Left/Right/Interior)
//    3. GPSPoint         - GPS location data
//    4. AccelerationData - Acceleration sensor data
//    5. ChannelInfo      - Video channel information
//    6. VideoMetadata    - Video metadata
//    7. VideoFile        - Video file model
//
// Importance of Data Model Testing:
//    - Ensure business logic accuracy
//    - Verify data integrity
//    - Confirm Codable serialization/deserialization
//    - Validate computed property accuracy
//
// ============================================================================

import XCTest
@testable import BlackboxPlayer

// ═════════════════════════════════════════════════════════════════════════
// MARK: - DataModelsTests (Data Model Test Class)
// ═════════════════════════════════════════════════════════════════════════

/// Data model unit test class
///
/// Verifies functionality of all data models.
///
/// Test Scope:
/// - Initialization and default values
/// - Computed properties
/// - Method behavior
/// - Data conversion
/// - Serialization/deserialization
/// - Performance
///
/// Model Test Characteristics:
/// - Fast execution without UI (millisecond level)
/// - Use Mock data
/// - Independent execution possible
/// - High coverage goal (90%+)
final class DataModelsTests: XCTestCase {

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - EventType Tests
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Event type detection test
     */
    /**
     * Verify that event types are correctly detected from file paths.
     */
    /**
     *
     * @section _____ 🎯 Verification Items
     * - "normal" path → .normal
     * - "event" path → .impact
     * - "parking" path → .parking
     * - "manual" path → .manual
     * - "emergency" path → .emergency
     * - Unknown path → .unknown
     */
    /**
     *
     * @section ________ 💡 File Path Pattern
     * @endcode
     * Blackbox SD Card Structure:
     * /DCIM/
     *   normal/    ← Normal Driving Video
     *   event/     ← Impact Detection Video
     *   parking/   ← Parking Mode Video
     *   manual/    ← Manual Recording Video
     *   emergency/ ← Emergency Recording Video
     * @endcode
     */
    /**
     * @test testEventTypeDetection
     * @brief 🔍 Detection Algorithm:
     *
     * @details
     *
     * @section _______ 🔍 Detection Algorithm
     * @endcode
     * extension EventType {
     *     static func detect(from path: String) -> EventType {
     *         if path.contains("normal") { return .normal }
     *         if path.contains("event") { return .impact }
     *         // ...
     *         return .unknown
     *     }
     * }
     * @endcode
     */
    func testEventTypeDetection() {
        /**
         * Normal driving video detection
         */
        /**
         *
         * @section _normal____ 💡 .normal's meaning
         * - Automatic recording during normal driving
         * - No impact detection
         * - Subject to循环 recording (Old files automatically deleted)
         */
        XCTAssertEqual(EventType.detect(from: "normal/video.mp4"), .normal)

        /**
         * Impact detection video detection
         */
        /**
         *
         * @section _impact____ 💡 .impact's meaning
         * - Impact sensor detects above certain G-force
         * - Protected recording (Not automatically deleted)
         * - Important as accident evidence
         */
        XCTAssertEqual(EventType.detect(from: "event/video.mp4"), .impact)

        /**
         * Parking mode video detection
         */
        /**
         *
         * @section _parking____ 💡 .parking's meaning
         * - Recording while vehicle is parked
         * - Start recording when motion detected
         * - Timeout for battery protection
         */
        XCTAssertEqual(EventType.detect(from: "parking/video.mp4"), .parking)

        /**
         * Manual recording video detection
         */
        /**
         *
         * @section _manual____ 💡 .manual's meaning
         * - User presses button for manual recording
         * - Record special moments
         * - Protected recording (Not automatically deleted)
         */
        XCTAssertEqual(EventType.detect(from: "manual/video.mp4"), .manual)

        /**
         * Emergency recording video detection
         */
        /**
         *
         * @section _emergency____ 💡 .emergency's meaning
         * - Emergency button (SOS) when pressed
         * - Highest priority protection
         * - Can send automatic notifications
         */
        XCTAssertEqual(EventType.detect(from: "emergency/video.mp4"), .emergency)

        /**
         * Unknown type detection
         */
        /**
         *
         * @section _unknown____ 💡 .unknown's meaning
         * - Not matching standard path pattern
         * - Custom user folder
         * - Needs manual classification
         */
        XCTAssertEqual(EventType.detect(from: "unknown/video.mp4"), .unknown)
    }

    /**
     * Event type priority test
     */
    /**
     * Verify that importance comparison between event types is correct.
     */
    /**
     *
     * @section _______ 🎯 Priority Order
     * @endcode
     * emergency > impact > manual > parking > normal > unknown
     *    (Most important)                           (Lowest)
     * @endcode
     */
    /**
     *
     * @section ________ 💡 Purpose of Priority
     * - Determine deletion order when storage space is insufficient
     * - UIlist sorting order in UI
     * - Determine notification importance
     */
    /**
     *
     * @section _____ 📊 Usage Example
     * @endcode
     * // When storage space is insufficient
     * let videosToDelete = allVideos
     *     .sorted { $0.eventType < $1.eventType }  // Starting from lowest priority
     *     .prefix(10)  // 10items selected
     */
    /**
     * @test testEventTypePriority
     * @brief // emergencyand impactthe Deleted last
     *
     * @details
     * // emergencyand impactthe Deleted last
     * @endcode
     */
    func testEventTypePriority() {
        /**
         * Emergency > Impact
         */
        /**
         *
         * @section _________ 💡 Comparison Operator Implementation
         * @endcode
         * extension EventType: Comparable {
         *     static func < (lhs: EventType, rhs: EventType) -> Bool {
         *         return lhs.priority < rhs.priority
         *     }
         * }
         * @endcode
         */
        XCTAssertTrue(EventType.emergency > EventType.impact)

        /**
         * Impact > Normal
         */
        /**
         * Impact detection video is more important than normal driving video.
         * - Impact video: Needs protection
         * - Normal video: Subject to循环 recording
         */
        XCTAssertTrue(EventType.impact > EventType.normal)

        /**
         * Normal > Unknown
         */
        /**
         * Normal driving video is still more important than unknown.
         * - Normal: Normal recording
         * - unknown: Unclassified file
         */
        XCTAssertTrue(EventType.normal > EventType.unknown)
    }

    /**
     * Event type display name test
     */
    /**
     * UIVerify that display names are correct.
     */
    /**
     *
     * @section _____ 🎯 Verification Items
     * - .normal → "Normal"
     * - .impact → "Impact"
     * - .parking → "Parking"
     */
    /**
     *
     * @section _________ 💡 Purpose of Display Names
     * @endcode
     * // UIUsed in UI
     * List(videos) { video in
     *     HStack {
     *         Text(video.eventType.displayName)  // "Impact", "Normal" etc
     *         Image(systemName: video.eventType.iconName)
     *     }
     * }
     */
    /**
     * // Filtering UI
     * Picker("Event Type", selection: $selectedType) {
     *     ForEach(EventType.allCases) { type in
     *         Text(type.displayName).tag(type)
     *     }
     * }
     * @endcode
     */
    /**
     * @test testEventTypeDisplayNames
     * @brief 🌍 Multi-language Support:
     *
     * @details
     * 🌍 Multi-language Support:
     * @endcode
     * extension EventType {
     *     var displayName: String {
     *         switch self {
     *         case .normal:
     *             return NSLocalizedString("event.normal", comment: "Normal")
     *         case .impact:
     *             return NSLocalizedString("event.impact", comment: "Impact")
     *         // ...
     *         }
     *     }
     * }
     * @endcode
     */
    func testEventTypeDisplayNames() {
        /**
         * Normal Display Name Check
         */
        XCTAssertEqual(EventType.normal.displayName, "Normal")

        /**
         * Impact Display Name Check
         */
        /**
         *
         * @section ______ 💡 Alternative Names
         * @endcode
         * "Impact"    ✅ Selected (Concise and clear)
         * "Shock"        (Impact but Less Specific)
         * "Accident"     (Implies Accident Inappropriately)
         * "Event"        (Too general)
         * @endcode
         */
        XCTAssertEqual(EventType.impact.displayName, "Impact")

        /**
         * Parking Display Name Check
         */
        XCTAssertEqual(EventType.parking.displayName, "Parking")
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - CameraPosition Tests (Camera Position Tests)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Camera position detection test
     */
    /**
     * Verify that camera position is correctly detected from filename.
     */
    /**
     *
     * @section _____ 🎯 Verification Items
     * - "_F" suffix → .front
     * - "_R" suffix → .rear
     * - "_L" suffix → .left
     * - "_Ri" suffix → .right
     * - "_I" suffix → .interior
     */
    /**
     *
     * @section ___________ 💡 Blackbox Filename Rules
     * @endcode
     * Format: YYYY_MM_DD_HH_MM_SS_[Position].mp4
     * Example: 2025_01_10_09_00_00_F.mp4
     *       └─────┬─────┘└──┬──┘ └┬┘
     *           Date       Time    Position
     */
    /**
     * F  = Front    (Front)
     * R  = Rear     (Rear)
     * L  = Left     (Left)
     * Ri = Right    (Right)
     * I  = Interior (Interior)
     * @endcode
     */
    /**
     * 🚗 Camera Placement:
     * @endcode
     *        F (Front)
     *          ↑
     *    L ←  🚗  → Ri
     *          ↓
     *        R (Rear)
     */
    /**
     * @test testCameraPositionDetection
     * @brief I (Interior): Faces driver's seat
     *
     * @details
     * I (Interior): Faces driver's seat
     * @endcode
     */
    func testCameraPositionDetection() {
        /**
         * Front camera Detection
         */
        /**
         *
         * @section __f________ 💡 "_F" Suffix Pattern
         * - Abbreviation of Front
         * - Most important camera
         * - Required in most blackboxes
         */
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_F.mp4"), .front)

        /**
         * Rear camera Detection
         */
        /**
         *
         * @section __r________ 💡 "_R" Suffix Pattern
         * - Abbreviation of Rear
         * - Rear collision detection
         * - Second camera in 2-channel blackbox
         */
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_R.mp4"), .rear)

        /**
         * Left camera Detection
         */
        /**
         *
         * @section __l________ 💡 "_L" Suffix Pattern
         * - Abbreviation of Left
         * - Blind spot detection
         * - Used in 4-channel blackbox
         */
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_L.mp4"), .left)

        /**
         * Right camera Detection
         */
        /**
         *
         * @section __ri________ 💡 "_Ri" Suffix Pattern
         * - Abbreviation of Right
         * - Use "Ri" to distinguish from Rear "R"
         * - Right blind spot detection
         */
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_Ri.mp4"), .right)

        /**
         * Interior camera Detection
         */
        /**
         *
         * @section __i________ 💡 "_I" Suffix Pattern
         * - Abbreviation of Interior
         * - Used in taxi, Uber, etc
         * - Monitors passengers and driver
         */
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_I.mp4"), .interior)
    }

    /**
     * Camera Position Channel Index Test
     */
    /**
     * Verify that each camera position has the correct channel number.
     */
    /**
     *
     * @section _____ 🎯 Verification Items
     * - .front → 0
     * - .rear → 1
     * - .left → 2
     * - .right → 3
     * - .interior → 4
     */
    /**
     *
     * @section __________ 💡 Purpose of Channel Index
     * @endcode
     * // Select video stream in FFmpeg
     * let streamIndex = cameraPosition.channelIndex
     * avformat_find_stream_info(formatContext, nil)
     * let stream = formatContext.streams[streamIndex]
     */
    /**
     * // Texture array index during rendering
     * textures[position.channelIndex] = newTexture
     */
    /**
     * // Channel selection in UI
     * let channel = channels[selectedPosition.channelIndex]
     * @endcode
     */
    /**
     * @test testCameraPositionChannelIndex
     * @brief 📊 Importance of Channel Order:
     *
     * @details
     *
     * @section __________ 📊 Importance of Channel Order
     * - Ensures consistency with fixed order
     * - Fast access via array index
     * - Matches FFmpeg stream order
     */
    func testCameraPositionChannelIndex() {
        /**
         * Front camera = Channel 0
         */
        /**
         *
         * @section 0_________ 💡 Reason why Front is Channel 0
         * - Most important camera
         * - Default channel that always exists
         * - First element of array
         */
        XCTAssertEqual(CameraPosition.front.channelIndex, 0)

        /**
         * Rear camera = Channel 1
         */
        /**
         * Second most important camera
         * Standard in 2-channel blackbox
         */
        XCTAssertEqual(CameraPosition.rear.channelIndex, 1)

        /**
         * Left camera = Channel 2
         */
        /**
         * Third channel in 4-channel blackbox
         */
        XCTAssertEqual(CameraPosition.left.channelIndex, 2)

        /**
         * Right camera = Channel 3
         */
        /**
         * Fourth channel in 4-channel blackbox
         */
        XCTAssertEqual(CameraPosition.right.channelIndex, 3)

        /**
         * Interior camera = Channel 4
         */
        /**
         *
         * @section 5______________ 💡 Additional Channel in 5-Channel Blackbox
         * - Optional feature
         * - For taxi/Uber
         * - Last index
         */
        XCTAssertEqual(CameraPosition.interior.channelIndex, 4)
    }

    /**
     * Convert Channel Index to Camera Position Test
     */
    /**
     * Verify that camera position is correctly found from channel number.
     */
    /**
     *
     * @section _____ 🎯 Verification Items
     * - 0 → .front
     * - 1 → .rear
     * - 4 → .interior
     * - 99 (invalid value) → nil
     */
    /**
     *
     * @section _____ 💡 Use Cases
     * @endcode
     * // Extract position from FFmpeg stream
     * for i in 0..<streamCount {
     *     if let position = CameraPosition.from(channelIndex: i) {
     *         channels[position] = decodeStream(at: i)
     *     }
     * }
     */
    /**
     * // Map position from UI index
     * @State var selectedIndex = 0
     * var selectedPosition: CameraPosition? {
     *     CameraPosition.from(channelIndex: selectedIndex)
     * }
     * @endcode
     */
    /**
     * @test testCameraPositionFromChannelIndex
     * @brief 🔄 Bidirectional Conversion:
     *
     * @details
     *
     * @section ______ 🔄 Bidirectional Conversion
     * @endcode
     * let position: CameraPosition = .front
     * let index = position.channelIndex      // → 0
     * let restored = CameraPosition.from(channelIndex: index)  // → .front
     * assert(restored == position)  // ✅
     * @endcode
     */
    func testCameraPositionFromChannelIndex() {
        /**
         * Channel 0 → Front camera
         */
        XCTAssertEqual(CameraPosition.from(channelIndex: 0), .front)

        /**
         * Channel 1 → Rear camera
         */
        XCTAssertEqual(CameraPosition.from(channelIndex: 1), .rear)

        /**
         * Channel 4 → Interior camera
         */
        XCTAssertEqual(CameraPosition.from(channelIndex: 4), .interior)

        /**
         * Invalid channel number → nil
         */
        /**
         *
         * @section nil_______ 💡 Reason for Returning nil
         * - Invalid index
         * - Unsupported channel
         * - Safe failure handling with Optional
         */
        /**
         *
         * @section _____ 🔍 Usage Example
         * @endcode
         * guard let position = CameraPosition.from(channelIndex: 99) else {
         *     print("Invalid channel index")
         *     return
         * }
         * @endcode
         */
        XCTAssertNil(CameraPosition.from(channelIndex: 99))
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - GPSPoint Tests (GPS Position Data Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * GPS Point Validation Test
     */
    /**
     * Verify that latitude/longitude values are within valid range.
     */
    /**
     * @test testGPSPointValidation
     * @brief 🌍 Valid range:
     *
     * @details
     * 🌍 Valid range:
     * - Latitude: -90° ~ 90° (North/South latitude)
     * - Longitude: -180° ~ 180° (East/West longitude)
     */
    func testGPSPointValidation() {
        /**
         * Valid GPS point
         */
        /**
         * Seoul City Hall coordinates: 37.5665°N, 126.9780°E
         */
        let valid = GPSPoint.sample
        XCTAssertTrue(valid.isValid)

        /**
         * Invalid GPS point
         */
        /**
         *
         * @section latitude___91_0_________ 💡 latitude = 91.0 is invalid
         * - Maximum latitude is 90° (North Pole)
         * - 91° does not exist on Earth
         */
        let invalid = GPSPoint(
            timestamp: Date(),
            latitude: 91.0,  // Invalid (> 90)
            longitude: 0.0
        )
        XCTAssertFalse(invalid.isValid)
    }

    /**
     * GPS Point Distance Calculation Test
     */
    /**
     * Verify distance between two GPS coordinates using Haversine Formula.
     */
    /**
     * @test testGPSPointDistance
     * @brief 🌐 Haversine Formula:
     *
     * @details
     *
     * @section haversine___ 🌐 Haversine Formula
     * Uses spherical trigonometry to calculate shortest distance between two points on Earth.
     */
    func testGPSPointDistance() {
        /**
         * Two points near Seoul Gwanghwamun
         */
        /**
         * point1: 37.5665°N, 126.9780°E
         * point2: 37.5667°N, 126.9782°E
         */
        /**
         * Approximately 25-30meters distance
         */
        let point1 = GPSPoint(timestamp: Date(), latitude: 37.5665, longitude: 126.9780)
        let point2 = GPSPoint(timestamp: Date(), latitude: 37.5667, longitude: 126.9782)

        let distance = point1.distance(to: point2)

        /**
         * Check that distance is positive
         */
        XCTAssertGreaterThan(distance, 0)

        /**
         * Check that distance is within 50 meters
         */
        /**
         *
         * @section 0_0002_______22__ 💡 0.0002 degree difference ≈ 22 meters
         */
        XCTAssertLessThan(distance, 50)
    }

    /**
     * GPS Signal Strength Test
     */
    /**
     * @test testGPSPointSignalStrength
     * @brief Determines signal strength based on accuracy and satellite count.
     *
     * @details
     * Determines signal strength based on accuracy and satellite count.
     */
    func testGPSPointSignalStrength() {
        /**
         * Strong GPS signal
         */
        /**
         *
         * @section _________ 💡 Conditions for strong signal
         * - horizontalAccuracy < 10m
         * - satelliteCount >= 7
         */
        let strongSignal = GPSPoint(
            timestamp: Date(),
            latitude: 37.5665,
            longitude: 126.9780,
            horizontalAccuracy: 5.0,      // 5 meter error
            satelliteCount: 8             // 8 satellites
        )
        XCTAssertTrue(strongSignal.hasStrongSignal)

        /**
         * Weak GPS signal
         */
        /**
         *
         * @section _________ 💡 Conditions for weak signal
         * - horizontalAccuracy >= 10m
         * - satelliteCount < 7
         */
        let weakSignal = GPSPoint(
            timestamp: Date(),
            latitude: 37.5665,
            longitude: 126.9780,
            horizontalAccuracy: 100.0,    // 100 meter error
            satelliteCount: 3             // 3 satellites only
        )
        XCTAssertFalse(weakSignal.hasStrongSignal)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - AccelerationData Tests (Acceleration Sensor Data Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Acceleration Magnitude Calculation Test
     */
    /**
     * Calculate vector magnitude of 3-axis acceleration.
     */
    /**
     * @test testAccelerationMagnitude
     * @brief 📐 Vector Magnitude Formula:
     *
     * @details
     * 📐 Vector Magnitude Formula:
     * magnitude = √(x² + y² + z²)
     */
    func testAccelerationMagnitude() {
        /**
         * Verify Pythagorean theorem: 3-4-5 Triangle
         */
        /**
         * x=3, y=4, z=0 → magnitude = 5
         * √(3² + 4² + 0²) = √(9 + 16) = √25 = 5
         */
        let data = AccelerationData(timestamp: Date(), x: 3.0, y: 4.0, z: 0.0)
        XCTAssertEqual(data.magnitude, 5.0, accuracy: 0.01)
    }

    /**
     * Impact Detection Test
     */
    /**
     * Determine impact occurrence based on acceleration magnitude.
     */
    /**
     * @test testAccelerationImpactDetection
     * @brief 📊 Impact Criteria (G-force):
     *
     * @details
     *
     * @section _______g_force_ 📊 Impact Criteria (G-force)
     * - Normal: < 1.5G
     * - Hard braking: 1.5G ~ 2.5G
     * - Impact: 2.5G ~ 5G
     * - Severe impact: > 5G
     */
    func testAccelerationImpactDetection() {
        /**
         * Normal driving (not impact)
         */
        XCTAssertFalse(AccelerationData.normal.isImpact)

        /**
         * Hard braking (not impact)
         */
        XCTAssertFalse(AccelerationData.braking.isImpact)

        /**
         * Impact (impact detected)
         */
        XCTAssertTrue(AccelerationData.impact.isImpact)

        /**
         * Severe impact (severe impact detected)
         */
        XCTAssertTrue(AccelerationData.severeImpact.isSevereImpact)
    }

    /**
     * Impact Severity Classification Test
     */
    /**
     * @test testAccelerationSeverity
     * @brief Classify into 4 levels based on acceleration magnitude.
     *
     * @details
     * Classify into 4 levels based on acceleration magnitude.
     */
    func testAccelerationSeverity() {
        /**
         * Normal → No severity
         */
        XCTAssertEqual(AccelerationData.normal.impactSeverity, .none)

        /**
         * Hard braking → Moderate severity
         */
        XCTAssertEqual(AccelerationData.braking.impactSeverity, .moderate)

        /**
         * Impact → High severity
         */
        XCTAssertEqual(AccelerationData.impact.impactSeverity, .high)

        /**
         * Severe impact → Severe level
         */
        XCTAssertEqual(AccelerationData.severeImpact.impactSeverity, .severe)
    }

    /**
     * Acceleration Direction Test
     */
    /**
     * @test testAccelerationDirection
     * @brief Determine primary direction based on largest acceleration axis.
     *
     * @details
     * Determine primary direction based on largest acceleration axis.
     */
    func testAccelerationDirection() {
        /**
         * Left turn (X axis is largest)
         */
        /**
         * x=-2.0 (large acceleration to the left)
         */
        let leftTurn = AccelerationData(timestamp: Date(), x: -2.0, y: 0.5, z: 1.0)
        XCTAssertEqual(leftTurn.primaryDirection, .left)

        /**
         * Hard braking (Y axis is largest)
         */
        /**
         * y=-3.0 (large acceleration to the rear)
         */
        let braking = AccelerationData(timestamp: Date(), x: 0.0, y: -3.0, z: 1.0)
        XCTAssertEqual(braking.primaryDirection, .backward)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - ChannelInfo Tests (Channel Information Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Channel Resolution Test
     */
    /**
     * @test testChannelInfoResolution
     * @brief Verify that resolution string and name are created correctly.
     *
     * @details
     * Verify that resolution string and name are created correctly.
     */
    func testChannelInfoResolution() {
        let hd = ChannelInfo.frontHD

        /**
         * Resolution string: "1920x1080"
         */
        XCTAssertEqual(hd.resolutionString, "1920x1080")

        /**
         * Resolution name: "Full HD"
         */
        XCTAssertEqual(hd.resolutionName, "Full HD")

        /**
         * High resolution flag
         */
        /**
         *
         * @section ____________1920x1080 💡 High resolution criteria: >= 1920x1080
         */
        XCTAssertTrue(hd.isHighResolution)
    }

    /**
     * Channel Aspect Ratio Test
     */
    /**
     * @test testChannelInfoAspectRatio
     * @brief Calculate aspect ratio such as 16:9, 4:3, etc.
     *
     * @details
     * Calculate aspect ratio such as 16:9, 4:3, etc.
     */
    func testChannelInfoAspectRatio() {
        let hd = ChannelInfo.frontHD

        /**
         * Aspect ratio string: "16:9"
         */
        XCTAssertEqual(hd.aspectRatioString, "16:9")

        /**
         * Aspect ratio decimal: 1.777...
         */
        /**
         * 16 / 9 = 1.777...
         */
        XCTAssertEqual(hd.aspectRatio, 16.0 / 9.0, accuracy: 0.01)
    }

    /**
     * Channel Validation Test
     */
    /**
     * @test testChannelInfoValidation
     * @brief Verify that required fields have valid values.
     *
     * @details
     * Verify that required fields have valid values.
     */
    func testChannelInfoValidation() {
        /**
         * Valid channel
         */
        let valid = ChannelInfo.frontHD
        XCTAssertTrue(valid.isValid)

        /**
         * Invalid channel
         */
        /**
         *
         * @section ______ 💡 Reasons for invalidity
         * - filePath is empty
         * - width = 0
         * - height = 0
         * - frameRate = 0
         */
        let invalid = ChannelInfo(
            position: .front,
            filePath: "",  // Empty path
            width: 0,      // Invalid width
            height: 0,
            frameRate: 0
        )
        XCTAssertFalse(invalid.isValid)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - VideoMetadata Tests (Video Metadata Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @test testVideoMetadataGPSData
     * @brief Video Metadata GPS Data Test
     *
     * @details
     * Video Metadata GPS Data Test
     */
    func testVideoMetadataGPSData() {
        let metadata = VideoMetadata.sample

        /**
         * GPS data presence
         */
        XCTAssertTrue(metadata.hasGPSData)

        /**
         * Total distance traveled (meters)
         */
        XCTAssertGreaterThan(metadata.totalDistance, 0)

        /**
         * Average speed (km/h)
         */
        XCTAssertNotNil(metadata.averageSpeed)

        /**
         * Maximum speed (km/h)
         */
        XCTAssertNotNil(metadata.maximumSpeed)
    }

    /**
     * @test testVideoMetadataAccelerationData
     * @brief Video Metadata Acceleration Data Test
     *
     * @details
     * Video Metadata Acceleration Data Test
     */
    func testVideoMetadataAccelerationData() {
        let metadata = VideoMetadata.sample

        /**
         * Acceleration data presence
         */
        XCTAssertTrue(metadata.hasAccelerationData)

        /**
         * Maximum G-force
         */
        XCTAssertNotNil(metadata.maximumGForce)
    }

    /**
     * @test testVideoMetadataImpactDetection
     * @brief Video Metadata Impact Detection Test
     *
     * @details
     * Video Metadata Impact Detection Test
     */
    func testVideoMetadataImpactDetection() {
        /**
         * Metadata with GPS only (no impact)
         */
        let noImpact = VideoMetadata.gpsOnly
        XCTAssertFalse(noImpact.hasImpactEvents)

        /**
         * Metadata with impact events
         */
        let withImpact = VideoMetadata.withImpact
        XCTAssertTrue(withImpact.hasImpactEvents)
        XCTAssertGreaterThan(withImpact.impactEvents.count, 0)
    }

    /**
     * @test testVideoMetadataPointRetrieval
     * @brief Video Metadata Point Retrieval Test
     *
     * @details
     * Video Metadata Point Retrieval Test
     */
    func testVideoMetadataPointRetrieval() {
        let metadata = VideoMetadata.sample

        /**
         * Retrieve GPS point at specific time
         */
        /**
         *
         * @section 1_0______gps______ 💡 Retrieve GPS coordinates at 1.0 seconds
         */
        let gpsPoint = metadata.gpsPoint(at: 1.0)
        XCTAssertNotNil(gpsPoint)

        /**
         * Retrieve acceleration data at specific time
         */
        /**
         *
         * @section 1_0____________ 💡 Retrieve acceleration at 1.0 seconds
         */
        let accelData = metadata.accelerationData(at: 1.0)
        XCTAssertNotNil(accelData)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - VideoFile Tests (Video File Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @test testVideoFileChannelAccess
     * @brief Video File Channel Access Test
     *
     * @details
     * Video File Channel Access Test
     */
    func testVideoFileChannelAccess() {
        let video = VideoFile.normal5Channel

        /**
         * Total number of channels
         */
        XCTAssertEqual(video.channelCount, 5)

        /**
         * Multi-channel status (2 or more)
         */
        XCTAssertTrue(video.isMultiChannel)

        /**
         * Front channel existence check
         */
        XCTAssertNotNil(video.frontChannel)

        /**
         * Rear channel existence check
         */
        XCTAssertNotNil(video.rearChannel)

        /**
         * Specific channel existence check
         */
        XCTAssertTrue(video.hasChannel(.front))
        XCTAssertTrue(video.hasChannel(.rear))
    }

    /**
     * @test testVideoFileProperties
     * @brief Video File Property Test
     *
     * @details
     * Video File Property Test
     */
    func testVideoFileProperties() {
        let video = VideoFile.normal5Channel

        /**
         * Event type
         */
        XCTAssertEqual(video.eventType, .normal)

        /**
         * Playback duration (seconds)
         */
        XCTAssertEqual(video.duration, 60.0)

        /**
         * Total file size (bytes)
         */
        XCTAssertGreaterThan(video.totalFileSize, 0)

        /**
         * Favorite status (Default value: false)
         */
        XCTAssertFalse(video.isFavorite)
    }

    /**
     * @test testVideoFileValidation
     * @brief Video File Validation Test
     *
     * @details
     * Video File Validation Test
     */
    func testVideoFileValidation() {
        /**
         * Valid video file
         */
        let valid = VideoFile.normal5Channel
        XCTAssertTrue(valid.isValid)
        XCTAssertTrue(valid.isPlayable)

        /**
         * Corrupted video file
         */
        let corrupted = VideoFile.corruptedFile
        XCTAssertFalse(corrupted.isPlayable)
    }

    /**
     * Video File Change Test
     */
    /**
     * @test testVideoFileMutations
     * @brief 💡 Struct Immutability:
     *
     * @details
     *
     * @section struct_____ 💡 Struct Immutability
     * - Original is not changed
     * - Returns new instance
     */
    func testVideoFileMutations() {
        let original = VideoFile.normal5Channel
        XCTAssertFalse(original.isFavorite)

        /**
         * Add to favorites
         */
        let favorited = original.withFavorite(true)
        XCTAssertTrue(favorited.isFavorite)
        XCTAssertEqual(favorited.id, original.id)  // ID is maintained

        /**
         * Add memo
         */
        let withNotes = original.withNotes("Test note")
        XCTAssertEqual(withNotes.notes, "Test note")
    }

    /**
     * @test testVideoFileMetadata
     * @brief Video File Metadata Test
     *
     * @details
     * Video File Metadata Test
     */
    func testVideoFileMetadata() {
        let video = VideoFile.normal5Channel
        XCTAssertTrue(video.hasGPSData)
        XCTAssertTrue(video.hasAccelerationData)

        let impactVideo = VideoFile.impact2Channel
        XCTAssertTrue(impactVideo.hasImpactEvents)
    }

    /**
     * @test testVideoFileFormatting
     * @brief Video File Formatting Test
     *
     * @details
     * Video File Formatting Test
     */
    func testVideoFileFormatting() {
        let video = VideoFile.normal5Channel

        /**
         * Duration string (Example: "01:00")
         */
        XCTAssertFalse(video.durationString.isEmpty)

        /**
         * Timestamp string (Example: "2025-01-10 09:00:00")
         */
        XCTAssertFalse(video.timestampString.isEmpty)

        /**
         * File size string (Example: "125.5 MB")
         */
        XCTAssertFalse(video.totalFileSizeString.isEmpty)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Codable Tests (Serialization/Deserialization Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * GPSPoint Codable Test
     */
    /**
     * @test testGPSPointCodable
     * @brief 💡 Codable Protocol:
     *
     * @details
     *
     * @section codable_____ 💡 Codable Protocol
     * - Encode to JSON
     * - Decode from JSON
     * - For data persistence and transmission
     */
    func testGPSPointCodable() throws {
        let original = GPSPoint.sample

        /**
         * JSON encoding
         */
        let encoded = try JSONEncoder().encode(original)

        /**
         * JSON decoding
         */
        let decoded = try JSONDecoder().decode(GPSPoint.self, from: encoded)

        /**
         * Verify data preservation
         */
        XCTAssertEqual(decoded.latitude, original.latitude)
        XCTAssertEqual(decoded.longitude, original.longitude)
    }

    /**
     * @test testAccelerationDataCodable
     * @brief AccelerationData Codable Test
     *
     * @details
     * AccelerationData Codable Test
     */
    func testAccelerationDataCodable() throws {
        let original = AccelerationData.impact

        /**
         * JSON encoding
         */
        let encoded = try JSONEncoder().encode(original)

        /**
         * JSON decoding
         */
        let decoded = try JSONDecoder().decode(AccelerationData.self, from: encoded)

        /**
         * Verify 3-axis data preservation
         */
        XCTAssertEqual(decoded.x, original.x)
        XCTAssertEqual(decoded.y, original.y)
        XCTAssertEqual(decoded.z, original.z)
    }

    /**
     * @test testVideoFileCodable
     * @brief VideoFile Codable Test
     *
     * @details
     * VideoFile Codable Test
     */
    func testVideoFileCodable() throws {
        let original = VideoFile.normal5Channel

        /**
         * JSON encoding
         */
        let encoded = try JSONEncoder().encode(original)

        /**
         * JSON decoding
         */
        let decoded = try JSONDecoder().decode(VideoFile.self, from: encoded)

        /**
         * Verify key property preservation
         */
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.eventType, original.eventType)
        XCTAssertEqual(decoded.duration, original.duration)
        XCTAssertEqual(decoded.channelCount, original.channelCount)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Performance Tests (Performance Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * GPS Distance Calculation Performance Test
     */
    /**
     * @test testGPSDistanceCalculationPerformance
     * @brief 💡 Haversine Formula Performance:
     *
     * @details
     *
     * @section haversine_______ 💡 Haversine Formula Performance
     * - Uses trigonometric functions (sin, cos, asin)
     * - Floating-point intensive operations
     * - Optimization needed when processing many points
     */
    func testGPSDistanceCalculationPerformance() {
        let points = GPSPoint.sampleRoute

        /**
         * 10 repeated measurements
         */
        measure {
            /**
             * Calculate distance for all consecutive point pairs
             */
            for i in 0..<(points.count - 1) {
                _ = points[i].distance(to: points[i + 1])
            }
        }
    }

    /**
     * Video Metadata Summary Creation Performance Test
     */
    /**
     * @test testVideoMetadataSummaryPerformance
     * @brief 💡 Summary Creation Definition:
     *
     * @details
     *
     * @section ________ 💡 Summary Creation Definition
     * - Process all GPS points
     * - Process all acceleration data
     * - Statistical calculation (Average, Maximum, Minimum)
     * - Event analysis
     */
    func testVideoMetadataSummaryPerformance() {
        let metadata = VideoMetadata.sample

        /**
         * 10 repeated measurements
         */
        measure {
            /**
             * Create summary string
             */
            _ = metadata.summary
        }
    }
}
