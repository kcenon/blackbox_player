//
//  GPSParser.swift
//  BlackboxPlayer
//
//  Parser for GPS data in NMEA 0183 format
//

import Foundation

/// Parser for NMEA 0183 GPS sentences
class GPSParser {
    // MARK: - Properties

    /// Base date for relative timestamps (set when parsing starts)
    private var baseDate: Date?

    // MARK: - Public Methods

    /// Parse NMEA sentences and convert to GPSPoint array
    /// - Parameters:
    ///   - data: Raw NMEA data
    ///   - baseDate: Base date for timestamps (from video file)
    /// - Returns: Array of GPSPoint objects
    func parseNMEA(data: Data, baseDate: Date) -> [GPSPoint] {
        self.baseDate = baseDate

        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }

        // Split into lines
        let lines = text.components(separatedBy: .newlines)
        var gpsPoints: [GPSPoint] = []

        // Temporary storage for merging GPRMC and GPGGA data
        var currentRMC: NMEARecord?

        for line in lines {
            let sentence = line.trimmingCharacters(in: .whitespaces)
            guard !sentence.isEmpty, sentence.hasPrefix("$") else { continue }

            // Parse sentence type
            if sentence.hasPrefix("$GPRMC") || sentence.hasPrefix("$GNRMC") {
                if let rmc = parseGPRMC(sentence) {
                    currentRMC = rmc
                    // Create GPSPoint from RMC (may be updated by GGA later)
                    if let point = createGPSPoint(from: rmc) {
                        gpsPoints.append(point)
                    }
                }
            } else if sentence.hasPrefix("$GPGGA") || sentence.hasPrefix("$GNGGA") {
                if let gga = parseGPGGA(sentence), let rmc = currentRMC {
                    // Update last GPS point with altitude and accuracy
                    if !gpsPoints.isEmpty {
                        let lastIndex = gpsPoints.count - 1
                        let lastPoint = gpsPoints[lastIndex]

                        // Update with altitude and satellite count
                        gpsPoints[lastIndex] = GPSPoint(
                            timestamp: lastPoint.timestamp,
                            latitude: lastPoint.latitude,
                            longitude: lastPoint.longitude,
                            altitude: gga.altitude,
                            speed: lastPoint.speed,
                            heading: lastPoint.heading,
                            horizontalAccuracy: gga.hdop.map { $0 * 10 },  // Rough estimate
                            satelliteCount: gga.satelliteCount
                        )
                    }
                }
            }
        }

        return gpsPoints
    }

    /// Parse single NMEA sentence
    /// - Parameter sentence: NMEA sentence string
    /// - Returns: GPSPoint or nil if parsing fails
    func parseSentence(_ sentence: String) -> GPSPoint? {
        if sentence.hasPrefix("$GPRMC") || sentence.hasPrefix("$GNRMC") {
            if let rmc = parseGPRMC(sentence) {
                return createGPSPoint(from: rmc)
            }
        }
        return nil
    }

    // MARK: - Private Methods

    private func parseGPRMC(_ sentence: String) -> NMEARecord? {
        // $GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A
        // Fields: [0]Type, [1]Time, [2]Status, [3]Lat, [4]LatDir, [5]Lon, [6]LonDir,
        //         [7]Speed, [8]Heading, [9]Date, [10]MagVar, [11]MagVarDir, [12]Checksum

        let fields = sentence.components(separatedBy: ",")
        guard fields.count >= 10 else { return nil }

        // Check status (A = active/valid, V = void/invalid)
        guard fields[2] == "A" else { return nil }

        // Parse timestamp
        guard let timestamp = parseDateTime(time: fields[1], date: fields.count > 9 ? fields[9] : nil) else {
            return nil
        }

        // Parse latitude
        guard let latitude = parseCoordinate(fields[3], direction: fields[4]) else {
            return nil
        }

        // Parse longitude
        guard let longitude = parseCoordinate(fields[5], direction: fields[6]) else {
            return nil
        }

        // Parse speed (knots to km/h)
        let speed = Double(fields[7]).map { $0 * 1.852 }  // Convert knots to km/h

        // Parse heading
        let heading = Double(fields[8])

        return NMEARecord(
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            altitude: nil,
            speed: speed,
            heading: heading,
            hdop: nil,
            satelliteCount: nil
        )
    }

    private func parseGPGGA(_ sentence: String) -> NMEARecord? {
        // $GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
        // Fields: [0]Type, [1]Time, [2]Lat, [3]LatDir, [4]Lon, [5]LonDir,
        //         [6]Quality, [7]NumSats, [8]HDOP, [9]Alt, [10]AltUnit, ...

        let fields = sentence.components(separatedBy: ",")
        guard fields.count >= 11 else { return nil }

        // Parse quality (0 = invalid, 1+ = valid)
        guard let quality = Int(fields[6]), quality > 0 else { return nil }

        // Parse timestamp
        guard let timestamp = parseDateTime(time: fields[1], date: nil) else {
            return nil
        }

        // Parse coordinates
        guard let latitude = parseCoordinate(fields[2], direction: fields[3]),
              let longitude = parseCoordinate(fields[4], direction: fields[5]) else {
            return nil
        }

        // Parse altitude
        let altitude = Double(fields[9])

        // Parse satellite count
        let satelliteCount = Int(fields[7])

        // Parse HDOP (horizontal dilution of precision)
        let hdop = Double(fields[8])

        return NMEARecord(
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            speed: nil,
            heading: nil,
            hdop: hdop,
            satelliteCount: satelliteCount
        )
    }

    private func parseCoordinate(_ value: String, direction: String) -> Double? {
        guard !value.isEmpty, !direction.isEmpty else { return nil }

        // Format: DDMM.MMMM (latitude) or DDDMM.MMMM (longitude)
        let isLatitude = direction == "N" || direction == "S"
        let degreeDigits = isLatitude ? 2 : 3

        guard value.count > degreeDigits else { return nil }

        // Split degrees and minutes
        let degreeString = String(value.prefix(degreeDigits))
        let minuteString = String(value.dropFirst(degreeDigits))

        guard let degrees = Double(degreeString),
              let minutes = Double(minuteString) else {
            return nil
        }

        // Convert to decimal degrees
        var coordinate = degrees + (minutes / 60.0)

        // Apply direction
        if direction == "S" || direction == "W" {
            coordinate = -coordinate
        }

        return coordinate
    }

    private func parseDateTime(time: String, date: String?) -> Date? {
        guard let baseDate = baseDate else { return nil }

        // Parse time: HHMMSS or HHMMSS.sss
        guard time.count >= 6 else { return nil }

        let hourString = String(time.prefix(2))
        let minuteString = String(time.dropFirst(2).prefix(2))
        let secondString = String(time.dropFirst(4).prefix(2))

        guard let hour = Int(hourString),
              let minute = Int(minuteString),
              let second = Int(secondString) else {
            return nil
        }

        // If date is provided, parse it: DDMMYY
        var components = Calendar.current.dateComponents([.year, .month, .day], from: baseDate)

        if let date = date, date.count >= 6 {
            let dayString = String(date.prefix(2))
            let monthString = String(date.dropFirst(2).prefix(2))
            let yearString = String(date.dropFirst(4).prefix(2))

            if let day = Int(dayString),
               let month = Int(monthString),
               let year = Int(yearString) {
                components.year = 2000 + year
                components.month = month
                components.day = day
            }
        }

        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = TimeZone(identifier: "UTC")

        return Calendar.current.date(from: components)
    }

    private func createGPSPoint(from record: NMEARecord) -> GPSPoint? {
        return GPSPoint(
            timestamp: record.timestamp,
            latitude: record.latitude,
            longitude: record.longitude,
            altitude: record.altitude,
            speed: record.speed,
            heading: record.heading,
            horizontalAccuracy: record.hdop.map { $0 * 10 },
            satelliteCount: record.satelliteCount
        )
    }
}

// MARK: - Supporting Types

/// Temporary storage for NMEA record data
private struct NMEARecord {
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let speed: Double?
    let heading: Double?
    let hdop: Double?
    let satelliteCount: Int?
}

// MARK: - Parser Errors

enum GPSParserError: Error {
    case invalidFormat
    case invalidChecksum
    case invalidCoordinate
    case invalidTimestamp
}

extension GPSParserError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid NMEA format"
        case .invalidChecksum:
            return "Invalid NMEA checksum"
        case .invalidCoordinate:
            return "Invalid GPS coordinate"
        case .invalidTimestamp:
            return "Invalid timestamp"
        }
    }
}
