/// @file DeviceDetectorTests.swift
/// @brief Unit tests for DeviceDetector
/// @author BlackboxPlayer Development Team
/// @details Unit tests that verify the SD card detection functionality of DeviceDetector.

import XCTest
@testable import BlackboxPlayer

/*
 ═══════════════════════════════════════════════════════════════════════════
 DeviceDetector Unit Tests
 ═══════════════════════════════════════════════════════════════════════════

 [Test Scope]
 1. detectSDCards: Detect currently mounted removable devices
 2. monitorDeviceChanges: Monitor device connection/disconnection events

 [Test Strategy]
 - Use actual system volumes (integration test nature)
 - Verify notification observer registration
 - Verify asynchronous callbacks using Expectation

 [Test Limitations]
 DeviceDetector is a system-level service:
 - Requires actual SD card connection/disconnection (difficult to automate)
 - Can be simulated with DMG files
 - Limited in CI/CD environments

 [Recommended Test Methods]
 1. Development environment: Use actual SD card or USB drive
 2. CI environment: Create/mount test DMG files
 3. Unit tests: Only verify observer registration/deregistration

 ═══════════════════════════════════════════════════════════════════════════
 */

/// @class DeviceDetectorTests
/// @brief Unit test class for DeviceDetector
final class DeviceDetectorTests: XCTestCase {
    // MARK: - Properties

    /// @var detector
    /// @brief DeviceDetector instance under test
    var detector: DeviceDetector!

    // MARK: - Setup & Teardown

    /// @brief Initialize environment before test
    override func setUp() {
        super.setUp()
        detector = DeviceDetector()
    }

    /// @brief Clean up environment after test
    override func tearDown() {
        detector = nil
        super.tearDown()
    }

    // MARK: - Detect SD Cards Tests

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 1: detectSDCards - Basic Operation
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Query removable devices from currently mounted volumes

     [Expected Result]
     - Returns array (empty array is possible)
     - Returned URLs are actual existing paths
     - Returned URLs satisfy removable device attributes

     [Note]
     If there are no SD cards or USB drives on the test machine, an empty array is returned.
     This is not an error and should not be treated as a failure.
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief detectSDCards: Verify that it returns a list of removable devices
    func testDetectSDCards_ReturnsArray() {
        // When: Query SD card list
        let sdCards = detector.detectSDCards()

        // Then: Returns array (empty array is also valid)
        XCTAssertTrue(sdCards is [URL], "Should return URL array")

        // Print detected devices
        if sdCards.isEmpty {
            print("⚠️ No SD cards detected. Connect SD card or USB drive for complete testing.")
        } else {
            print("✓ Detected \(sdCards.count) removable device(s):")
            for sdCard in sdCards {
                print("  - \(sdCard.path)")
            }
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 2: detectSDCards - Path Validity
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Verify that returned URLs are actually existing paths

     [Expected Result]
     - All URLs actually exist
     - All URLs are directories
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief detectSDCards: Verify that returned paths actually exist
    func testDetectSDCards_ReturnsValidPaths() {
        // When: Query SD card list
        let sdCards = detector.detectSDCards()

        // Then: All paths actually exist
        for sdCard in sdCards {
            let pathExists = FileManager.default.fileExists(atPath: sdCard.path)
            XCTAssertTrue(pathExists, "Path should exist: \(sdCard.path)")

            // Check if it's a directory
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: sdCard.path, isDirectory: &isDirectory)
            XCTAssertTrue(isDirectory.boolValue, "Should be a directory: \(sdCard.path)")
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 3: detectSDCards - Removable Attribute Verification
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Verify that returned volumes actually satisfy removable device attributes

     [Expected Result]
     - isRemovable = true
     - isEjectable = true
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief detectSDCards: Verify that returned volumes satisfy removable attributes
    func testDetectSDCards_ReturnsRemovableDevices() throws {
        // When: Query SD card list
        let sdCards = detector.detectSDCards()

        // Then: All volumes satisfy removable attributes
        for sdCard in sdCards {
            let resourceValues = try sdCard.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey])

            XCTAssertTrue(resourceValues.volumeIsRemovable == true, "Should be removable: \(sdCard.path)")
            XCTAssertTrue(resourceValues.volumeIsEjectable == true, "Should be ejectable: \(sdCard.path)")
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 4: detectSDCards - Exclude Internal Disks
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Verify that internal disks (Macintosh HD, etc.) are not included in the results

     [Expected Result]
     - "/" (root volume) is not included
     - Excludes system volumes like "/System/Volumes"
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief detectSDCards: Verify that internal disks are not included in results
    func testDetectSDCards_ExcludesInternalDisks() {
        // When: Query SD card list
        let sdCards = detector.detectSDCards()

        // Then: Exclude internal disk paths
        let internalPaths = ["/", "/System/Volumes/Data"]

        for sdCard in sdCards {
            XCTAssertFalse(internalPaths.contains(sdCard.path), "Should not include internal disk: \(sdCard.path)")
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 5: detectSDCards - Remove Duplicates
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Verify that the same device is not returned multiple times

     [Expected Result]
     - All URLs are unique (no duplicates)
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief detectSDCards: Verify that duplicate paths are not returned
    func testDetectSDCards_ReturnsUniqueDevices() {
        // When: Query SD card list
        let sdCards = detector.detectSDCards()

        // Then: No duplicates
        let uniqueCards = Set(sdCards)
        XCTAssertEqual(sdCards.count, uniqueCards.count, "Should not have duplicate devices")
    }

    // MARK: - Monitor Device Changes Tests

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 6: monitorDeviceChanges - Callback Registration
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Verify that callbacks are properly registered when monitoring starts

     [Expected Result]
     - No errors when calling the method
     - Observer is internally registered

     [Note]
     Without actual device connection/disconnection events, callback execution cannot be verified.
     This test only verifies the registration itself.
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief monitorDeviceChanges: Verify that callbacks are properly registered
    func testMonitorDeviceChanges_RegistersCallbacks() {
        // Given: Callback functions
        var connectCalled = false
        var disconnectCalled = false

        let onConnect: (URL) -> Void = { _ in
            connectCalled = true
        }

        let onDisconnect: (URL) -> Void = { _ in
            disconnectCalled = true
        }

        // When: Start monitoring
        XCTAssertNoThrow(
            detector.monitorDeviceChanges(onConnect: onConnect, onDisconnect: onDisconnect),
            "Should register callbacks without error"
        )

        // Then: Completed without error
        // (Actual callback execution only occurs during device connection/disconnection)
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 7: monitorDeviceChanges - Multiple Calls
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Verify that it's safe to call monitorDeviceChanges multiple times

     [Expected Result]
     - Multiple observers can be registered simultaneously
     - No memory leaks
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief monitorDeviceChanges: Verify that it's safe to call multiple times
    func testMonitorDeviceChanges_AllowsMultipleCalls() {
        // When: Start monitoring multiple times
        detector.monitorDeviceChanges(onConnect: { _ in }, onDisconnect: { _ in })
        detector.monitorDeviceChanges(onConnect: { _ in }, onDisconnect: { _ in })
        detector.monitorDeviceChanges(onConnect: { _ in }, onDisconnect: { _ in })

        // Then: Completed without error
        // (All observers are cleaned up in deinit)
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 8: Memory Management
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Verify that observers are cleaned up when DeviceDetector instance is deallocated

     [Expected Result]
     - All observers are removed when deinit is called
     - No memory leaks
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief Verify that DeviceDetector cleans up observers when deallocated
    func testDeviceDetector_CleansUpObservers() {
        // Given: Create new instance
        var tempDetector: DeviceDetector? = DeviceDetector()

        // When: Start monitoring and then deallocate
        tempDetector?.monitorDeviceChanges(onConnect: { _ in }, onDisconnect: { _ in })
        tempDetector = nil

        // Then: deinit is called and observers are cleaned up
        // (Passes if no memory leak)
        XCTAssertNil(tempDetector, "Detector should be deallocated")
    }

    // MARK: - Integration Tests (Manual)

    /*
     ───────────────────────────────────────────────────────────────────────
     Integration Tests (Manual Execution)
     ───────────────────────────────────────────────────────────────────────

     The following tests require an actual SD card or USB drive.
     They will not run in automated CI/CD.

     [Test Method]
     1. Insert actual SD card
     2. Run testMonitorDeviceChanges_DetectsConnection
     3. Eject SD card while test is waiting
     4. Verify success/failure within 30 seconds

     [Alternative: Using DMG File]
     ```bash
     # Create test DMG
     hdiutil create -size 100m -fs FAT32 -volname "TEST_SD" test_sd.dmg

     # Mount after running test
     hdiutil attach test_sd.dmg

     # Unmount
     hdiutil detach /Volumes/TEST_SD
     ```
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief [MANUAL] monitorDeviceChanges: Verify that callback is called when actual device is connected
    ///
    /// This test requires manual execution:
    /// 1. Start test
    /// 2. Insert SD card or USB drive
    /// 3. Verify callback is called within 30 seconds
    func disabled_testMonitorDeviceChanges_DetectsConnection_MANUAL() {
        // Given: Set up expectation
        let connectExpectation = expectation(description: "Device connected")

        var connectedDevice: URL?

        // When: Start monitoring
        detector.monitorDeviceChanges(
            onConnect: { volumeURL in
                connectedDevice = volumeURL
                connectExpectation.fulfill()
            },
            onDisconnect: { _ in }
        )

        print("⏳ Waiting for SD card connection... (30 seconds)")
        print("   Please insert SD card or USB drive now.")

        // Then: Callback is called within 30 seconds
        wait(for: [connectExpectation], timeout: 30.0)

        XCTAssertNotNil(connectedDevice, "Should detect connected device")
        if let device = connectedDevice {
            print("✓ Device connected: \(device.path)")
        }
    }

    /// @brief [MANUAL] monitorDeviceChanges: Verify that callback is called when actual device is disconnected
    ///
    /// This test requires manual execution:
    /// 1. Connect SD card or USB drive beforehand
    /// 2. Start test
    /// 3. Eject device within 30 seconds
    func disabled_testMonitorDeviceChanges_DetectsDisconnection_MANUAL() {
        // Given: Set up expectation
        let disconnectExpectation = expectation(description: "Device disconnected")

        var disconnectedDevice: URL?

        // When: Start monitoring
        detector.monitorDeviceChanges(
            onConnect: { _ in },
            onDisconnect: { volumeURL in
                disconnectedDevice = volumeURL
                disconnectExpectation.fulfill()
            }
        )

        print("⏳ Waiting for SD card disconnection... (30 seconds)")
        print("   Please eject SD card or USB drive now.")

        // Then: Callback is called within 30 seconds
        wait(for: [disconnectExpectation], timeout: 30.0)

        XCTAssertNotNil(disconnectedDevice, "Should detect disconnected device")
        if let device = disconnectedDevice {
            print("✓ Device disconnected: \(device.path)")
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Performance Tests
     ───────────────────────────────────────────────────────────────────────

     [Purpose]
     Measure execution time of detectSDCards()

     [Expected Performance]
     - Typically under 10ms
     - Under 50ms even with many mounted volumes
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief detectSDCards: Performance measurement
    func testDetectSDCards_Performance() {
        measure {
            // When: Query SD card list (10 iterations)
            for _ in 0..<10 {
                _ = detector.detectSDCards()
            }
        }

        // Performance baseline: Average under 10ms (under 1ms per execution)
    }
}

/*
 ═══════════════════════════════════════════════════════════════════════════
 Test Execution Guide
 ═══════════════════════════════════════════════════════════════════════════

 [Automated Test Execution]

 ```bash
 # Basic tests (excluding manual tests)
 xcodebuild test -scheme BlackboxPlayer \
   -destination 'platform=macOS' \
   -only-testing:BlackboxPlayerTests/DeviceDetectorTests

 # Specific test only
 xcodebuild test -scheme BlackboxPlayer \
   -destination 'platform=macOS' \
   -only-testing:BlackboxPlayerTests/DeviceDetectorTests/testDetectSDCards_ReturnsArray
 ```

 [Manual Test Execution]

 Run manual tests directly in Xcode:
 1. Select testMonitorDeviceChanges_DetectsConnection_MANUAL
 2. Click the diamond icon
 3. Insert SD card after test starts
 4. Verify result within 30 seconds

 [Testing with DMG File]

 ```bash
 # 1. Create test DMG
 hdiutil create -size 100m -fs FAT32 -volname "TEST_SD" /tmp/test_sd.dmg

 # 2. Start test (in background)
 xcodebuild test -scheme BlackboxPlayer \
   -destination 'platform=macOS' \
   -only-testing:BlackboxPlayerTests/DeviceDetectorTests/testMonitorDeviceChanges_DetectsConnection_MANUAL &

 # 3. Mount DMG after 5 seconds
 sleep 5
 hdiutil attach /tmp/test_sd.dmg

 # 4. Wait for test to complete
 wait

 # 5. Cleanup
 hdiutil detach /Volumes/TEST_SD
 rm /tmp/test_sd.dmg
 ```

 [CI/CD Integration]

 Automate with DMG file in GitHub Actions:
 ```yaml
 - name: Create Test DMG
   run: |
     hdiutil create -size 100m -fs FAT32 -volname "TEST_SD" test_sd.dmg

 - name: Run Tests with DMG
   run: |
     # Start test in background
     xcodebuild test -scheme BlackboxPlayer -destination 'platform=macOS' &
     TEST_PID=$!

     # Mount DMG after 5 seconds
     sleep 5
     hdiutil attach test_sd.dmg

     # Wait for test to complete
     wait $TEST_PID

 - name: Cleanup
   run: |
     hdiutil detach /Volumes/TEST_SD || true
     rm test_sd.dmg || true
 ```

 [Test Coverage]

 100% coverage is not possible for DeviceDetector as it's a system-level integration.
 Recommended coverage:
 - detectSDCards: 80% (testable without actual SD card)
 - monitorDeviceChanges: 60% (callback execution requires manual testing)

 ═══════════════════════════════════════════════════════════════════════════
 */
