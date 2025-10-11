//
//  VideoDecoderTests.swift
//  BlackboxPlayerTests
//
//  Unit tests for VideoDecoder
//

import XCTest
@testable import BlackboxPlayer

final class VideoDecoderTests: XCTestCase {

    // MARK: - Properties

    var testVideoPath: String!
    var decoder: VideoDecoder!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        super.setUp()
        continueAfterFailure = false

        // Create a test video path
        // Note: In real tests, you would use a actual test video file
        testVideoPath = "/path/to/test/video.mp4"
    }

    override func tearDownWithError() throws {
        decoder = nil
        testVideoPath = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testDecoderInitialization() {
        // Given
        decoder = VideoDecoder(filePath: testVideoPath)

        // Then
        XCTAssertNotNil(decoder, "Decoder should be initialized")
        XCTAssertFalse(decoder.isInitialized, "Decoder should not be initialized before calling initialize()")
        XCTAssertNil(decoder.videoInfo, "Video info should be nil before initialization")
        XCTAssertNil(decoder.audioInfo, "Audio info should be nil before initialization")
    }

    func testInitializeWithNonExistentFile() {
        // Given
        decoder = VideoDecoder(filePath: "/nonexistent/file.mp4")

        // When/Then
        XCTAssertThrowsError(try decoder.initialize()) { error in
            if case DecoderError.cannotOpenFile = error {
                // Expected error
            } else {
                XCTFail("Expected cannotOpenFile error, got \(error)")
            }
        }
    }

    func testDoubleInitialization() throws {
        // Given: A decoder with a valid file (mocked)
        // Note: This test would require a valid video file
        // For now, we test the error path

        // When/Then
        // XCTAssertThrowsError on already initialized decoder
    }

    // MARK: - Decoding Tests

    func testDecodeNextFrameWithoutInitialization() {
        // Given
        decoder = VideoDecoder(filePath: testVideoPath)

        // When/Then
        XCTAssertThrowsError(try decoder.decodeNextFrame()) { error in
            if case DecoderError.notInitialized = error {
                // Expected error
            } else {
                XCTFail("Expected notInitialized error, got \(error)")
            }
        }
    }

    func testDecodeVideoFrame() {
        // Note: This test requires a real video file
        // Integration test: decoder should decode video frames successfully
    }

    func testDecodeAudioFrame() {
        // Note: This test requires a real video file with audio
        // Integration test: decoder should decode audio frames successfully
    }

    func testDecodeUntilEOF() {
        // Note: This test requires a real video file
        // Integration test: decoder should return nil at end of file
    }

    // MARK: - Seeking Tests

    func testSeekWithoutInitialization() {
        // Given
        decoder = VideoDecoder(filePath: testVideoPath)

        // When/Then
        XCTAssertThrowsError(try decoder.seek(to: 5.0)) { error in
            if case DecoderError.notInitialized = error {
                // Expected error
            } else {
                XCTFail("Expected notInitialized error, got \(error)")
            }
        }
    }

    func testSeekToValidTimestamp() {
        // Note: This test requires a real video file
        // Integration test: decoder should seek to valid timestamp
    }

    func testSeekToNegativeTimestamp() {
        // Note: This test requires a real video file
        // Integration test: seeking to negative timestamp should handle gracefully
    }

    func testSeekBeyondDuration() {
        // Note: This test requires a real video file
        // Integration test: seeking beyond duration should handle gracefully
    }

    // MARK: - Duration Tests

    func testGetDurationWithoutInitialization() {
        // Given
        decoder = VideoDecoder(filePath: testVideoPath)

        // When
        let duration = decoder.getDuration()

        // Then
        XCTAssertNil(duration, "Duration should be nil when decoder is not initialized")
    }

    func testGetDurationWithValidFile() {
        // Note: This test requires a real video file
        // Integration test: decoder should return valid duration
    }

    // MARK: - Error Handling Tests

    func testHandleCorruptedFile() {
        // Note: This test requires a corrupted video file
        // Integration test: decoder should throw appropriate error for corrupted files
    }

    func testHandleInvalidCodec() {
        // Note: This test requires a video file with unsupported codec
        // Integration test: decoder should throw codecNotFound error
    }

    // MARK: - Memory Management Tests

    func testCleanupOnDeinit() {
        // Given
        decoder = VideoDecoder(filePath: testVideoPath)

        // When
        decoder = nil

        // Then
        // Decoder should cleanup resources properly
        // This is verified by no memory leaks in Instruments
    }

    func testMultipleDecodersSimultaneously() {
        // Note: This test requires a real video file
        // Integration test: multiple decoders should work independently
    }

    // MARK: - Performance Tests

    func testDecodingPerformance() {
        // Note: This test requires a real video file
        // Performance test: measure time to decode frames
        measure {
            // Decode 100 frames and measure performance
        }
    }

    func testSeekingPerformance() {
        // Note: This test requires a real video file
        // Performance test: measure time to seek
        measure {
            // Perform multiple seeks and measure performance
        }
    }
}

// MARK: - Integration Tests

/// Integration tests that require real video files
/// These tests should be run separately with actual video files
final class VideoDecoderIntegrationTests: XCTestCase {

    var decoder: VideoDecoder!
    var testVideoPath: String!

    override func setUpWithError() throws {
        super.setUp()

        // Setup test video file path
        // This should point to a real test video file
        let bundle = Bundle(for: type(of: self))
        guard let videoPath = bundle.path(forResource: "test_video", ofType: "mp4") else {
            throw XCTSkip("Test video file not found. Add test_video.mp4 to test bundle.")
        }
        testVideoPath = videoPath
        decoder = VideoDecoder(filePath: testVideoPath)
    }

    override func tearDownWithError() throws {
        decoder = nil
        testVideoPath = nil
        super.tearDown()
    }

    func testInitializeWithValidFile() throws {
        // When
        try decoder.initialize()

        // Then
        XCTAssertTrue(decoder.isInitialized, "Decoder should be initialized")
        XCTAssertNotNil(decoder.videoInfo, "Video info should be available")

        let videoInfo = try XCTUnwrap(decoder.videoInfo)
        XCTAssertGreaterThan(videoInfo.width, 0, "Video width should be positive")
        XCTAssertGreaterThan(videoInfo.height, 0, "Video height should be positive")
        XCTAssertGreaterThan(videoInfo.frameRate, 0, "Frame rate should be positive")
    }

    func testDecodeMultipleFrames() throws {
        // Given
        try decoder.initialize()

        // When
        var frameCount = 0
        var videoFrameCount = 0
        var audioFrameCount = 0

        while let frames = try decoder.decodeNextFrame() {
            if frames.video != nil {
                videoFrameCount += 1
            }
            if frames.audio != nil {
                audioFrameCount += 1
            }
            frameCount += 1

            // Decode only 100 frames for this test
            if frameCount >= 100 {
                break
            }
        }

        // Then
        XCTAssertGreaterThan(videoFrameCount, 0, "Should decode at least one video frame")
        print("Decoded \(videoFrameCount) video frames and \(audioFrameCount) audio frames")
    }

    func testSeekAndDecode() throws {
        // Given
        try decoder.initialize()

        // When
        try decoder.seek(to: 5.0)
        let frames = try decoder.decodeNextFrame()

        // Then
        XCTAssertNotNil(frames, "Should be able to decode after seeking")
        if let videoFrame = frames?.video {
            XCTAssertGreaterThanOrEqual(videoFrame.timestamp, 5.0, "Frame timestamp should be at or after seek point")
        }
    }

    func testGetDuration() throws {
        // Given
        try decoder.initialize()

        // When
        let duration = decoder.getDuration()

        // Then
        let unwrappedDuration = try XCTUnwrap(duration)
        XCTAssertGreaterThan(unwrappedDuration, 0, "Duration should be positive")
        print("Video duration: \(unwrappedDuration) seconds")
    }
}
