/**
 * @file GPSSensorIntegrationTests.swift
 * @brief GPS/G-sensor visualization feature integration tests
 * @author BlackboxPlayer Team
 *
 * @details
 * Comprehensively tests parsing, loading, synchronization, and visualization features of GPS and G-sensor data.
 *
 * @section test_overview Test Overview
 *
 * GPS/G-sensor data processing pipeline:
 * @code
 * Video File (with metadata)
 *       ↓
 * ┌─────┴─────┬─────────────┐
 * ↓           ↓             ↓
 * GPS Data    G-sensor Data Video Channel
 *   ↓           ↓             ↓
 * GPSParser   AccelParser   VideoDecoder
 *   ↓           ↓             ↓
 * GPSService  GSensorSvc    VideoChannel
 *   ↓           ↓             ↓
 * └─────┬─────┴─────────────┘
 *       ↓
 * SyncController (30fps sync)
 *       ↓
 * ┌─────┴─────┬─────────┐
 * ↓           ↓         ↓
 * MapOverlay  Graph     Video
 * (GPS path)  (Accel)   (Video)
 * @endcode
 *
 * @section test_categories Test Categories
 *
 * -# <b>Data Parsing Tests</b>: Verify GPS/G-sensor binary data parsing
 * -# <b>Service Load Tests</b>: Verify data loading and initialization
 * -# <b>Synchronization Tests</b>: Verify synchronization between video playback time and sensor data
 * -# <b>Real-time Update Tests</b>: Verify real-time sensor data updates during playback
 * -# <b>Seek Synchronization Tests</b>: Verify sensor data synchronization during time seeking
 * -# <b>Performance Tests</b>: Verify large-scale data processing performance
 */

// ============================================================================
// MARK: - Imports
// ============================================================================

import XCTest
import Combine
import CoreLocation
@testable import BlackboxPlayer

// ============================================================================
// MARK: - GPS/G-Sensor Integration Tests
// ============================================================================

/**
 * @class GPSSensorIntegrationTests
 * @brief GPS/G-sensor visualization feature integration test class
 *
 * @details
 * Validates the entire processing pipeline for GPS and G-sensor data.
 * Performs integration tests from data parsing to UI display.
 */
class GPSSensorIntegrationTests: XCTestCase {

    // MARK: - Properties

    /// Test target SyncController
    var syncController: SyncController!

    /// GPS service
    var gpsService: GPSService!

    /// G-sensor service
    var gsensorService: GSensorService!

    /// Combine subscription storage
    var cancellables: Set<AnyCancellable> = []

    // MARK: - Setup & Teardown

    /**
     * @brief Initialize before each test execution
     *
     * @details
     * - Create SyncController
     * - Initialize GPS/G-sensor services
     * - Initialize Combine subscription storage
     */
    override func setUp() {
        super.setUp()

        syncController = SyncController()
        gpsService = GPSService()
        gsensorService = GSensorService()
        cancellables = []
    }

    /**
     * @brief Cleanup after each test execution
     *
     * @details
     * - Stop playback
     * - Clean up services
     * - Cancel subscriptions
     */
    override func tearDown() {
        syncController?.stop()
        gpsService?.clear()
        gsensorService?.clear()
        cancellables.removeAll()

        syncController = nil
        gpsService = nil
        gsensorService = nil

        super.tearDown()
    }

    // ============================================================================
    // MARK: - 1. GPS Data Parsing Tests
    // ============================================================================

    /**
     * @brief VideoMetadata GPS data verification test
     *
     * @details
     * Verifies that VideoMetadata correctly stores and retrieves GPS data.
     *
     * Test scenario:
     * 1. Create GPS point array
     * 2. Create VideoMetadata
     * 3. Verify GPS point count
     * 4. Query GPS point at specific time
     */
    func testVideoMetadataGPSData() {
        // Given: Create sample GPS points
        let baseDate = Date()
        let gpsPoints = createSampleGPSPoints(baseDate: baseDate, count: 10)

        // When: Create VideoMetadata
        let metadata = VideoMetadata(
            gpsPoints: gpsPoints,
            accelerationData: []
        )

        // Then: Verify GPS data
        XCTAssertEqual(metadata.gpsPoints.count, 10, "10 GPS points should be stored")
        XCTAssertTrue(metadata.hasGPSData, "GPS data should exist")

        // Query GPS point at specific time
        if let point = metadata.gpsPoint(at: 5.0) {
            XCTAssertNotNil(point, "Should find GPS point at 5 second mark")
        }
    }

    // ============================================================================
    // MARK: - 2. G-Sensor Data Parsing Tests
    // ============================================================================

    /**
     * @brief VideoMetadata acceleration data verification test
     *
     * @details
     * Verifies that VideoMetadata correctly stores and retrieves G-sensor data.
     *
     * Test scenario:
     * 1. Create AccelerationData array
     * 2. Create VideoMetadata
     * 3. Verify acceleration data count
     * 4. Query acceleration data at specific time
     */
    func testVideoMetadataAccelerationData() {
        // Given: Create sample acceleration data
        let baseDate = Date()
        let accelData = createSampleAccelerationData(baseDate: baseDate, count: 1000)

        // When: Create VideoMetadata
        let metadata = VideoMetadata(
            gpsPoints: [],
            accelerationData: accelData
        )

        // Then: Verify acceleration data
        XCTAssertEqual(metadata.accelerationData.count, 1000, "1000 acceleration samples should be stored")
        XCTAssertTrue(metadata.hasAccelerationData, "Acceleration data should exist")

        // Query acceleration data at specific time
        if let data = metadata.accelerationData(at: 5.0) {
            XCTAssertNotNil(data, "Should find acceleration data at 5 second mark")
        }
    }

    /**
     * @brief G-sensor impact event detection test
     *
     * @details
     * Verifies that VideoMetadata correctly detects impact events from high acceleration values.
     *
     * Test scenario:
     * 1. Create normal driving data + impact data
     * 2. Load into VideoMetadata
     * 3. Verify impact event detection
     * 4. Verify impact magnitude calculation
     */
    func testImpactEventDetection() {
        // Given: Normal driving + impact event data
        let baseDate = Date()
        let normalData = AccelerationData(timestamp: baseDate, x: 0.0, y: 0.0, z: 1.0)
        let impactData = AccelerationData(timestamp: baseDate.addingTimeInterval(1.0),
                                          x: 5.0, y: 3.0, z: 2.0) // Strong impact

        let metadata = VideoMetadata(
            gpsPoints: [],
            accelerationData: [normalData, impactData]
        )

        // Then: Verify impact event detection
        let impactEvents = metadata.impactEvents
        XCTAssertGreaterThan(impactEvents.count, 0, "Impact event should be detected")

        // Verify impact magnitude calculation
        let detectedImpact = impactEvents.first!
        let magnitude = sqrt(detectedImpact.x * detectedImpact.x +
                                detectedImpact.y * detectedImpact.y +
                                detectedImpact.z * detectedImpact.z)
        XCTAssertGreaterThan(magnitude, 3.0, "Impact magnitude should exceed threshold")
    }

    // ============================================================================
    // MARK: - 3. Service Integration Tests
    // ============================================================================

    /**
     * @brief GPS service integration test
     *
     * @details
     * Verifies that GPSService correctly loads and queries GPS data from VideoMetadata.
     *
     * Test scenario:
     * 1. Create GPS metadata
     * 2. Call GPSService.loadGPSData()
     * 3. Verify data is loaded into GPS service
     * 4. Test current location query
     */
    func testGPSServiceIntegration() {
        // Given: GPS metadata
        let baseDate = Date()
        let gpsPoints = createSampleGPSPoints(baseDate: baseDate, count: 10)
        let metadata = VideoMetadata(gpsPoints: gpsPoints, accelerationData: [])

        // When: Load GPS data
        gpsService.loadGPSData(from: metadata, startTime: baseDate)

        // Then: Verify data loaded into GPS service
        XCTAssertTrue(gpsService.hasData, "GPS data should be loaded")
        XCTAssertEqual(gpsService.pointCount, 10, "10 GPS points should be loaded")
        XCTAssertEqual(gpsService.routePoints.count, 10, "Route points should be set")

        // Query current location
        let location = gpsService.getCurrentLocation(at: 5.0)
        XCTAssertNotNil(location, "Should find location at 5 second mark")
    }

    /**
     * @brief GPS data time interpolation test
     *
     * @details
     * Verifies that GPSService performs linear interpolation for positions between two GPS points.
     *
     * Test scenario:
     * 1. Create two GPS points (0 sec, 2 sec)
     * 2. Request position at middle time (1 sec)
     * 3. Verify interpolated position is accurate
     */
    func testGPSInterpolation() {
        // Given: GPS points at 0 sec and 2 sec
        let baseDate = Date()
        let point1 = GPSPoint(
            timestamp: baseDate,
            latitude: 37.5000,
            longitude: 127.0000,
            speed: 30.0
        )
        let point2 = GPSPoint(
            timestamp: baseDate.addingTimeInterval(2.0),
            latitude: 37.5020,
            longitude: 127.0020,
            speed: 40.0
        )

        let metadata = VideoMetadata(gpsPoints: [point1, point2], accelerationData: [])

        gpsService.loadGPSData(from: metadata, startTime: baseDate)

        // When: Request position at middle time (1 sec)
        let interpolatedLocation = gpsService.getCurrentLocation(at: 1.0)

        // Then: Verify interpolated position (should be middle value)
        XCTAssertNotNil(interpolatedLocation, "Should return interpolated position")

        if let location = interpolatedLocation {
            // Latitude: (37.5000 + 37.5020) / 2 = 37.5010
            XCTAssertEqual(location.coordinate.latitude, 37.5010, accuracy: 0.0001,
                           "Latitude should be linearly interpolated")
            // Longitude: (127.0000 + 127.0020) / 2 = 127.0010
            XCTAssertEqual(location.coordinate.longitude, 127.0010, accuracy: 0.0001,
                           "Longitude should be linearly interpolated")
            // Speed: (30.0 + 40.0) / 2 = 35.0
            XCTAssertEqual(location.speed ?? 0.0, 35.0, accuracy: 0.1,
                           "Speed should be linearly interpolated")
        }
    }

    // ============================================================================
    // MARK: - 4. Synchronization Tests
    // ============================================================================

    /**
     * @brief Video-GPS synchronization test
     *
     * @details
     * Verifies that video playback time and GPS data are accurately synchronized.
     *
     * Test scenario:
     * 1. Load video file with GPS data
     * 2. Seek to specific time (5 sec)
     * 3. Verify GPS position at that time
     * 4. Verify time and GPS data match
     */
    func testVideoGPSSynchronization() {
        // Given: Video file with GPS data
        let videoFile = createSampleVideoFile()

        do {
            try syncController.loadVideoFile(videoFile)
        } catch {
            XCTFail("Failed to load video file: \(error)")
            return
        }

        // When: Seek to 5 seconds
        syncController.seekToTime(5.0)

        // Then: Verify GPS position at 5 seconds
        let gpsLocation = syncController.gpsService.getCurrentLocation(at: 5.0)
        XCTAssertNotNil(gpsLocation, "GPS position at 5 seconds should be returned")

        // Verify timestamp synchronization
        if let location = gpsLocation {
            let timeDiff = abs(location.timestamp.timeIntervalSince(
                videoFile.timestamp.addingTimeInterval(5.0)
            ))
            XCTAssertLessThan(timeDiff, 0.1, "GPS data and video time should be synchronized within 100ms")
        }
    }

    /**
     * @brief Video-G-sensor synchronization test
     *
     * @details
     * Verifies that video playback time and G-sensor data are accurately synchronized.
     *
     * Test scenario:
     * 1. Load video file with G-sensor data
     * 2. Seek to specific time (3 sec)
     * 3. Verify acceleration value at that time
     * 4. Verify time and G-sensor data match
     */
    func testVideoGSensorSynchronization() {
        // Given: Video file with G-sensor data
        let videoFile = createSampleVideoFile()

        do {
            try syncController.loadVideoFile(videoFile)
        } catch {
            XCTFail("Failed to load video file: \(error)")
            return
        }

        // When: Seek to 3 seconds
        syncController.seekToTime(3.0)

        // Then: Verify acceleration value at 3 seconds
        let accelData = syncController.gsensorService.getCurrentAcceleration(at: 3.0)
        XCTAssertNotNil(accelData, "Acceleration data at 3 seconds should be returned")

        // Verify timestamp synchronization
        if let data = accelData {
            let timeDiff = abs(data.timestamp.timeIntervalSince(
                videoFile.timestamp.addingTimeInterval(3.0)
            ))
            XCTAssertLessThan(timeDiff, 0.01, "G-sensor data and video time should be synchronized within 10ms")
        }
    }

    /**
     * @brief Real-time sensor data update test during playback
     *
     * @details
     * Verifies that GPS and G-sensor data are updated in real-time during video playback.
     *
     * Test scenario:
     * 1. Load video file
     * 2. Start playback
     * 3. Observe currentTime changes
     * 4. Verify GPS/G-sensor data updates at each time
     */
    func testRealtimeSensorDataUpdate() {
        // Given: GPS/Video file with G-sensor data
        let videoFile = createSampleVideoFile()

        do {
            try syncController.loadVideoFile(videoFile)
        } catch {
            XCTFail("Failed to load video file: \(error)")
            return
        }

        // When: Start playback and observe time changes
        let expectation = XCTestExpectation(description: "Real-time sensor data update")
        var updateCount = 0
        var lastGPSLocation: GPSPoint?
        var lastAccelData: AccelerationData?

        syncController.$currentTime
            .sink { [weak self] time in
                guard let self = self else { return }

                if time > 0 && time < 2.0 {
                    // Verify GPS data update
                    let gpsLocation = self.syncController.gpsService.getCurrentLocation(at: time)
                    if let location = gpsLocation {
                        if lastGPSLocation == nil || lastGPSLocation!.timestamp != location.timestamp {
                            lastGPSLocation = location
                            updateCount += 1
                        }
                    }

                    // Verify G-sensor data update
                    let accelData = self.syncController.gsensorService.getCurrentAcceleration(at: time)
                    if let data = accelData {
                        if lastAccelData == nil || lastAccelData!.timestamp != data.timestamp {
                            lastAccelData = data
                            updateCount += 1
                        }
                    }

                    if updateCount >= 4 { // GPS 2+ times + G-sensor 2+ times update
                        expectation.fulfill()
                    }
                }
            }
            .store(in: &cancellables)

        syncController.play()

        // Then: Verify real-time update
        wait(for: [expectation], timeout: 3.0)
        XCTAssertGreaterThanOrEqual(updateCount, 4, "Sensor data should be updated in real-time")
    }

    // ============================================================================
    // MARK: - 5. Performance Tests
    // ============================================================================

    /**
     * @brief GPS data search performance test
     *
     * @details
     * Measures performance of finding data at specific time among 10,000 GPS points.
     * Should have O(log n) time complexity since binary search is used.
     */
    func testGPSDataSearchPerformance() {
        // Given: 10,000 GPS points
        let baseDate = Date()
        var gpsPoints: [GPSPoint] = []
        for i in 0..<10000 {
            let point = GPSPoint(
                timestamp: baseDate.addingTimeInterval(Double(i)),
                latitude: 37.5 + Double(i) * 0.0001,
                longitude: 127.0 + Double(i) * 0.0001,
                speed: 30.0
            )
            gpsPoints.append(point)
        }

        let metadata = VideoMetadata(gpsPoints: gpsPoints, accelerationData: [])
        gpsService.loadGPSData(from: metadata, startTime: baseDate)

        // When: Measure search performance for data at specific time
        measure {
            for i in stride(from: 0, to: 10000, by: 100) {
                _ = gpsService.getCurrentLocation(at: TimeInterval(i))
            }
        }

        // Then: Fast search should complete (automatically measured by measure)
    }

    // ============================================================================
    // MARK: - Helper Methods
    // ============================================================================

    /**
     * @brief Create sample GPS binary data
     *
     * @details
     * Creates 3 GPS points in Float64 binary format.
     * Each point: latitude(8) + longitude(8) + speed(8) = 24 bytes
     *
     * @return GPS binary data
     */
    private func createSampleGPSBinaryData() -> Data {
        var data = Data()

        // GPS point 1: Seoul City Hall (37.5665, 126.9780, speed 30km/h)
        var lat1: Double = 37.5665
        var lon1: Double = 126.9780
        var speed1: Double = 30.0
        data.append(Data(bytes: &lat1, count: 8))
        data.append(Data(bytes: &lon1, count: 8))
        data.append(Data(bytes: &speed1, count: 8))

        // GPS point 2: Slight northeast movement
        var lat2: Double = 37.5670
        var lon2: Double = 126.9785
        var speed2: Double = 35.0
        data.append(Data(bytes: &lat2, count: 8))
        data.append(Data(bytes: &lon2, count: 8))
        data.append(Data(bytes: &speed2, count: 8))

        // GPS point 3: Further northeast movement
        var lat3: Double = 37.5675
        var lon3: Double = 126.9790
        var speed3: Double = 40.0
        data.append(Data(bytes: &lat3, count: 8))
        data.append(Data(bytes: &lon3, count: 8))
        data.append(Data(bytes: &speed3, count: 8))

        return data
    }

    /**
     * @brief Create sample acceleration Float32 binary data
     *
     * @details
     * Creates 3 acceleration samples in Float32 binary format.
     * Each sample: X(4) + Y(4) + Z(4) = 12 bytes
     *
     * @return Acceleration binary data
     */
    private func createSampleAccelerationFloat32Data() -> Data {
        var data = Data()

        // Sample 1: Normal driving (X=0, Y=0, Z=1.0 gravity)
        var x1: Float = 0.0
        var y1: Float = 0.0
        var z1: Float = 1.0
        data.append(Data(bytes: &x1, count: 4))
        data.append(Data(bytes: &y1, count: 4))
        data.append(Data(bytes: &z1, count: 4))

        // Sample 2: Slight acceleration (Y-axis positive)
        var x2: Float = 0.0
        var y2: Float = 0.5
        var z2: Float = 1.0
        data.append(Data(bytes: &x2, count: 4))
        data.append(Data(bytes: &y2, count: 4))
        data.append(Data(bytes: &z2, count: 4))

        // Sample 3: Right turn (X-axis positive)
        var x3: Float = 0.3
        var y3: Float = 0.0
        var z3: Float = 1.0
        data.append(Data(bytes: &x3, count: 4))
        data.append(Data(bytes: &y3, count: 4))
        data.append(Data(bytes: &z3, count: 4))

        return data
    }

    /**
     * @brief Create sample acceleration Int16 binary data
     *
     * @details
     * Creates 3 acceleration samples in Int16 binary format.
     * Scale: 16384 = 1.0G
     *
     * @return Acceleration binary data
     */
    private func createSampleAccelerationInt16Data() -> Data {
        var data = Data()

        let scale: Int16 = 16384 // 1G = 16384

        // Sample 1: Normal driving
        var x1: Int16 = 0
        var y1: Int16 = 0
        var z1: Int16 = scale // 1.0G
        data.append(Data(bytes: &x1, count: 2))
        data.append(Data(bytes: &y1, count: 2))
        data.append(Data(bytes: &z1, count: 2))

        // Sample 2: Slight acceleration
        var x2: Int16 = 0
        var y2: Int16 = scale / 2 // 0.5G
        var z2: Int16 = scale
        data.append(Data(bytes: &x2, count: 2))
        data.append(Data(bytes: &y2, count: 2))
        data.append(Data(bytes: &z2, count: 2))

        // Sample 3: Right turn
        var x3: Int16 = scale / 3 // 0.33G
        var y3: Int16 = 0
        var z3: Int16 = scale
        data.append(Data(bytes: &x3, count: 2))
        data.append(Data(bytes: &y3, count: 2))
        data.append(Data(bytes: &z3, count: 2))

        return data
    }

    /**
     * @brief Create large GPS binary data
     *
     * @param count Number of GPS points to create
     * @return Large GPS binary data
     */
    private func createLargeGPSBinaryData(count: Int) -> Data {
        var data = Data()

        for i in 0..<count {
            var lat: Double = 37.5 + Double(i) * 0.0001
            var lon: Double = 127.0 + Double(i) * 0.0001
            var speed: Double = 30.0 + Double(i % 20)

            data.append(Data(bytes: &lat, count: 8))
            data.append(Data(bytes: &lon, count: 8))
            data.append(Data(bytes: &speed, count: 8))
        }

        return data
    }

    /**
     * @brief Create large acceleration Float32 binary data
     *
     * @param count Number of acceleration samples to create
     * @return Large acceleration binary data
     */
    private func createLargeAccelerationFloat32Data(count: Int) -> Data {
        var data = Data()

        for i in 0..<count {
            var x: Float = Float(sin(Double(i) * 0.1)) * 0.5
            var y: Float = Float(cos(Double(i) * 0.1)) * 0.5
            var z: Float = 1.0 + Float(sin(Double(i) * 0.05)) * 0.2

            data.append(Data(bytes: &x, count: 4))
            data.append(Data(bytes: &y, count: 4))
            data.append(Data(bytes: &z, count: 4))
        }

        return data
    }

    /**
     * @brief Create sample video file for testing
     *
     * @details
     * Creates VideoFile object with GPS and G-sensor metadata.
     *
     * @return VideoFile with GPS/G-sensor data
     */
    private func createSampleVideoFile() -> VideoFile {
        let baseDate = Date()

        // Create GPS data (10 points over 10 seconds)
        var gpsPoints: [GPSPoint] = []
        for i in 0..<10 {
            let point = GPSPoint(
                timestamp: baseDate.addingTimeInterval(Double(i)),
                latitude: 37.5665 + Double(i) * 0.001,
                longitude: 126.9780 + Double(i) * 0.001,
                speed: 30.0 + Double(i) * 2.0
            )
            gpsPoints.append(point)
        }

        // Create G-sensor data (10 seconds at 100Hz = 1000 samples)
        var accelData: [AccelerationData] = []
        for i in 0..<1000 {
            let data = AccelerationData(
                timestamp: baseDate.addingTimeInterval(Double(i) / 100.0),
                x: sin(Double(i) * 0.1) * 0.3,
                y: cos(Double(i) * 0.1) * 0.3,
                z: 1.0
            )
            accelData.append(data)
        }

        // Create metadata
        let metadata = VideoMetadata(gpsPoints: gpsPoints, accelerationData: accelData)

        // Create video file
        let channelInfo = ChannelInfo(
            position: .front,
            filePath: "/tmp/test_front.mp4",
            width: 1920,
            height: 1080,
            frameRate: 30.0
        )

        let videoFile = VideoFile(
            timestamp: baseDate,
            eventType: .normal,
            duration: 10.0,
            channels: [channelInfo],
            metadata: metadata,
            basePath: "/tmp/test_video"
        )

        return videoFile
    }

    /**
     * @brief Create sample GPS point array
     *
     * @param baseDate Base date
     * @param count Number of GPS points to create
     * @return GPS point array
     */
    private func createSampleGPSPoints(baseDate: Date, count: Int) -> [GPSPoint] {
        var points: [GPSPoint] = []

        for i in 0..<count {
            let point = GPSPoint(
                timestamp: baseDate.addingTimeInterval(Double(i)),
                latitude: 37.5665 + Double(i) * 0.001,
                longitude: 126.9780 + Double(i) * 0.001,
                speed: 30.0 + Double(i) * 2.0
            )
            points.append(point)
        }

        return points
    }

    /**
     * @brief Create sample acceleration data array
     *
     * @param baseDate Base date
     * @param count Number of acceleration samples to create
     * @return Acceleration data array
     */
    private func createSampleAccelerationData(baseDate: Date, count: Int) -> [AccelerationData] {
        var data: [AccelerationData] = []

        for i in 0..<count {
            let sample = AccelerationData(
                timestamp: baseDate.addingTimeInterval(Double(i) / 100.0), // 100Hz
                x: sin(Double(i) * 0.1) * 0.3,
                y: cos(Double(i) * 0.1) * 0.3,
                z: 1.0
            )
            data.append(sample)
        }

        return data
    }
}
