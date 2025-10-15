/**
 * @file VendorParserTests.swift
 * @brief Vendor parser 단위 테스트
 * @author BlackboxPlayer Development Team
 */

import XCTest
@testable import BlackboxPlayer

// ============================================================================
// MARK: - CR2000OmegaParserTests
// ============================================================================

class CR2000OmegaParserTests: XCTestCase {

    var parser: CR2000OmegaParser!

    override func setUp() {
        super.setUp()
        parser = CR2000OmegaParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - Filename Matching Tests

    func testMatchesValidFilename() {
        // CR-2000 OMEGA 형식: YYYY-MM-DD-HHh-MMm-SSs_X_type.mp4
        let validFilenames = [
            "2025-10-07-09h-11m-09s_F_normal.mp4",
            "2025-10-07-09h-11m-09s_R_normal.mp4",
            "2025-10-07-09h-11m-09s_F_event.mp4",
            "2025-10-07-09h-11m-09s_R_parking.mp4",
            "2025-10-07-09h-11m-09s_I_motion.mp4",
            "2024-01-15-14h-30m-25s_F_normal.mp4"
        ]

        for filename in validFilenames {
            XCTAssertTrue(
                parser.matches(filename),
                "Should match valid CR-2000 OMEGA filename: \(filename)"
            )
        }
    }

    func testDoesNotMatchInvalidFilename() {
        let invalidFilenames = [
            "20240115_143025_F.mp4",           // BlackVue format
            "video.mp4",                        // Generic name
            "2025-10-07_F_normal.mp4",         // Missing time
            "2025-10-07-09h-11m-09s.mp4",      // Missing position and type
            "2025-10-07-09h-11m-09s_F.mp4",    // Missing type
            "invalid_file.avi"                  // Wrong extension
        ]

        for filename in invalidFilenames {
            XCTAssertFalse(
                parser.matches(filename),
                "Should not match invalid filename: \(filename)"
            )
        }
    }

    // MARK: - Video File Parsing Tests

    func testParseVideoFileNormal() {
        let filename = "2025-10-07-09h-11m-09s_F_normal.mp4"
        let testURL = URL(fileURLWithPath: "/test/\(filename)")

        let fileInfo = parser.parseVideoFile(testURL)

        XCTAssertNotNil(fileInfo, "Should parse valid filename")

        guard let info = fileInfo else { return }

        // Check camera position
        XCTAssertEqual(info.position, .front, "Should detect front camera")

        // Check event type
        XCTAssertEqual(info.eventType, .normal, "Should detect normal recording")

        // Check base filename
        XCTAssertEqual(info.baseFilename, "2025-10-07-09h-11m-09s", "Should extract base filename")

        // Check timestamp
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: info.timestamp)

        XCTAssertEqual(components.year, 2025, "Year should be 2025")
        XCTAssertEqual(components.month, 10, "Month should be 10")
        XCTAssertEqual(components.day, 7, "Day should be 7")
        XCTAssertEqual(components.hour, 9, "Hour should be 9")
        XCTAssertEqual(components.minute, 11, "Minute should be 11")
        XCTAssertEqual(components.second, 9, "Second should be 9")
    }

    func testParseVideoFileEvent() {
        let filename = "2025-10-07-10h-30m-45s_R_event.mp4"
        let testURL = URL(fileURLWithPath: "/test/\(filename)")

        let fileInfo = parser.parseVideoFile(testURL)

        XCTAssertNotNil(fileInfo)
        XCTAssertEqual(fileInfo?.position, .rear, "Should detect rear camera")
        XCTAssertEqual(fileInfo?.eventType, .impact, "Should map 'event' to .impact")
    }

    func testParseVideoFileParking() {
        let filename = "2025-10-07-15h-20m-30s_F_parking.mp4"
        let testURL = URL(fileURLWithPath: "/test/\(filename)")

        let fileInfo = parser.parseVideoFile(testURL)

        XCTAssertNotNil(fileInfo)
        XCTAssertEqual(fileInfo?.eventType, .parking, "Should detect parking mode")
    }

    func testParseVideoFileMotion() {
        let filename = "2025-10-07-12h-15m-00s_F_motion.mp4"
        let testURL = URL(fileURLWithPath: "/test/\(filename)")

        let fileInfo = parser.parseVideoFile(testURL)

        XCTAssertNotNil(fileInfo)
        XCTAssertEqual(fileInfo?.eventType, .impact, "Should map 'motion' to .impact")
    }

    func testParseVideoFileInteriorCamera() {
        let filename = "2025-10-07-09h-11m-09s_i_normal.mp4"
        let testURL = URL(fileURLWithPath: "/test/\(filename)")

        let fileInfo = parser.parseVideoFile(testURL)

        XCTAssertNotNil(fileInfo)
        XCTAssertEqual(fileInfo?.position, .interior, "Should detect interior camera (lowercase 'i')")
    }

    // MARK: - Supported Features Tests

    func testSupportedFeatures() {
        let features = parser.supportedFeatures()

        XCTAssertTrue(features.contains(.gpsData), "Should support GPS data")
        XCTAssertTrue(features.contains(.accelerometer), "Should support accelerometer")
        XCTAssertTrue(features.contains(.parkingMode), "Should support parking mode")
        XCTAssertTrue(features.contains(.voiceRecording), "Should support voice recording")
    }
}

// ============================================================================
// MARK: - BlackVueParserTests
// ============================================================================

class BlackVueParserTests: XCTestCase {

    var parser: BlackVueParser!

    override func setUp() {
        super.setUp()
        parser = BlackVueParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - Filename Matching Tests

    func testMatchesValidFilename() {
        // BlackVue 형식: YYYYMMDD_HHMMSS_X.mp4
        let validFilenames = [
            "20240115_143025_F.mp4",
            "20240115_143025_R.mp4",
            "20230601_120000_F.mp4",
            "20240115_143025_FI.mp4",    // Multi-channel
            "20240115_143025_RF.mp4"     // Multi-channel
        ]

        for filename in validFilenames {
            XCTAssertTrue(
                parser.matches(filename),
                "Should match valid BlackVue filename: \(filename)"
            )
        }
    }

    func testDoesNotMatchInvalidFilename() {
        let invalidFilenames = [
            "2025-10-07-09h-11m-09s_F_normal.mp4",  // CR-2000 OMEGA format
            "video.mp4",
            "20240115_F.mp4",                        // Missing time
            "20240115_143025.mp4"                    // Missing position
        ]

        for filename in invalidFilenames {
            XCTAssertFalse(
                parser.matches(filename),
                "Should not match invalid filename: \(filename)"
            )
        }
    }

    // MARK: - Video File Parsing Tests

    func testParseVideoFile() {
        let filename = "20240115_143025_F.mp4"
        let testURL = URL(fileURLWithPath: "/test/Normal/\(filename)")

        let fileInfo = parser.parseVideoFile(testURL)

        XCTAssertNotNil(fileInfo, "Should parse valid filename")

        guard let info = fileInfo else { return }

        // Check camera position
        XCTAssertEqual(info.position, .front, "Should detect front camera")

        // Check base filename
        XCTAssertEqual(info.baseFilename, "20240115_143025", "Should extract base filename")

        // Check timestamp
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: info.timestamp)

        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
        XCTAssertEqual(components.second, 25)
    }

    func testParseVideoFileEventType() {
        // Event 폴더의 파일
        let eventFile = URL(fileURLWithPath: "/test/Event/20240115_143025_F.mp4")
        let eventInfo = parser.parseVideoFile(eventFile)
        XCTAssertEqual(eventInfo?.eventType, .impact, "Should detect event type from path")

        // Normal 폴더의 파일
        let normalFile = URL(fileURLWithPath: "/test/Normal/20240115_143025_F.mp4")
        let normalInfo = parser.parseVideoFile(normalFile)
        XCTAssertEqual(normalInfo?.eventType, .normal, "Should detect normal type from path")

        // Parking 폴더의 파일
        let parkingFile = URL(fileURLWithPath: "/test/Parking/20240115_143025_F.mp4")
        let parkingInfo = parser.parseVideoFile(parkingFile)
        XCTAssertEqual(parkingInfo?.eventType, .parking, "Should detect parking type from path")
    }

    // MARK: - Supported Features Tests

    func testSupportedFeatures() {
        let features = parser.supportedFeatures()

        XCTAssertTrue(features.contains(.gpsData))
        XCTAssertTrue(features.contains(.accelerometer))
        XCTAssertTrue(features.contains(.parkingMode))
        XCTAssertTrue(features.contains(.cloudSync))
        XCTAssertTrue(features.contains(.voiceRecording))
    }
}

// ============================================================================
// MARK: - VendorDetectorTests
// ============================================================================

class VendorDetectorTests: XCTestCase {

    var detector: VendorDetector!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        detector = VendorDetector()

        // Create temporary directory for test files
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try? FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDir)
        detector = nil
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Vendor Detection Tests

    func testDetectCR2000Omega() {
        // Create CR-2000 OMEGA test files
        let filenames = [
            "2025-10-07-09h-11m-09s_F_normal.mp4",
            "2025-10-07-09h-11m-09s_R_normal.mp4",
            "2025-10-07-09h-13m-09s_F_normal.mp4",
            "2025-10-07-09h-13m-09s_R_normal.mp4",
            "2025-10-07-09h-15m-09s_F_normal.mp4",
            "2025-10-07-09h-15m-09s_R_normal.mp4"
        ]

        for filename in filenames {
            let fileURL = tempDir.appendingPathComponent(filename)
            FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        }

        // Detect vendor
        let detectedParser = detector.detectVendor(in: tempDir)

        XCTAssertNotNil(detectedParser, "Should detect vendor")
        XCTAssertEqual(detectedParser?.vendorId, "cr2000omega", "Should detect CR-2000 OMEGA")
        XCTAssertEqual(detectedParser?.vendorName, "CR-2000 OMEGA")
    }

    func testDetectBlackVue() {
        // Create BlackVue test files
        let filenames = [
            "20240115_143025_F.mp4",
            "20240115_143025_R.mp4",
            "20240115_143125_F.mp4",
            "20240115_143125_R.mp4",
            "20240115_143225_F.mp4",
            "20240115_143225_R.mp4"
        ]

        for filename in filenames {
            let fileURL = tempDir.appendingPathComponent(filename)
            FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        }

        // Detect vendor
        let detectedParser = detector.detectVendor(in: tempDir)

        XCTAssertNotNil(detectedParser, "Should detect vendor")
        XCTAssertEqual(detectedParser?.vendorId, "blackvue", "Should detect BlackVue")
        XCTAssertEqual(detectedParser?.vendorName, "BlackVue")
    }

    func testDetectUnknownVendor() {
        // Create files with unknown format
        let filenames = [
            "video1.mp4",
            "video2.mp4",
            "recording.avi"
        ]

        for filename in filenames {
            let fileURL = tempDir.appendingPathComponent(filename)
            FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        }

        // Detect vendor
        let detectedParser = detector.detectVendor(in: tempDir)

        XCTAssertNil(detectedParser, "Should not detect vendor for unknown format")
    }

    func testDetectWithMixedFiles() {
        // Create mostly CR-2000 OMEGA files with some noise
        let cr2000Files = [
            "2025-10-07-09h-11m-09s_F_normal.mp4",
            "2025-10-07-09h-11m-09s_R_normal.mp4",
            "2025-10-07-09h-13m-09s_F_normal.mp4",
            "2025-10-07-09h-13m-09s_R_normal.mp4",
            "2025-10-07-09h-15m-09s_F_normal.mp4",
            "2025-10-07-09h-15m-09s_R_normal.mp4",
            "2025-10-07-09h-17m-09s_F_normal.mp4",
            "2025-10-07-09h-17m-09s_R_normal.mp4"
        ]

        let noiseFiles = [
            "readme.txt",
            "thumbnail.jpg"
        ]

        for filename in cr2000Files + noiseFiles {
            let fileURL = tempDir.appendingPathComponent(filename)
            FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        }

        // Detect vendor (should detect CR-2000 OMEGA despite noise files)
        let detectedParser = detector.detectVendor(in: tempDir)

        XCTAssertNotNil(detectedParser, "Should detect vendor despite noise files")
        XCTAssertEqual(detectedParser?.vendorId, "cr2000omega", "Should detect CR-2000 OMEGA")
    }

    // MARK: - Cache Tests

    func testVendorDetectionCaching() {
        // Create CR-2000 OMEGA test files
        let filenames = [
            "2025-10-07-09h-11m-09s_F_normal.mp4",
            "2025-10-07-09h-11m-09s_R_normal.mp4",
            "2025-10-07-09h-13m-09s_F_normal.mp4"
        ]

        for filename in filenames {
            let fileURL = tempDir.appendingPathComponent(filename)
            FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        }

        // First detection
        let parser1 = detector.detectVendor(in: tempDir)
        XCTAssertNotNil(parser1)

        // Second detection (should use cache)
        let parser2 = detector.detectVendor(in: tempDir)
        XCTAssertNotNil(parser2)

        // Should return same vendor
        XCTAssertEqual(parser1?.vendorId, parser2?.vendorId, "Should return same vendor from cache")
    }
}
