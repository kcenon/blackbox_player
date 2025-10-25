/**
 * @file MockServices.swift
 * @brief Mock Service Implementation for Testing
 * @author BlackboxPlayer Team
 *
 * @details
 * Provides Mock services for use in integration tests.
 * Removes dependencies on actual services to improve test stability.
 */

import Foundation
import CoreLocation
import CoreVideo
import Combine
@testable import BlackboxPlayer

// ============================================================================
// MARK: - MockGPSService
// ============================================================================

/**
 * @class MockGPSService
 * @brief GPS Service Mock Implementation
 *
 * @details
 * A Mock service that operates with test data without loading actual GPS data.
 */
class MockGPSService: GPSService {

    // MARK: - Properties

    /// Mock GPS point storage
    private var mockGPSPoints: [GPSPoint] = []

    /// Start time
    private var mockStartTime = Date()

    /// Load call count (for test verification)
    var loadCallCount: Int = 0

    /// Get current location call count
    var getCurrentLocationCallCount: Int = 0

    // MARK: - Override Properties

    override var hasData: Bool {
        return !mockGPSPoints.isEmpty
    }

    override var pointCount: Int {
        return mockGPSPoints.count
    }

    override var routePoints: [GPSPoint] {
        return mockGPSPoints
    }

    // MARK: - Mock Methods

    override func loadGPSData(from metadata: VideoMetadata, startTime: Date) {
        loadCallCount += 1
        mockStartTime = startTime
        mockGPSPoints = metadata.gpsPoints
    }

    override func getCurrentLocation(at time: TimeInterval) -> GPSPoint? {
        getCurrentLocationCallCount += 1

        guard !mockGPSPoints.isEmpty else { return nil }

        let targetTime = mockStartTime.addingTimeInterval(time)

        // Find exactly matching point
        if let exactPoint = mockGPSPoints.first(where: { $0.timestamp == targetTime }) {
            return exactPoint
        }

        // Linear interpolation
        for i in 0..<mockGPSPoints.count - 1 {
            let p1 = mockGPSPoints[i]
            let p2 = mockGPSPoints[i + 1]

            if p1.timestamp <= targetTime && targetTime <= p2.timestamp {
                let ratio = targetTime.timeIntervalSince(p1.timestamp) / p2.timestamp.timeIntervalSince(p1.timestamp)

                let lat = p1.coordinate.latitude + (p2.coordinate.latitude - p1.coordinate.latitude) * ratio
                let lon = p1.coordinate.longitude + (p2.coordinate.longitude - p1.coordinate.longitude) * ratio
                let speed = (p1.speed ?? 0) + ((p2.speed ?? 0) - (p1.speed ?? 0)) * ratio

                return GPSPoint(
                    timestamp: targetTime,
                    latitude: lat,
                    longitude: lon,
                    speed: speed
                )
            }
        }

        // Return nearest point if out of range
        return mockGPSPoints.min(by: {
            abs($0.timestamp.timeIntervalSince(targetTime)) < abs($1.timestamp.timeIntervalSince(targetTime))
        })
    }

    override func clear() {
        mockGPSPoints.removeAll()
        loadCallCount = 0
        getCurrentLocationCallCount = 0
    }

    // MARK: - Test Helper Methods

    /// Set mock GPS data directly for testing
    func setMockData(points: [GPSPoint], startTime: Date) {
        mockGPSPoints = points
        mockStartTime = startTime
    }
}

// ============================================================================
// MARK: - MockGSensorService
// ============================================================================

/**
 * @class MockGSensorService
 * @brief G-Sensor Service Mock Implementation
 */
class MockGSensorService: GSensorService {

    // MARK: - Properties

    /// Mock acceleration data
    private var mockAccelData: [AccelerationData] = []

    /// Start time
    private var mockStartTime = Date()

    /// Load call count
    var loadCallCount: Int = 0

    /// Get current acceleration call count
    var getCurrentAccelerationCallCount: Int = 0

    // MARK: - Override Properties

    override var hasData: Bool {
        return !mockAccelData.isEmpty
    }

    // MARK: - Mock Methods

    override func loadAccelerationData(from metadata: VideoMetadata, startTime: Date) {
        loadCallCount += 1
        mockStartTime = startTime
        mockAccelData = metadata.accelerationData
    }

    override func getCurrentAcceleration(at time: TimeInterval) -> AccelerationData? {
        getCurrentAccelerationCallCount += 1

        guard !mockAccelData.isEmpty else { return nil }

        let targetTime = mockStartTime.addingTimeInterval(time)

        // Find nearest sample
        return mockAccelData.min(by: {
            abs($0.timestamp.timeIntervalSince(targetTime)) < abs($1.timestamp.timeIntervalSince(targetTime))
        })
    }

    override func clear() {
        mockAccelData.removeAll()
        loadCallCount = 0
        getCurrentAccelerationCallCount = 0
    }

    // MARK: - Test Helper Methods

    /// Set mock acceleration data directly for testing
    func setMockData(data: [AccelerationData], startTime: Date) {
        mockAccelData = data
        mockStartTime = startTime
    }
}

// ============================================================================
// MARK: - MockVideoDecoder
// ============================================================================

/**
 * @class MockVideoDecoder
 * @brief Video Decoder Mock Implementation
 *
 * @details
 * Generates test frames without actual video files.
 */
class MockVideoDecoder {

    // MARK: - Properties

    /// Mock video duration
    var duration: TimeInterval = 10.0

    /// FPS
    var fps: Double = 30.0

    /// Decode call count
    var decodeCallCount: Int = 0

    /// Seek call count
    var seekCallCount: Int = 0

    // MARK: - Methods

    /// Create mock frame
    func createMockFrame(at time: TimeInterval) -> VideoFrame? {
        decodeCallCount += 1

        guard time >= 0 && time <= duration else { return nil }

        // Generate mock frame data
        let width = 1920
        let height = 1080
        let bytesPerPixel = 4 // RGBA
        let lineSize = width * bytesPerPixel
        let dataSize = lineSize * height

        // Dummy pixel data (black)
        let dummyData = Data(count: dataSize)

        let frameNumber = Int(time * fps)

        return VideoFrame(
            timestamp: time,
            width: width,
            height: height,
            pixelFormat: .rgba,
            data: dummyData,
            lineSize: lineSize,
            frameNumber: frameNumber,
            isKeyFrame: frameNumber % 30 == 0 // Key frame every 30 frames
        )
    }

    func seek(to time: TimeInterval) {
        seekCallCount += 1
    }
}

// ============================================================================
// MARK: - MockSyncController
// ============================================================================

/**
 * @class MockSyncController
 * @brief Synchronization Controller Mock Implementation
 */
class MockSyncController {

    // MARK: - Properties

    /// Current playback time (Published)
    @Published var currentTime: TimeInterval = 0.0

    /// Playing status
    @Published var isPlaying: Bool = false

    /// GPS service
    var gpsService: MockGPSService

    /// G-sensor service
    var gsensorService: MockGSensorService

    /// Video file
    var videoFile: VideoFile?

    /// Load call count
    var loadCallCount: Int = 0

    /// Play call count
    var playCallCount: Int = 0

    /// Seek call count
    var seekCallCount: Int = 0

    // MARK: - Initialization

    init() {
        self.gpsService = MockGPSService()
        self.gsensorService = MockGSensorService()
    }

    // MARK: - Methods

    func loadVideoFile(_ file: VideoFile) throws {
        loadCallCount += 1
        videoFile = file

        let metadata = file.metadata
        gpsService.loadGPSData(from: metadata, startTime: file.timestamp)
        gsensorService.loadAccelerationData(from: metadata, startTime: file.timestamp)
    }

    func play() {
        playCallCount += 1
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        isPlaying = false
        currentTime = 0.0
    }

    func seekToTime(_ time: TimeInterval) {
        seekCallCount += 1
        currentTime = time
    }

    /// Simulate time progression for testing
    func simulateTimeProgress(to targetTime: TimeInterval, step: TimeInterval = 0.1) async {
        var time: TimeInterval = 0.0
        while time <= targetTime {
            currentTime = time
            try? await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
            time += step
        }
        currentTime = targetTime
    }
}
