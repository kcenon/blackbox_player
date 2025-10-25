/**
 * @file CR2000OmegaParser.swift
 * @brief CR-2000 OMEGA dashcam file parser
 * @author BlackboxPlayer Development Team
 *
 * @details
 * Parses CR-2000 OMEGA dashcam filename format and metadata.
 *
 * Filename format: YYYY-MM-DD-HHh-MMm-SSs_X_type.mp4
 * - Example: 2025-10-07-09h-11m-09s_F_normal.mp4
 *
 * Metadata: Stream #2 (mp4s)
 * - GPS: X,Y,Z,gJ$GPRMC (NMEA 0183)
 * - Acceleration: X,Y,Z (front part)
 */

import Foundation

// ============================================================================
// MARK: - CR2000OmegaParser
// ============================================================================

/**
 * @class CR2000OmegaParser
 * @brief CR-2000 OMEGA dashcam file parser
 */
class CR2000OmegaParser: VendorParserProtocol {

    // MARK: - VendorParserProtocol Properties

    let vendorId = "cr2000omega"
    let vendorName = "CR-2000 OMEGA"

    // MARK: - Private Properties

    /**
     * Filename regex pattern: YYYY-MM-DD-HHh-MMm-SSs_X_type.mp4
     *
     * Capture groups:
     * - 1: Year (YYYY) - 4 digits
     * - 2: Month (MM) - 2 digits
     * - 3: Day (DD) - 2 digits
     * - 4: Hour (HH) - 2 digits
     * - 5: Minute (MM) - 2 digits
     * - 6: Second (SS) - 2 digits
     * - 7: Camera position (F/R/L/I)
     * - 8: Recording type (normal/event/parking/motion)
     * - 9: Extension (mp4/avi etc.)
     */
    private let filenamePattern = #"^(\d{4})-(\d{2})-(\d{2})-(\d{2})h-(\d{2})m-(\d{2})s_([FRLIi])_(normal|event|parking|motion)\.(\w+)$"#

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
     * @brief Check if filename matches CR-2000 OMEGA format
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
     * 1. Extract date, time, camera position, and type using regex
     * 2. Convert date/time string → Date
     * 3. Map camera position code → CameraPosition enum
     * 4. Extract event type directly from filename (normal/event/parking)
     * 5. Query file size
     * 6. Create VideoFileInfo
     */
    func parseVideoFile(_ fileURL: URL) -> VideoFileInfo? {
        let filename = fileURL.lastPathComponent

        // Regex matching
        guard let regex = filenameRegex else { return nil }

        let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
        guard let match = regex.firstMatch(in: filename, options: [], range: range) else {
            return nil
        }

        // Verify capture group count: [whole, year, month, day, hour, minute, second, position, type, extension]
        guard match.numberOfRanges == 10 else { return nil }

        // Extract capture groups
        let year = (filename as NSString).substring(with: match.range(at: 1))
        let month = (filename as NSString).substring(with: match.range(at: 2))
        let day = (filename as NSString).substring(with: match.range(at: 3))
        let hour = (filename as NSString).substring(with: match.range(at: 4))
        let minute = (filename as NSString).substring(with: match.range(at: 5))
        let second = (filename as NSString).substring(with: match.range(at: 6))
        let positionCode = (filename as NSString).substring(with: match.range(at: 7))
        let eventTypeString = (filename as NSString).substring(with: match.range(at: 8))

        // Parse timestamp: "20251007091109" → Date
        let timestampString = "\(year)\(month)\(day)\(hour)\(minute)\(second)"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")

        guard let timestamp = dateFormatter.date(from: timestampString) else {
            return nil
        }

        // Detect camera position
        let position = CameraPosition.detect(from: positionCode)

        // Extract event type directly from filename
        let eventType: EventType
        switch eventTypeString.lowercased() {
        case "normal":
            eventType = .normal
        case "event":
            eventType = .impact  // Map event to impact
        case "parking":
            eventType = .parking
        case "motion":
            eventType = .impact  // Map motion to impact
        default:
            eventType = .unknown
        }

        // Query file size
        let fileSize = UInt64(
            (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? UInt64) ?? 0
        )

        // Generate base filename (excluding camera position and type)
        // "2025-10-07-09h-11m-09s_F_normal.mp4" → "2025-10-07-09h-11m-09s"
        let baseFilename = "\(year)-\(month)-\(day)-\(hour)h-\(minute)m-\(second)s"

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
     * CR-2000 OMEGA stores data in Stream #2 as "X,Y,Z,gJ$GPRMC,..." format
     * Extracts only the NMEA 0183 portion after gJ and parses with GPSParser.
     */
    func extractGPSData(from fileURL: URL) -> [GPSPoint] {
        // Extract metadata lines with MetadataStreamParser
        let parser = MetadataStreamParser()
        let lines = parser.extractMetadataLines(from: fileURL, streamIndex: 2)

        guard !lines.isEmpty else {
            return []
        }

        // Extract base date from filename (for combining with NMEA time)
        let baseDate = extractBaseDate(from: fileURL)

        // Parse with GPSParser
        let gpsParser = GPSParser()
        var gpsPoints: [GPSPoint] = []

        for line in lines {
            // Extract "$GPRMC" NMEA portion (binary header already removed)
            if let nmeaStart = line.range(of: "$GPRMC") {
                let nmea = String(line[nmeaStart.lowerBound...])

                // Convert NMEA string to Data
                if let nmeaData = nmea.data(using: .ascii) {
                    let points = gpsParser.parseNMEA(data: nmeaData, baseDate: baseDate)
                    gpsPoints.append(contentsOf: points)
                }
            }
        }

        return gpsPoints
    }

    /**
     * @brief Extract acceleration data from video
     * @param fileURL Video file URL
     * @return Array of AccelerationData
     *
     * @details
     * CR-2000 OMEGA stores data in Stream #2 as "X,Y,Z,gJ$GPRMC,..." format
     * Extracts the X, Y, Z values from the beginning.
     */
    func extractAccelerationData(from fileURL: URL) -> [AccelerationData] {
        // Extract metadata lines with MetadataStreamParser
        let parser = MetadataStreamParser()
        let lines = parser.extractMetadataLines(from: fileURL, streamIndex: 2)

        guard !lines.isEmpty else {
            return []
        }

        // Extract base date from filename
        let baseDate = extractBaseDate(from: fileURL)

        var accelerationData: [AccelerationData] = []
        var timestamp: TimeInterval = 0.0

        for line in lines {
            // Line format: "X,Y,Z,gJ$GPRMC,..."
            // Extract first 3 values (X, Y, Z)
            let components = line.split(separator: ",", maxSplits: 3)

            guard components.count >= 3,
                  let x = Double(components[0]),
                  let y = Double(components[1]),
                  let z = Double(components[2]) else {
                continue
            }

            // Create AccelerationData (1 second interval)
            let data = AccelerationData(
                timestamp: baseDate.addingTimeInterval(timestamp),
                x: x,
                y: y,
                z: z
            )

            accelerationData.append(data)
            timestamp += 1.0  // Increment by 1 second
        }

        return accelerationData
    }

    /**
     * @brief CR-2000 OMEGA supported features
     * @return Array of VendorFeature
     */
    func supportedFeatures() -> [VendorFeature] {
        return [
            .gpsData,
            .accelerometer,
            .parkingMode,
            .voiceRecording
        ]
    }

    // MARK: - Private Methods

    /**
     * @brief Extract recording start time from file URL
     * @param fileURL Video file URL
     * @return Recording start Date
     *
     * @details
     * Filename format: "YYYY-MM-DD-HHh-MMm-SSs_X_type.mp4"
     * Example: "2025-10-07-09h-11m-09s_F_normal.mp4"
     * → Date(2025-10-07 09:11:09 +0900)
     */
    private func extractBaseDate(from fileURL: URL) -> Date {
        let filename = fileURL.lastPathComponent

        // Regex matching
        guard let regex = filenameRegex else {
            return Date()
        }

        let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
        guard let match = regex.firstMatch(in: filename, options: [], range: range),
              match.numberOfRanges == 10 else {
            return Date()
        }

        // Extract capture groups
        let year = (filename as NSString).substring(with: match.range(at: 1))
        let month = (filename as NSString).substring(with: match.range(at: 2))
        let day = (filename as NSString).substring(with: match.range(at: 3))
        let hour = (filename as NSString).substring(with: match.range(at: 4))
        let minute = (filename as NSString).substring(with: match.range(at: 5))
        let second = (filename as NSString).substring(with: match.range(at: 6))

        // Parse timestamp
        let timestampString = "\(year)\(month)\(day)\(hour)\(minute)\(second)"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")

        return dateFormatter.date(from: timestampString) ?? Date()
    }
}
