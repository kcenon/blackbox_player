//
//  AccelerationParser.swift
//  BlackboxPlayer
//
//  Parser for G-sensor (accelerometer) data
//

import Foundation

/// Parser for binary G-sensor acceleration data
class AccelerationParser {
    // MARK: - Properties

    /// Sample rate in Hz (samples per second)
    private let sampleRate: Double

    /// Data format
    private let format: AccelDataFormat

    // MARK: - Initialization

    /// Initialize parser with configuration
    /// - Parameters:
    ///   - sampleRate: Sample rate in Hz (default: 10 Hz)
    ///   - format: Data format (default: float32)
    init(sampleRate: Double = 10.0, format: AccelDataFormat = .float32) {
        self.sampleRate = sampleRate
        self.format = format
    }

    // MARK: - Public Methods

    /// Parse binary acceleration data
    /// - Parameters:
    ///   - data: Raw binary data
    ///   - baseDate: Base timestamp (from video file)
    /// - Returns: Array of AccelerationData objects
    func parseAccelerationData(_ data: Data, baseDate: Date) -> [AccelerationData] {
        var accelerationData: [AccelerationData] = []

        let bytesPerSample = format.bytesPerSample * 3  // X, Y, Z axes
        let sampleCount = data.count / bytesPerSample

        guard sampleCount > 0 else { return [] }

        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            for i in 0..<sampleCount {
                let offset = i * bytesPerSample

                guard offset + bytesPerSample <= data.count else { break }

                // Parse X, Y, Z values based on format
                let x: Double
                let y: Double
                let z: Double

                switch format {
                case .float32:
                    let xPtr = ptr.baseAddress!.advanced(by: offset).assumingMemoryBound(to: Float.self)
                    let yPtr = ptr.baseAddress!.advanced(by: offset + 4).assumingMemoryBound(to: Float.self)
                    let zPtr = ptr.baseAddress!.advanced(by: offset + 8).assumingMemoryBound(to: Float.self)
                    x = Double(xPtr.pointee)
                    y = Double(yPtr.pointee)
                    z = Double(zPtr.pointee)

                case .int16:
                    let xPtr = ptr.baseAddress!.advanced(by: offset).assumingMemoryBound(to: Int16.self)
                    let yPtr = ptr.baseAddress!.advanced(by: offset + 2).assumingMemoryBound(to: Int16.self)
                    let zPtr = ptr.baseAddress!.advanced(by: offset + 4).assumingMemoryBound(to: Int16.self)
                    // Convert from int16 to G-force (assuming ±2G range, 16-bit)
                    x = Double(xPtr.pointee) / 16384.0
                    y = Double(yPtr.pointee) / 16384.0
                    z = Double(zPtr.pointee) / 16384.0
                }

                // Calculate timestamp
                let timeOffset = Double(i) / sampleRate
                let timestamp = baseDate.addingTimeInterval(timeOffset)

                let accelData = AccelerationData(
                    timestamp: timestamp,
                    x: x,
                    y: y,
                    z: z
                )

                accelerationData.append(accelData)
            }
        }

        return accelerationData
    }

    /// Parse text-based acceleration data (CSV format)
    /// - Parameters:
    ///   - data: CSV data
    ///   - baseDate: Base timestamp
    /// - Returns: Array of AccelerationData objects
    func parseCSVData(_ data: Data, baseDate: Date) -> [AccelerationData] {
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }

        var accelerationData: [AccelerationData] = []
        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Skip header line if present
            if trimmed.hasPrefix("timestamp") || trimmed.hasPrefix("time") {
                continue
            }

            // Parse CSV: timestamp,x,y,z or just x,y,z
            let fields = trimmed.components(separatedBy: ",")

            let timestamp: Date
            let startIndex: Int

            if fields.count >= 4 {
                // Format: timestamp,x,y,z
                if let timeValue = Double(fields[0]) {
                    timestamp = baseDate.addingTimeInterval(timeValue)
                } else {
                    timestamp = baseDate.addingTimeInterval(Double(index) / sampleRate)
                }
                startIndex = 1
            } else if fields.count >= 3 {
                // Format: x,y,z (no timestamp)
                timestamp = baseDate.addingTimeInterval(Double(index) / sampleRate)
                startIndex = 0
            } else {
                continue
            }

            guard let x = Double(fields[startIndex]),
                  let y = Double(fields[startIndex + 1]),
                  let z = Double(fields[startIndex + 2]) else {
                continue
            }

            let accelData = AccelerationData(
                timestamp: timestamp,
                x: x,
                y: y,
                z: z
            )

            accelerationData.append(accelData)
        }

        return accelerationData
    }

    /// Detect data format from binary data
    /// - Parameter data: Raw data
    /// - Returns: Detected format or nil
    static func detectFormat(_ data: Data) -> AccelDataFormat? {
        // Try to detect based on data patterns
        // This is a heuristic approach

        guard data.count >= 12 else { return nil }

        // Check if values look like floats (typical range: -10.0 to 10.0 G)
        let isFloat = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Bool in
            let x = ptr.baseAddress!.assumingMemoryBound(to: Float.self).pointee
            let y = ptr.baseAddress!.advanced(by: 4).assumingMemoryBound(to: Float.self).pointee
            let z = ptr.baseAddress!.advanced(by: 8).assumingMemoryBound(to: Float.self).pointee

            // Reasonable G-force range
            return abs(x) < 20 && abs(y) < 20 && abs(z) < 20
        }

        return isFloat ? AccelDataFormat.float32 : AccelDataFormat.int16
    }
}

// MARK: - Supporting Types

/// Acceleration data format
enum AccelDataFormat {
    /// 32-bit floating point (4 bytes per axis)
    case float32

    /// 16-bit signed integer (2 bytes per axis)
    case int16

    var bytesPerSample: Int {
        switch self {
        case .float32:
            return 4
        case .int16:
            return 2
        }
    }
}

// MARK: - Parser Errors

enum AccelerationParserError: Error {
    case invalidFormat
    case insufficientData
    case invalidValue
}

extension AccelerationParserError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid acceleration data format"
        case .insufficientData:
            return "Insufficient data for parsing"
        case .invalidValue:
            return "Invalid acceleration value"
        }
    }
}
