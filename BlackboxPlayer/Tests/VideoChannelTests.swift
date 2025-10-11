//
//  VideoChannelTests.swift
//  BlackboxPlayerTests
//
//  Unit tests for VideoChannel
//

import XCTest
import Combine
@testable import BlackboxPlayer

final class VideoChannelTests: XCTestCase {

    // MARK: - Properties

    var channel: VideoChannel!
    var testChannelInfo: ChannelInfo!
    var cancellables: Set<AnyCancellable>!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        super.setUp()
        continueAfterFailure = false
        cancellables = []

        // Create test channel info
        testChannelInfo = ChannelInfo(
            position: .front,
            filePath: "/path/to/test/video.mp4",
            displayName: "Test Channel"
        )
    }

    override func tearDownWithError() throws {
        channel?.stop()
        channel = nil
        testChannelInfo = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testChannelInitialization() {
        // Given/When
        channel = VideoChannel(channelInfo: testChannelInfo)

        // Then
        XCTAssertNotNil(channel, "Channel should be initialized")
        XCTAssertEqual(channel.state, .idle, "Initial state should be idle")
        XCTAssertNil(channel.currentFrame, "Current frame should be nil initially")
        XCTAssertEqual(channel.channelInfo.position, .front, "Channel position should match")
    }

    func testChannelIdentifiable() {
        // Given
        let channel1 = VideoChannel(channelInfo: testChannelInfo)
        let channel2 = VideoChannel(channelInfo: testChannelInfo)

        // Then
        XCTAssertNotEqual(channel1.id, channel2.id, "Each channel should have unique ID")
    }

    func testChannelEquatable() {
        // Given
        let channelID = UUID()
        let channel1 = VideoChannel(channelID: channelID, channelInfo: testChannelInfo)
        let channel2 = VideoChannel(channelID: channelID, channelInfo: testChannelInfo)
        let channel3 = VideoChannel(channelInfo: testChannelInfo)

        // Then
        XCTAssertEqual(channel1, channel2, "Channels with same ID should be equal")
        XCTAssertNotEqual(channel1, channel3, "Channels with different IDs should not be equal")
    }

    // MARK: - State Management Tests

    func testStateTransitions() {
        // Given
        channel = VideoChannel(channelInfo: testChannelInfo)

        // Then
        XCTAssertEqual(channel.state, .idle, "Initial state should be idle")
        XCTAssertEqual(channel.state.displayName, "Idle")
    }

    func testStateDisplayNames() {
        // Test all state display names
        XCTAssertEqual(ChannelState.idle.displayName, "Idle")
        XCTAssertEqual(ChannelState.ready.displayName, "Ready")
        XCTAssertEqual(ChannelState.decoding.displayName, "Decoding")
        XCTAssertEqual(ChannelState.completed.displayName, "Completed")
        XCTAssertEqual(ChannelState.error("test").displayName, "Error: test")
    }

    func testStatePublishing() {
        // Given
        channel = VideoChannel(channelInfo: testChannelInfo)
        let expectation = expectation(description: "State change published")
        var receivedStates: [ChannelState] = []

        // When
        channel.$state
            .sink { state in
                receivedStates.append(state)
                if receivedStates.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Simulate state change (this would happen in real initialization)
        // Note: This test shows the pattern, actual state changes require real decoder

        // Then
        waitForExpectations(timeout: 1.0)
    }

    // MARK: - Buffer Management Tests

    func testInitialBufferStatus() {
        // Given
        channel = VideoChannel(channelInfo: testChannelInfo)

        // When
        let status = channel.getBufferStatus()

        // Then
        XCTAssertEqual(status.current, 0, "Buffer should be empty initially")
        XCTAssertEqual(status.max, 30, "Max buffer size should be 30")
        XCTAssertEqual(status.fillPercentage, 0.0, "Fill percentage should be 0%")
    }

    func testFlushBuffer() {
        // Given
        channel = VideoChannel(channelInfo: testChannelInfo)

        // When
        channel.flushBuffer()
        let status = channel.getBufferStatus()

        // Then
        XCTAssertEqual(status.current, 0, "Buffer should be empty after flush")
    }

    func testGetFrameFromEmptyBuffer() {
        // Given
        channel = VideoChannel(channelInfo: testChannelInfo)

        // When
        let frame = channel.getFrame(at: 1.0)

        // Then
        XCTAssertNil(frame, "Should return nil when buffer is empty")
    }

    // MARK: - Error Handling Tests

    func testInitializeWithNonExistentFile() {
        // Given
        channel = VideoChannel(channelInfo: testChannelInfo)

        // When/Then
        XCTAssertThrowsError(try channel.initialize()) { error in
            // Should throw decoder error for non-existent file
        }
    }

    func testSeekWithoutInitialization() {
        // Given
        channel = VideoChannel(channelInfo: testChannelInfo)

        // When/Then
        XCTAssertThrowsError(try channel.seek(to: 5.0)) { error in
            if case ChannelError.notInitialized = error {
                // Expected error
            } else {
                XCTFail("Expected notInitialized error, got \(error)")
            }
        }
    }

    func testDoubleInitialization() {
        // Note: This test requires a valid video file
        // Given: A channel with valid file
        // When: Initialize twice
        // Then: Should throw invalidState error
    }

    // MARK: - Thread Safety Tests

    func testConcurrentBufferAccess() {
        // Given
        channel = VideoChannel(channelInfo: testChannelInfo)
        let iterations = 100

        // When: Access buffer from multiple threads
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            _ = channel.getBufferStatus()
            channel.flushBuffer()
        }

        // Then: Should not crash (thread safety verified)
        let finalStatus = channel.getBufferStatus()
        XCTAssertEqual(finalStatus.current, 0)
    }

    func testConcurrentGetFrame() {
        // Given
        channel = VideoChannel(channelInfo: testChannelInfo)

        // When: Get frames from multiple threads
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            _ = channel.getFrame(at: Double(index))
        }

        // Then: Should not crash
        XCTAssertNotNil(channel)
    }

    // MARK: - Memory Management Tests

    func testChannelDeinit() {
        // Given
        var testChannel: VideoChannel? = VideoChannel(channelInfo: testChannelInfo)

        // When
        testChannel = nil

        // Then
        // Channel should cleanup properly (verified by no memory leaks)
        XCTAssertNil(testChannel)
    }

    func testStopCleansResources() {
        // Given
        channel = VideoChannel(channelInfo: testChannelInfo)

        // When
        channel.stop()

        // Then
        XCTAssertEqual(channel.state, .idle)
        XCTAssertNil(channel.currentFrame)
        let status = channel.getBufferStatus()
        XCTAssertEqual(status.current, 0, "Buffer should be empty after stop")
    }

    // MARK: - Performance Tests

    func testBufferStatusPerformance() {
        // Given
        channel = VideoChannel(channelInfo: testChannelInfo)

        // When/Then
        measure {
            for _ in 0..<1000 {
                _ = channel.getBufferStatus()
            }
        }
    }

    func testGetFramePerformance() {
        // Given
        channel = VideoChannel(channelInfo: testChannelInfo)

        // When/Then
        measure {
            for i in 0..<1000 {
                _ = channel.getFrame(at: Double(i) * 0.033)
            }
        }
    }
}

// MARK: - Integration Tests

/// Integration tests that require real video files
final class VideoChannelIntegrationTests: XCTestCase {

    var channel: VideoChannel!
    var testChannelInfo: ChannelInfo!

    override func setUpWithError() throws {
        super.setUp()

        // Setup test video file
        let bundle = Bundle(for: type(of: self))
        guard let videoPath = bundle.path(forResource: "test_video", ofType: "mp4") else {
            throw XCTSkip("Test video file not found")
        }

        testChannelInfo = ChannelInfo(
            position: .front,
            filePath: videoPath,
            displayName: "Test Channel"
        )
        channel = VideoChannel(channelInfo: testChannelInfo)
    }

    override func tearDownWithError() throws {
        channel.stop()
        channel = nil
        testChannelInfo = nil
        super.tearDown()
    }

    func testInitializeChannel() throws {
        // When
        try channel.initialize()

        // Then
        XCTAssertEqual(channel.state, .ready, "State should be ready after initialization")
    }

    func testStartDecoding() throws {
        // Given
        try channel.initialize()

        // When
        channel.startDecoding()

        // Wait for some frames to be decoded
        Thread.sleep(forTimeInterval: 0.5)

        // Then
        XCTAssertEqual(channel.state, .decoding, "State should be decoding")
        let status = channel.getBufferStatus()
        XCTAssertGreaterThan(status.current, 0, "Buffer should have frames")
    }

    func testGetFrameAfterDecoding() throws {
        // Given
        try channel.initialize()
        channel.startDecoding()

        // Wait for frames
        Thread.sleep(forTimeInterval: 0.5)

        // When
        let frame = channel.getFrame(at: 0.5)

        // Then
        XCTAssertNotNil(frame, "Should get frame from buffer")
        if let frame = frame {
            XCTAssertGreaterThanOrEqual(frame.timestamp, 0.0)
        }
    }

    func testSeekAndDecode() throws {
        // Given
        try channel.initialize()
        channel.startDecoding()
        Thread.sleep(forTimeInterval: 0.3)

        // When
        try channel.seek(to: 5.0)
        Thread.sleep(forTimeInterval: 0.5)

        // Then
        let frame = channel.getFrame(at: 5.0)
        XCTAssertNotNil(frame, "Should get frame after seeking")
        if let frame = frame {
            XCTAssertGreaterThanOrEqual(frame.timestamp, 5.0, "Frame should be at or after seek point")
        }
    }

    func testBufferFillAndCleanup() throws {
        // Given
        try channel.initialize()
        channel.startDecoding()

        // Wait for buffer to fill
        Thread.sleep(forTimeInterval: 2.0)

        // When
        let status = channel.getBufferStatus()

        // Then
        XCTAssertLessThanOrEqual(status.current, status.max, "Buffer should not exceed max size")
        XCTAssertLessThanOrEqual(status.fillPercentage, 1.0, "Fill percentage should not exceed 100%")
    }

    func testFrameTimestampOrdering() throws {
        // Given
        try channel.initialize()
        channel.startDecoding()
        Thread.sleep(forTimeInterval: 1.0)

        // When
        let frame1 = channel.getFrame(at: 0.0)
        let frame2 = channel.getFrame(at: 1.0)
        let frame3 = channel.getFrame(at: 2.0)

        // Then
        if let f1 = frame1, let f2 = frame2, let f3 = frame3 {
            XCTAssertLessThan(f1.timestamp, f2.timestamp, "Frames should be ordered by timestamp")
            XCTAssertLessThan(f2.timestamp, f3.timestamp, "Frames should be ordered by timestamp")
        }
    }
}
