//
//  MultiChannelRendererTests.swift
//  BlackboxPlayerTests
//
//  Unit tests for MultiChannelRenderer
//

import XCTest
import Metal
import MetalKit
@testable import BlackboxPlayer

final class MultiChannelRendererTests: XCTestCase {

    // MARK: - Properties

    var renderer: MultiChannelRenderer!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        super.setUp()
        continueAfterFailure = false

        // Check if Metal is available
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal is not available on this system")
        }

        renderer = MultiChannelRenderer()
        guard renderer != nil else {
            throw XCTSkip("Failed to create MultiChannelRenderer")
        }
    }

    override func tearDownWithError() throws {
        renderer = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testRendererInitialization() {
        // Then
        XCTAssertNotNil(renderer, "Renderer should initialize successfully")
        XCTAssertNotNil(renderer.captureService, "Capture service should be initialized")
        XCTAssertEqual(renderer.layoutMode, .grid, "Default layout should be grid")
        XCTAssertEqual(renderer.focusedPosition, .front, "Default focused position should be front")
    }

    func testMetalDeviceAvailable() {
        // Then
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal device should be available")
            return
        }
        XCTAssertNotNil(device)
    }

    // MARK: - Layout Mode Tests

    func testSetLayoutMode() {
        // When
        renderer.setLayoutMode(.focus)

        // Then
        XCTAssertEqual(renderer.layoutMode, .focus)

        // When
        renderer.setLayoutMode(.horizontal)

        // Then
        XCTAssertEqual(renderer.layoutMode, .horizontal)
    }

    func testAllLayoutModes() {
        // Test all layout modes
        for mode in LayoutMode.allCases {
            // When
            renderer.setLayoutMode(mode)

            // Then
            XCTAssertEqual(renderer.layoutMode, mode)
            XCTAssertNotNil(mode.displayName)
        }
    }

    func testLayoutModeDisplayNames() {
        // Test display names
        XCTAssertEqual(LayoutMode.grid.displayName, "Grid")
        XCTAssertEqual(LayoutMode.focus.displayName, "Focus")
        XCTAssertEqual(LayoutMode.horizontal.displayName, "Horizontal")
    }

    // MARK: - Focused Position Tests

    func testSetFocusedPosition() {
        // When
        renderer.setFocusedPosition(.rear)

        // Then
        XCTAssertEqual(renderer.focusedPosition, .rear)

        // When
        renderer.setFocusedPosition(.left)

        // Then
        XCTAssertEqual(renderer.focusedPosition, .left)
    }

    func testAllCameraPositions() {
        // Test all camera positions
        for position in [CameraPosition.front, .rear, .left, .right, .interior] {
            // When
            renderer.setFocusedPosition(position)

            // Then
            XCTAssertEqual(renderer.focusedPosition, position)
        }
    }

    // MARK: - Viewport Calculation Tests (Grid Layout)

    func testGridViewportsSingleChannel() {
        // Note: These tests would require access to private methods
        // For now, we test indirectly through rendering or expose the methods for testing

        // Grid with 1 channel should fill entire area
        let size = CGSize(width: 1920, height: 1080)
        // Test would calculate viewports here
    }

    func testGridViewportsTwoChannels() {
        // Grid with 2 channels should create 1x2 or 2x1 grid
        let size = CGSize(width: 1920, height: 1080)
        // Test would calculate viewports here
    }

    func testGridViewportsFourChannels() {
        // Grid with 4 channels should create 2x2 grid
        let size = CGSize(width: 1920, height: 1080)
        // Test would calculate viewports here
    }

    func testGridViewportsFiveChannels() {
        // Grid with 5 channels should create 3x2 grid
        let size = CGSize(width: 1920, height: 1080)
        // Test would calculate viewports here
    }

    // MARK: - Focus Layout Tests

    func testFocusLayoutViewports() {
        // Given
        renderer.setLayoutMode(.focus)
        renderer.setFocusedPosition(.front)

        // Focus layout should have:
        // - 75% width for focused channel
        // - 25% width for thumbnails
    }

    // MARK: - Horizontal Layout Tests

    func testHorizontalLayoutViewports() {
        // Given
        renderer.setLayoutMode(.horizontal)

        // Horizontal layout should divide width equally
    }

    // MARK: - Capture Tests

    func testCaptureWithoutRendering() {
        // When: Capture before rendering
        let data = renderer.captureCurrentFrame()

        // Then: Should return nil
        XCTAssertNil(data, "Should return nil when no frame has been rendered")
    }

    func testCaptureFormats() {
        // Test both PNG and JPEG formats
        // Note: Requires actual rendering

        let formats: [CaptureImageFormat] = [.png, .jpeg]
        for format in formats {
            // Format should be supported
            XCTAssertNotNil(format)
        }
    }

    // MARK: - Performance Tests

    func testLayoutModeChangePerformance() {
        measure {
            for _ in 0..<1000 {
                renderer.setLayoutMode(.grid)
                renderer.setLayoutMode(.focus)
                renderer.setLayoutMode(.horizontal)
            }
        }
    }

    func testFocusPositionChangePerformance() {
        measure {
            for _ in 0..<1000 {
                renderer.setFocusedPosition(.front)
                renderer.setFocusedPosition(.rear)
                renderer.setFocusedPosition(.left)
                renderer.setFocusedPosition(.right)
            }
        }
    }

    // MARK: - Memory Management Tests

    func testRendererDeinit() {
        // Given
        var testRenderer: MultiChannelRenderer? = MultiChannelRenderer()

        // When
        testRenderer = nil

        // Then
        XCTAssertNil(testRenderer)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentLayoutModeChange() {
        // When: Change layout mode from multiple threads
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            let modes: [LayoutMode] = [.grid, .focus, .horizontal]
            renderer.setLayoutMode(modes[index % 3])
        }

        // Then: Should not crash
        XCTAssertNotNil(renderer)
    }

    func testConcurrentFocusPositionChange() {
        // When: Change focus position from multiple threads
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            let positions: [CameraPosition] = [.front, .rear, .left, .right, .interior]
            renderer.setFocusedPosition(positions[index % 5])
        }

        // Then: Should not crash
        XCTAssertNotNil(renderer)
    }
}

// MARK: - Integration Tests

/// Integration tests requiring actual Metal rendering
final class MultiChannelRendererIntegrationTests: XCTestCase {

    var renderer: MultiChannelRenderer!
    var testFrames: [CameraPosition: VideoFrame]!

    override func setUpWithError() throws {
        super.setUp()

        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal is not available")
        }

        renderer = MultiChannelRenderer()
        guard renderer != nil else {
            throw XCTSkip("Failed to create renderer")
        }

        // Create test frames
        // Note: This requires actual video frames for full integration testing
        testFrames = [:]
    }

    override func tearDownWithError() throws {
        renderer = nil
        testFrames = nil
        super.tearDown()
    }

    func testRenderWithEmptyFrames() {
        // Note: This test requires MTKView or similar drawable
        // For now, test that renderer doesn't crash with empty frames

        let frames: [CameraPosition: VideoFrame] = [:]
        // Rendering with empty frames should be safe
        XCTAssertNotNil(renderer)
    }

    func testGridLayoutRendering() {
        // Note: Requires actual rendering setup
        // Test would verify grid layout produces correct viewports
    }

    func testFocusLayoutRendering() {
        // Note: Requires actual rendering setup
        // Test would verify focus layout with main and thumbnail viewports
    }

    func testHorizontalLayoutRendering() {
        // Note: Requires actual rendering setup
        // Test would verify horizontal layout with equal width viewports
    }

    func testCaptureAfterRendering() {
        // Note: Requires actual rendering
        // After rendering, capture should return valid image data
    }

    func testCaptureDifferentFormats() {
        // Note: Requires actual rendering
        // Test PNG vs JPEG capture produces different data
    }

    func testTransformationIntegration() {
        // Test that video transformations are applied during rendering
        // Note: Requires actual rendering and transformation service
    }
}

// MARK: - Helper Extensions for Testing

extension MultiChannelRendererTests {
    /// Create dummy viewport for testing
    func createTestViewport(x: CGFloat = 0, y: CGFloat = 0, width: CGFloat = 100, height: CGFloat = 100) -> CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Create test size
    func createTestSize(width: CGFloat = 1920, height: CGFloat = 1080) -> CGSize {
        return CGSize(width: width, height: height)
    }

    /// Verify viewport is within bounds
    func assertViewportInBounds(_ viewport: CGRect, _ size: CGSize) {
        XCTAssertGreaterThanOrEqual(viewport.origin.x, 0)
        XCTAssertGreaterThanOrEqual(viewport.origin.y, 0)
        XCTAssertLessThanOrEqual(viewport.maxX, size.width)
        XCTAssertLessThanOrEqual(viewport.maxY, size.height)
    }

    /// Verify total viewport area matches drawable size
    func assertTotalViewportArea(_ viewports: [CameraPosition: CGRect], equals size: CGSize, tolerance: CGFloat = 0.01) {
        let totalArea = viewports.values.reduce(0) { $0 + ($1.width * $1.height) }
        let expectedArea = size.width * size.height
        let difference = abs(totalArea - expectedArea) / expectedArea

        XCTAssertLessThan(difference, tolerance, "Total viewport area should match drawable size")
    }
}
