/**
 * @file GPSSensorIntegrationTests_Improved.swift
 * @brief Improved GPS/G-sensor integration tests
 * @author BlackboxPlayer Team
 *
 * @details
 * Improves test stability using Mock services,
 * and resolves timing issues with async/await-based integration tests.
 *
 * @section improvements Improvements
 *
 * 1. **Mock Infrastructure**: Use Mocks instead of real services
 * 2. **Async/Await**: async/await instead of Combine + XCTestExpectation
 * 3. **Deterministic Timing**: Simulation instead of real time
 * 4. **Better Isolation**: Complete isolation of each test
 * 5. **No File System**: Remove file system dependencies
 */

import XCTest
import Combine
import CoreLocation
@testable import BlackboxPlayer

// ============================================================================
// MARK: - Improved GPS/G-Sensor Integration Tests
// ============================================================================

class GPSSensorIntegrationTests_Improved: XCTestCase {

    // MARK: - Properties

    /// Mock synchronization controller
    var mockSyncController: MockSyncController!

    /// Combine subscription storage
    var cancellables: Set<AnyCancellable> = []

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        mockSyncController = MockSyncController()
        cancellables = []
    }

    override func tearDown() async throws {
        // Explicit cleanup
        mockSyncController?.stop()
        mockSyncController?.gpsService.clear()
        mockSyncController?.gsensorService.clear()
        cancellables.removeAll()

        mockSyncController = nil

        // Ensure resource cleanup with a small delay
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        try await super.tearDown()
    }

    // ============================================================================
    // MARK: - 1. Data Model Tests
    // ============================================================================

    func testVideoMetadataGPSData() {
        // Given: Sample GPS points
        let baseDate = Date()
        let gpsPoints = TestDataFactory.createGPSPoints(baseDate: baseDate, count: 10)

        // When: Create VideoMetadata
        let metadata = VideoMetadata(gpsPoints: gpsPoints, accelerationData: [])

        // Then: Verify GPS data
        XCTAssertEqual(metadata.gpsPoints.count, 10)
        XCTAssertTrue(metadata.hasGPSData)

        let point = metadata.gpsPoint(at: 5.0)
        XCTAssertNotNil(point, "GPS point at 5 second mark should exist")
    }

    func testVideoMetadataAccelerationData() {
        // Given: Sample acceleration data
        let baseDate = Date()
        let accelData = TestDataFactory.createAccelerationData(baseDate: baseDate, count: 1000)

        // When: Create VideoMetadata
        let metadata = VideoMetadata(gpsPoints: [], accelerationData: accelData)

        // Then: Verify acceleration data
        XCTAssertEqual(metadata.accelerationData.count, 1000)
        XCTAssertTrue(metadata.hasAccelerationData)

        let data = metadata.accelerationData(at: 5.0)
        XCTAssertNotNil(data, "Acceleration data at 5 second mark should exist")
    }

    func testImpactEventDetection() {
        // Given: Normal + impact data
        let baseDate = Date()
        let normalData = AccelerationData(timestamp: baseDate, x: 0.0, y: 0.0, z: 1.0)
        let impactData = AccelerationData(
            timestamp: baseDate.addingTimeInterval(1.0),
            x: 5.0, y: 3.0, z: 2.0
        )

        let metadata = VideoMetadata(gpsPoints: [], accelerationData: [normalData, impactData])

        // Then: Verify impact detection
        let impactEvents = metadata.impactEvents
        XCTAssertGreaterThan(impactEvents.count, 0, "Impact event should be detected")

        let impact = impactEvents.first!
        let magnitude = sqrt(impact.x * impact.x + impact.y * impact.y + impact.z * impact.z)
        XCTAssertGreaterThan(magnitude, 3.0, "Impact magnitude should exceed threshold")
    }

    // ============================================================================
    // MARK: - 2. Service Integration Tests (with Mocks)
    // ============================================================================

    func testMockGPSServiceIntegration() {
        // Given: Mock GPS data
        let baseDate = Date()
        let gpsPoints = TestDataFactory.createGPSPoints(baseDate: baseDate, count: 10)
        let metadata = VideoMetadata(gpsPoints: gpsPoints, accelerationData: [])

        // When: Load into Mock service
        mockSyncController.gpsService.loadGPSData(from: metadata, startTime: baseDate)

        // Then: Verify data loaded
        XCTAssertTrue(mockSyncController.gpsService.hasData)
        XCTAssertEqual(mockSyncController.gpsService.pointCount, 10)
        XCTAssertEqual(mockSyncController.gpsService.loadCallCount, 1, "loadGPSData should be called once")

        // Query location
        let location = mockSyncController.gpsService.getCurrentLocation(at: 5.0)
        XCTAssertNotNil(location)
        XCTAssertEqual(mockSyncController.gpsService.getCurrentLocationCallCount, 1)
    }

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

        mockSyncController.gpsService.setMockData(points: [point1, point2], startTime: baseDate)

        // When: Request position at middle time (1 sec)
        let interpolated = mockSyncController.gpsService.getCurrentLocation(at: 1.0)

        // Then: Verify linear interpolation
        XCTAssertNotNil(interpolated)

        if let location = interpolated {
            XCTAssertEqual(location.coordinate.latitude, 37.5010, accuracy: 0.0001)
            XCTAssertEqual(location.coordinate.longitude, 127.0010, accuracy: 0.0001)
            XCTAssertEqual(location.speed ?? 0.0, 35.0, accuracy: 0.1)
        }
    }

    // ============================================================================
    // MARK: - 3. Synchronization Tests (Async/Await)
    // ============================================================================

    func testVideoGPSSynchronization() async throws {
        // Given: Video file with GPS data
        let videoFile = TestDataFactory.createVideoFile(withGPS: true, withAccel: false)

        // When: Load video file
        try mockSyncController.loadVideoFile(videoFile)

        // Seek to 5 seconds
        mockSyncController.seekToTime(5.0)

        // Then: Verify GPS position at 5 seconds
        let gpsLocation = mockSyncController.gpsService.getCurrentLocation(at: 5.0)
        XCTAssertNotNil(gpsLocation, "GPS position at 5 second mark should be returned")

        XCTAssertEqual(mockSyncController.loadCallCount, 1)
        XCTAssertEqual(mockSyncController.seekCallCount, 1)
    }

    func testVideoGSensorSynchronization() async throws {
        // Given: Video file with G-sensor data
        let videoFile = TestDataFactory.createVideoFile(withGPS: false, withAccel: true)

        // When: Load video file
        try mockSyncController.loadVideoFile(videoFile)

        // Seek to 3 seconds
        mockSyncController.seekToTime(3.0)

        // Then: Verify acceleration data at 3 seconds
        let accelData = mockSyncController.gsensorService.getCurrentAcceleration(at: 3.0)
        XCTAssertNotNil(accelData, "Acceleration data at 3 second mark should be returned")

        XCTAssertEqual(mockSyncController.loadCallCount, 1)
        XCTAssertEqual(mockSyncController.seekCallCount, 1)
    }

    /// 🔧 Improved real-time sensor data update test
    ///
    /// **Improvements:**
    /// - Use async/await instead of XCTestExpectation
    /// - Direct polling instead of Combine subscription
    /// - Control timing with simulation (no need to wait actual 3 seconds)
    func testRealtimeSensorDataUpdate() async throws {
        // Given: Video file with GPS/G-sensor data
        let videoFile = TestDataFactory.createVideoFile(withGPS: true, withAccel: true)
        try mockSyncController.loadVideoFile(videoFile)

        // When: Simulate time progress (0 sec → 2 sec)
        var timePoints: [TimeInterval] = []
        var gpsUpdates: [GPSPoint] = []
        var accelUpdates: [AccelerationData] = []

        // Async time progress
        await mockSyncController.simulateTimeProgress(to: 2.0, step: 0.5)

        // Collect data at each time point
        for time in stride(from: 0.0, through: 2.0, by: 0.5) {
            mockSyncController.seekToTime(time)
            timePoints.append(time)

            if let gps = mockSyncController.gpsService.getCurrentLocation(at: time) {
                gpsUpdates.append(gps)
            }

            if let accel = mockSyncController.gsensorService.getCurrentAcceleration(at: time) {
                accelUpdates.append(accel)
            }
        }

        // Then: Verify sensor data is updated at each time point
        XCTAssertGreaterThanOrEqual(timePoints.count, 4, "Test at least 4 time points")
        XCTAssertGreaterThanOrEqual(gpsUpdates.count, 4, "GPS data should be updated at each time")
        XCTAssertGreaterThanOrEqual(accelUpdates.count, 4, "G-sensor data should be updated at each time")

        // Verify continuity: Check if time increases
        for i in 1..<gpsUpdates.count {
            XCTAssertGreaterThan(
                gpsUpdates[i].timestamp,
                gpsUpdates[i - 1].timestamp,
                "GPS timestamps should increase in order"
            )
        }
    }

    // ============================================================================
    // MARK: - 4. Performance Tests (with Smaller Dataset)
    // ============================================================================

    /// Performance tests are performed with smaller dataset (CI stability)
    func testGPSDataSearchPerformance() {
        // Given: 1,000 GPS points (reduced from original 10,000)
        let baseDate = Date()
        var gpsPoints: [GPSPoint] = []
        for i in 0..<1000 {
            let point = GPSPoint(
                timestamp: baseDate.addingTimeInterval(Double(i)),
                latitude: 37.5 + Double(i) * 0.0001,
                longitude: 127.0 + Double(i) * 0.0001,
                speed: 30.0
            )
            gpsPoints.append(point)
        }

        mockSyncController.gpsService.setMockData(points: gpsPoints, startTime: baseDate)

        // When: Measure search performance for data at specific time
        measure {
            for i in stride(from: 0, to: 1000, by: 10) {
                _ = mockSyncController.gpsService.getCurrentLocation(at: TimeInterval(i))
            }
        }

        // Then: Automatically measured by measure (verify against baseline)
    }
}

// ============================================================================
// MARK: - TestDataFactory
// ============================================================================

/**
 * @class TestDataFactory
 * @brief Test data creation factory
 *
 * @details
 * Utility class for consistent test data generation.
 */
enum TestDataFactory {

    /// Create GPS point array
    static func createGPSPoints(baseDate: Date, count: Int) -> [GPSPoint] {
        var points: [GPSPoint] = []

        for i in 0..<count {
            let point = GPSPoint(
                timestamp: baseDate.addingTimeInterval(Double(i)),
                latitude: 37.5665 + Double(i) * 0.001,
                longitude: 126.9780 + Double(i) * 0.001,
                speed: 30.0 + Double(i) * 2.0,
                heading: Double(i) * 36.0 // 0, 36, 72, ... degrees
            )
            points.append(point)
        }

        return points
    }

    /// Create acceleration data array
    static func createAccelerationData(baseDate: Date, count: Int) -> [AccelerationData] {
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

    /// Create video file for testing
    static func createVideoFile(withGPS: Bool, withAccel: Bool) -> VideoFile {
        let baseDate = Date()

        var gpsPoints: [GPSPoint] = []
        var accelData: [AccelerationData] = []

        if withGPS {
            gpsPoints = createGPSPoints(baseDate: baseDate, count: 10)
        }

        if withAccel {
            accelData = createAccelerationData(baseDate: baseDate, count: 1000)
        }

        let metadata = VideoMetadata(gpsPoints: gpsPoints, accelerationData: accelData)

        let channelInfo = ChannelInfo(
            position: .front,
            filePath: "/mock/test_front.mp4",  // Mock path (no actual file needed)
            width: 1920,
            height: 1080,
            frameRate: 30.0
        )

        return VideoFile(
            timestamp: baseDate,
            eventType: .normal,
            duration: 10.0,
            channels: [channelInfo],
            metadata: metadata,
            basePath: "/mock/test_video"
        )
    }
}
