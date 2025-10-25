/**
 * @file BlackVueParser.swift
 * @brief BlackVue dashcam file parser
 * @author BlackboxPlayer Development Team
 *
 * @details
 * Parses BlackVue dashcam filename format and metadata.
 *
 * Filename format: YYYYMMDD_HHMMSS_X.mp4
 * - Example: 20240115_143025_F.mp4
 *
 * Metadata: Stream #2 (mp4s)
 * - GPS: NMEA 0183 format
 * - Acceleration: 3-axis data
 */

import Foundation

// ============================================================================
// MARK: - BlackVueParser
// ============================================================================

/**
 * @class BlackVueParser
 * @brief BlackVue dashcam file parser
 */
class BlackVueParser: VendorParserProtocol {

    // MARK: - VendorParserProtocol Properties

    let vendorId = "blackvue"
    let vendorName = "BlackVue"

    // MARK: - Private Properties

    /**
     * Filename regex pattern: YYYYMMDD_HHMMSS_X.mp4
     *
     * Capture groups:
     * - 1: Date (YYYYMMDD) - 8 digits
     * - 2: Time (HHMMSS) - 6 digits
     * - 3: Camera position (F/R/L/I) - 1+ characters
     * - 4: Extension (mp4/avi etc.)
     */
    private let filenamePattern = #"^(\d{8})_(\d{6})_([FRLIi]+)\.(\w+)$"#

    /// Compiled regular expression
    private let filenameRegex: NSRegularExpression?

    // MARK: - Initialization

    init() {
        self.filenameRegex = try? NSRegularExpression(
            pattern: filenamePattern,
            options: []
        )
    }

    // MARK: - VendorParserProtocol Methods

    /**
     * @brief Check if filename matches BlackVue format
     * @param filename Filename to check
     * @return Whether it matches
     */
    func matches(_ filename: String) -> Bool {
        guard let regex = filenameRegex else { return false }

        let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
        return regex.firstMatch(in: filename, options: [], range: range) != nil
    }

    /**
     * @brief Extract metadata from filename
     * @param fileURL Video file URL
     * @return VideoFileInfo or nil
     *
     * @details
     * Filename parsing process:
     * 1. Extract date, time, camera position using regex
     * 2. Convert date/time string → Date
     * 3. Camera position code → CameraPosition enum
     * 4. Detect event type from path
     * 5. Query file size
     * 6. Create VideoFileInfo
     */
    func parseVideoFile(_ fileURL: URL) -> VideoFileInfo? {
        let filename = fileURL.lastPathComponent
        let pathString = fileURL.path

        // Regex matching
        guard let regex = filenameRegex else { return nil }

        let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
        guard let match = regex.firstMatch(in: filename, options: [], range: range) else {
            return nil
        }

        // Check capture group count: [all, date, time, position, extension]
        guard match.numberOfRanges == 5 else { return nil }

        // Extract capture groups
        let dateString = (filename as NSString).substring(with: match.range(at: 1))
        let timeString = (filename as NSString).substring(with: match.range(at: 2))
        let positionCode = (filename as NSString).substring(with: match.range(at: 3))

        // Parse timestamp: "20240115143025" → Date
        let timestampString = dateString + timeString
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")

        guard let timestamp = dateFormatter.date(from: timestampString) else {
            return nil
        }

        // Detect camera position
        let position = CameraPosition.detect(from: positionCode)

        // Detect event type (path-based)
        let eventType = EventType.detect(from: pathString)

        // Query file size
        let fileSize = UInt64(
            (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? UInt64) ?? 0
        )

        // Generate base filename (excluding camera position)
        // "20240115_143025_F.mp4" → "20240115_143025"
        let baseFilename = "\(dateString)_\(timeString)"

        return VideoFileInfo(
            url: fileURL,
            timestamp: timestamp,
            position: position,
            eventType: eventType,
            fileSize: fileSize,
            baseFilename: baseFilename
        )
    }

    /**
     * @brief Extract GPS data from video
     * @param fileURL Video file URL
     * @return Array of GPSPoint
     *
     * @details
     * BlackVue stores GPS data in NMEA 0183 format in Stream #2
     * Uses GPSParser for extraction.
     */
    func extractGPSData(from fileURL: URL) -> [GPSPoint] {
        // TODO: Integrate GPSParser
        // Currently returns empty array
        return []
    }

    /**
     * @brief Extract acceleration data from video
     * @param fileURL Video file URL
     * @return Array of AccelerationData
     *
     * @details
     * BlackVue includes acceleration data in Stream #2
     * Uses GSensorParser for extraction.
     */
    func extractAccelerationData(from fileURL: URL) -> [AccelerationData] {
        // TODO: Integrate GSensorParser
        // Currently returns empty array
        return []
    }

    /**
     * @brief BlackVue supported features
     * @return Array of VendorFeature
     */
    func supportedFeatures() -> [VendorFeature] {
        return [
            .gpsData,
            .accelerometer,
            .parkingMode,
            .cloudSync,
            .voiceRecording
        ]
    }
}
