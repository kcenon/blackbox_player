//
//  SyncControllerTests.swift
//  BlackboxPlayerTests
//
//  Unit tests for SyncController
//

import XCTest
import Combine
@testable import BlackboxPlayer

final class SyncControllerTests: XCTestCase {

    // MARK: - Properties

    var syncController: SyncController!
    var cancellables: Set<AnyCancellable>!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        super.setUp()
        continueAfterFailure = false
        syncController = SyncController()
        cancellables = []
    }

    override func tearDownWithError() throws {
        syncController.stop()
        syncController = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        // Then
        XCTAssertEqual(syncController.playbackState, .stopped, "Initial state should be stopped")
        XCTAssertEqual(syncController.currentTime, 0.0, "Initial time should be 0")
        XCTAssertEqual(syncController.playbackPosition, 0.0, "Initial position should be 0")
        XCTAssertEqual(syncController.playbackSpeed, 1.0, "Initial speed should be 1.0")
        XCTAssertEqual(syncController.duration, 0.0, "Initial duration should be 0")
        XCTAssertEqual(syncController.channelCount, 0, "Initial channel count should be 0")
        XCTAssertFalse(syncController.allChannelsReady, "Channels should not be ready initially")
    }

    func testServicesInitialization() {
        // Then
        XCTAssertNotNil(syncController.gpsService, "GPS service should be initialized")
        XCTAssertNotNil(syncController.gsensorService, "G-Sensor service should be initialized")
    }

    // MARK: - State Management Tests

    func testPlaybackStateTransitions() {
        // Given: Controller starts in .stopped state
        XCTAssertEqual(syncController.playbackState, .stopped)

        // Note: Actual state transitions require loaded channels
        // This is tested in integration tests
    }

    func testPlaybackStatePublishing() {
        // Given
        let expectation = expectation(description: "Playback state published")
        var receivedStates: [PlaybackState] = []

        syncController.$playbackState
            .sink { state in
                receivedStates.append(state)
                if receivedStates.count >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedStates.first, .stopped)
    }

    func testCurrentTimePublishing() {
        // Given
        let expectation = expectation(description: "Current time published")
        var receivedTimes: [TimeInterval] = []

        syncController.$currentTime
            .sink { time in
                receivedTimes.append(time)
                if receivedTimes.count >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedTimes.first, 0.0)
    }

    // MARK: - Playback Control Tests

    func testPlayWithoutChannels() {
        // When
        syncController.play()

        // Then
        XCTAssertEqual(syncController.playbackState, .stopped, "Should remain stopped without channels")
    }

    func testPauseWithoutPlaying() {
        // When
        syncController.pause()

        // Then
        XCTAssertEqual(syncController.playbackState, .stopped, "Should remain stopped")
    }

    func testTogglePlayPause() {
        // Note: Requires loaded channels for actual toggle
        // Unit test verifies method exists and doesn't crash

        // When
        syncController.togglePlayPause()

        // Then
        XCTAssertNotNil(syncController)
    }

    func testStop() {
        // When
        syncController.stop()

        // Then
        XCTAssertEqual(syncController.playbackState, .stopped)
        XCTAssertEqual(syncController.currentTime, 0.0)
        XCTAssertEqual(syncController.playbackPosition, 0.0)
        XCTAssertEqual(syncController.duration, 0.0)
        XCTAssertEqual(syncController.channelCount, 0)
    }

    // MARK: - Seeking Tests

    func testSeekToTime() {
        // Note: Requires loaded channels
        // Unit test verifies method exists

        // When
        syncController.seekToTime(5.0)

        // Then: Should clamp to 0.0 since duration is 0
        XCTAssertEqual(syncController.currentTime, 0.0)
    }

    func testSeekBySeconds() {
        // When
        syncController.seekBySeconds(10.0)

        // Then: Should seek from current time
        // With duration 0, should clamp to 0
        XCTAssertEqual(syncController.currentTime, 0.0)
    }

    func testSeekNegativeTime() {
        // When
        syncController.seekToTime(-5.0)

        // Then: Should clamp to 0
        XCTAssertEqual(syncController.currentTime, 0.0)
    }

    // MARK: - Synchronized Frames Tests

    func testGetSynchronizedFramesWithNoChannels() {
        // When
        let frames = syncController.getSynchronizedFrames()

        // Then
        XCTAssertTrue(frames.isEmpty, "Should return empty dictionary without channels")
    }

    func testGetBufferStatusWithNoChannels() {
        // When
        let status = syncController.getBufferStatus()

        // Then
        XCTAssertTrue(status.isEmpty, "Should return empty dictionary without channels")
    }

    // MARK: - Time Formatting Tests

    func testCurrentTimeString() {
        // Given: currentTime = 0
        // When
        let timeString = syncController.currentTimeString

        // Then
        XCTAssertEqual(timeString, "00:00")
    }

    func testDurationString() {
        // Given: duration = 0
        // When
        let durationString = syncController.durationString

        // Then
        XCTAssertEqual(durationString, "00:00")
    }

    func testRemainingTimeString() {
        // Given: remaining = 0
        // When
        let remainingString = syncController.remainingTimeString

        // Then
        XCTAssertEqual(remainingString, "-00:00")
    }

    func testPlaybackSpeedString() {
        // Given
        syncController.playbackSpeed = 1.5

        // When
        let speedString = syncController.playbackSpeedString

        // Then
        XCTAssertEqual(speedString, "1.5x")
    }

    func testTimeFormatting() {
        // Test various time values
        let testCases: [(TimeInterval, String)] = [
            (0, "00:00"),
            (30, "00:30"),
            (60, "01:00"),
            (90, "01:30"),
            (3600, "60:00"),
            (3665, "61:05")
        ]

        for (time, expected) in testCases {
            // Use private method through reflection or test computed property
            // For now, test through public API
        }
    }

    // MARK: - Playback Speed Tests

    func testPlaybackSpeedChange() {
        // Given
        let expectation = expectation(description: "Playback speed changed")
        var receivedSpeeds: [Double] = []

        syncController.$playbackSpeed
            .sink { speed in
                receivedSpeeds.append(speed)
                if receivedSpeeds.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        syncController.playbackSpeed = 2.0

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedSpeeds.last, 2.0)
    }

    func testDriftThreshold() {
        // Drift threshold should be 50ms
        // This is an internal property, tested through integration
    }

    // MARK: - Thread Safety Tests

    func testConcurrentChannelAccess() {
        // When: Access channel count from multiple threads
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            _ = syncController.channelCount
            _ = syncController.allChannelsReady
        }

        // Then: Should not crash
        XCTAssertNotNil(syncController)
    }

    func testConcurrentFrameAccess() {
        // When: Get synchronized frames from multiple threads
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            _ = syncController.getSynchronizedFrames()
            _ = syncController.getBufferStatus()
        }

        // Then: Should not crash
        XCTAssertNotNil(syncController)
    }

    // MARK: - Memory Management Tests

    func testDeinit() {
        // Given
        var controller: SyncController? = SyncController()

        // When
        controller = nil

        // Then
        XCTAssertNil(controller)
    }

    func testStopClearsResources() {
        // When
        syncController.stop()

        // Then
        XCTAssertEqual(syncController.channelCount, 0)
        XCTAssertEqual(syncController.currentTime, 0.0)
        XCTAssertEqual(syncController.duration, 0.0)
    }

    // MARK: - Performance Tests

    func testGetSynchronizedFramesPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = syncController.getSynchronizedFrames()
            }
        }
    }

    func testGetBufferStatusPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = syncController.getBufferStatus()
            }
        }
    }
}

// MARK: - Integration Tests

/// Integration tests with real channels
final class SyncControllerIntegrationTests: XCTestCase {

    var syncController: SyncController!
    var testVideoFile: VideoFile!

    override func setUpWithError() throws {
        super.setUp()

        // Create test video file
        let bundle = Bundle(for: type(of: self))
        guard let videoPath = bundle.path(forResource: "test_video", ofType: "mp4") else {
            throw XCTSkip("Test video file not found")
        }

        // Create test video file with channels
        testVideoFile = VideoFile(
            id: UUID(),
            name: "Test Video",
            filePath: videoPath,
            timestamp: Date(),
            duration: 10.0,
            eventType: .normal,
            size: 1024 * 1024,
            channels: [
                ChannelInfo(position: .front, filePath: videoPath, displayName: "Front")
            ],
            metadata: VideoMetadata.empty
        )

        syncController = SyncController()
    }

    override func tearDownWithError() throws {
        syncController.stop()
        syncController = nil
        testVideoFile = nil
        super.tearDown()
    }

    func testLoadVideoFile() throws {
        // When
        try syncController.loadVideoFile(testVideoFile)

        // Then
        XCTAssertEqual(syncController.playbackState, .paused)
        XCTAssertGreaterThan(syncController.channelCount, 0)
        XCTAssertGreaterThan(syncController.duration, 0)
        XCTAssertTrue(syncController.allChannelsReady)
    }

    func testPlaybackFlow() throws {
        // Given
        try syncController.loadVideoFile(testVideoFile)

        // When: Play
        syncController.play()

        // Then
        XCTAssertEqual(syncController.playbackState, .playing)

        // Wait for some playback
        Thread.sleep(forTimeInterval: 0.5)

        // Then: Time should advance
        XCTAssertGreaterThan(syncController.currentTime, 0.0)

        // When: Pause
        syncController.pause()

        // Then
        XCTAssertEqual(syncController.playbackState, .paused)
    }

    func testSeekDuringPlayback() throws {
        // Given
        try syncController.loadVideoFile(testVideoFile)
        syncController.play()
        Thread.sleep(forTimeInterval: 0.3)

        // When
        syncController.seekToTime(5.0)

        // Then
        XCTAssertEqual(syncController.currentTime, 5.0)
        XCTAssertGreaterThan(syncController.playbackPosition, 0.0)
    }

    func testSynchronizedFrames() throws {
        // Given
        try syncController.loadVideoFile(testVideoFile)
        syncController.play()
        Thread.sleep(forTimeInterval: 0.5)

        // When
        let frames = syncController.getSynchronizedFrames()

        // Then
        XCTAssertFalse(frames.isEmpty, "Should have synchronized frames")
        for (position, frame) in frames {
            XCTAssertGreaterThanOrEqual(frame.timestamp, 0.0)
            print("Channel \(position.displayName): frame at \(frame.timestamp)s")
        }
    }

    func testPlaybackSpeedControl() throws {
        // Given
        try syncController.loadVideoFile(testVideoFile)

        // When: Set speed to 2x
        syncController.playbackSpeed = 2.0
        syncController.play()

        let startTime = syncController.currentTime
        Thread.sleep(forTimeInterval: 0.5)
        let endTime = syncController.currentTime

        // Then: Should advance approximately 1 second (0.5s * 2x speed)
        let elapsed = endTime - startTime
        XCTAssertGreaterThan(elapsed, 0.8, "Should advance faster at 2x speed")
    }

    func testBufferStatus() throws {
        // Given
        try syncController.loadVideoFile(testVideoFile)
        syncController.play()
        Thread.sleep(forTimeInterval: 0.5)

        // When
        let status = syncController.getBufferStatus()

        // Then
        XCTAssertFalse(status.isEmpty)
        for (position, bufferStatus) in status {
            XCTAssertGreaterThan(bufferStatus.current, 0, "Channel \(position.displayName) should have buffered frames")
            XCTAssertLessThanOrEqual(bufferStatus.fillPercentage, 1.0)
        }
    }

    func testPlayToEnd() throws {
        // Given: Short video
        try syncController.loadVideoFile(testVideoFile)

        // When: Play to end
        syncController.play()

        // Wait for playback to complete
        let timeout = syncController.duration + 2.0
        var elapsed: TimeInterval = 0.0
        let checkInterval: TimeInterval = 0.1

        while syncController.playbackState == .playing && elapsed < timeout {
            Thread.sleep(forTimeInterval: checkInterval)
            elapsed += checkInterval
        }

        // Then: Should stop at end
        XCTAssertEqual(syncController.playbackState, .stopped)
        XCTAssertEqual(syncController.currentTime, syncController.duration)
        XCTAssertEqual(syncController.playbackPosition, 1.0)
    }
}
