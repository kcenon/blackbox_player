/// @file AccelerationParser.swift
/// @brief G-sensor (accelerometer) binary data parser
/// @author BlackboxPlayer Development Team
/// @details
/// Reads G-sensor data stored in dashcam files and converts it to AccelerationData objects.
/// Supports both binary formats (Float32, Int16) and text format (CSV).

//
//  AccelerationParser.swift
//  BlackboxPlayer
//
//  G-sensor (accelerometer) binary data parser
//
//  [Purpose of this file]
//  Reads G-sensor data stored in dashcam files and converts it to AccelerationData objects.
//  Supports both binary formats (Float32, Int16) and text format (CSV).
//
//  [What is G-sensor data?]
//  Data measuring vehicle acceleration along 3 axes (X, Y, Z):
//  - X-axis: Left/right acceleration (left turn, right turn)
//  - Y-axis: Forward/backward acceleration (acceleration, braking)
//  - Z-axis: Up/down acceleration (speed bumps, jumps)
//
//  [Data Flow]
//  1. Read G-sensor binary data from dashcam file
//  2. Parse with AccelerationParser → AccelerationData array
//  3. Detect and analyze impacts in GSensorService
//  4. Visualize as graph in UI
//
//  Binary file → AccelerationParser → [AccelerationData] → GSensorService → 📊 graph
//

import Foundation

// MARK: - AccelerationParser Class

/// @class AccelerationParser
/// @brief G-sensor binary data parser
/// @details
/// Parses acceleration data stored in dashcam files.
/// Supports various data formats (Float32, Int16, CSV).
///
/// ### Key Features:
/// 1. Binary acceleration data parsing (Float32, Int16)
/// 2. CSV text data parsing
/// 3. Automatic format detection
/// 4. Timestamp calculation
///
/// ### Usage Examples:
/// ```swift
/// // Parse Float32 binary data
/// let parser = AccelerationParser(sampleRate: 10.0, format: .float32)
/// let accelData = parser.parseAccelerationData(binaryData, baseDate: videoStartDate)
///
/// // Parse CSV text data
/// let csvData = parser.parseCSVData(csvData, baseDate: videoStartDate)
///
/// // Auto-detect format
/// if let format = AccelerationParser.detectFormat(unknownData) {
///     let parser = AccelerationParser(format: format)
///     // ...
/// }
/// ```
class AccelerationParser {
    // MARK: - Properties

    /// @var sampleRate
    /// @brief Sampling frequency (Hz, samples per second)
    /// @details
    /// Indicates how many measurements the G-sensor takes per second.
    ///
    /// ### Common Values:
    /// - 10 Hz: Dashcam standard (10 measurements per second)
    /// - 50 Hz: Premium dashcam
    /// - 100 Hz: Professional racing logger
    ///
    /// ### Example:
    /// ```
    /// sampleRate = 10 Hz
    /// → 1 second = 10 samples
    /// → sample interval = 1/10 = 0.1s = 100ms
    /// ```
    private let sampleRate: Double

    /// @var format
    /// @brief Data format (Float32 or Int16)
    /// @details
    /// Different dashcam manufacturers use different formats:
    /// - Float32: High precision, larger memory (4 bytes × 3 axes = 12 bytes)
    /// - Int16: Memory savings, sufficient precision (2 bytes × 3 axes = 6 bytes, 50% reduction)
    private let format: AccelDataFormat

    // MARK: - Initialization

    /// @brief Initialize parser
    /// @param sampleRate Sampling frequency (default: 10 Hz)
    /// @param format Data format (default: Float32)
    /// @details
    /// Initializes AccelerationParser.
    ///
    /// ### Examples:
    /// ```swift
    /// // Default settings (10 Hz, Float32)
    /// let parser1 = AccelerationParser()
    ///
    /// // Custom settings
    /// let parser2 = AccelerationParser(sampleRate: 50.0, format: .int16)
    /// ```
    init(sampleRate: Double = 10.0, format: AccelDataFormat = .float32) {
        self.sampleRate = sampleRate
        self.format = format
    }

    // MARK: - Public Methods

    /// @brief Parse binary acceleration data
    /// @param data Raw binary data
    /// @param baseDate Base time (video start time)
    /// @return AccelerationData array
    /// @details
    /// Converts raw binary data read from dashcam file to AccelerationData array.
    ///
    /// ### Data Structure:
    /// ```
    /// Float32 format (12 bytes per sample):
    /// [X: 4bytes][Y: 4bytes][Z: 4bytes][X][Y][Z][X][Y][Z]...
    ///
    /// Int16 format (6 bytes per sample):
    /// [X: 2bytes][Y: 2bytes][Z: 2bytes][X][Y][Z]...
    /// ```
    ///
    /// ### Timestamp Calculation:
    /// ```
    /// sampleRate = 10 Hz (0.1s interval)
    /// baseDate = 2024-10-12 15:30:00
    ///
    /// Sample 0: 15:30:00.000 (baseDate + 0.0s)
    /// Sample 1: 15:30:00.100 (baseDate + 0.1s)
    /// Sample 2: 15:30:00.200 (baseDate + 0.2s)
    /// ...
    /// ```
    func parseAccelerationData(_ data: Data, baseDate: Date) -> [AccelerationData] {
        var accelerationData: [AccelerationData] = []

        // Calculate bytes per sample
        let bytesPerSample = format.bytesPerSample * 3  // X, Y, Z - 3 axes
        // Float32: 4 × 3 = 12 bytes
        // Int16: 2 × 3 = 6 bytes

        let sampleCount = data.count / bytesPerSample

        guard sampleCount > 0 else { return [] }

        // Access binary data via unsafe pointer (performance optimization)
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            for i in 0..<sampleCount {
                let offset = i * bytesPerSample

                guard offset + bytesPerSample <= data.count else { break }

                // Parse X, Y, Z values
                let x: Double
                let y: Double
                let z: Double

                switch format {
                case .float32:
                    // Parse Float32 (read 4 bytes at a time)
                    // [X: 4byte][Y: 4byte][Z: 4byte]
                    let xPtr = ptr.baseAddress!.advanced(by: offset).assumingMemoryBound(to: Float.self)
                    let yPtr = ptr.baseAddress!.advanced(by: offset + 4).assumingMemoryBound(to: Float.self)
                    let zPtr = ptr.baseAddress!.advanced(by: offset + 8).assumingMemoryBound(to: Float.self)
                    x = Double(xPtr.pointee)
                    y = Double(yPtr.pointee)
                    z = Double(zPtr.pointee)

                case .int16:
                    // Parse Int16 (read 2 bytes at a time)
                    // [X: 2byte][Y: 2byte][Z: 2byte]
                    let xPtr = ptr.baseAddress!.advanced(by: offset).assumingMemoryBound(to: Int16.self)
                    let yPtr = ptr.baseAddress!.advanced(by: offset + 2).assumingMemoryBound(to: Int16.self)
                    let zPtr = ptr.baseAddress!.advanced(by: offset + 4).assumingMemoryBound(to: Int16.self)

                    // Int16 → G-force conversion
                    // ±2G range, 16-bit (-32768 ~ +32767)
                    // Scale factor: 32768 / 2G = 16384
                    //
                    // Examples:
                    // 16384 → 16384 / 16384 = 1.0G
                    // 32767 → 32767 / 16384 = 2.0G (maximum)
                    // -16384 → -16384 / 16384 = -1.0G
                    x = Double(xPtr.pointee) / 16384.0
                    y = Double(yPtr.pointee) / 16384.0
                    z = Double(zPtr.pointee) / 16384.0
                }

                // Calculate timestamp
                let timeOffset = Double(i) / sampleRate  // sample index / sampling frequency
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

    /// @brief Parse CSV text data
    /// @param data CSV data
    /// @param baseDate Base time
    /// @return AccelerationData array
    /// @details
    /// Parses acceleration data in CSV format.
    /// Useful for debugging or test data.
    ///
    /// ### Supported Formats:
    /// ```
    /// Format 1 (with timestamp):
    /// timestamp,x,y,z
    /// 0.0,-0.1,0.05,1.0
    /// 0.1,-0.2,0.1,0.98
    /// 0.2,-0.15,0.08,1.02
    ///
    /// Format 2 (without timestamp):
    /// x,y,z
    /// -0.1,0.05,1.0
    /// -0.2,0.1,0.98
    /// -0.15,0.08,1.02
    /// ```
    func parseCSVData(_ data: Data, baseDate: Date) -> [AccelerationData] {
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }

        var accelerationData: [AccelerationData] = []
        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Skip header row
            if trimmed.hasPrefix("timestamp") || trimmed.hasPrefix("time") {
                continue
            }

            // Parse CSV: timestamp,x,y,z or x,y,z
            let fields = trimmed.components(separatedBy: ",")

            let timestamp: Date
            let startIndex: Int

            if fields.count >= 4 {
                // Format 1: timestamp,x,y,z
                if let timeValue = Double(fields[0]) {
                    timestamp = baseDate.addingTimeInterval(timeValue)
                } else {
                    // Fall back to index-based if timestamp parsing fails
                    timestamp = baseDate.addingTimeInterval(Double(index) / sampleRate)
                }
                startIndex = 1
            } else if fields.count >= 3 {
                // Format 2: x,y,z (no timestamp)
                timestamp = baseDate.addingTimeInterval(Double(index) / sampleRate)
                startIndex = 0
            } else {
                continue  // Invalid format
            }

            guard let x = Double(fields[startIndex]),
                  let y = Double(fields[startIndex + 1]),
                  let z = Double(fields[startIndex + 2]) else {
                continue  // Number parsing failed
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

    /// @brief Auto-detect format from binary data
    /// @param data Raw data
    /// @return Detected format (or nil)
    /// @details
    /// Analyzes data patterns to guess whether it's Float32 or Int16.
    /// Not perfect but accurate in most cases.
    ///
    /// ### Detection Logic:
    /// ```
    /// 1. Interpret first 12 bytes as Float32
    /// 2. Are X, Y, Z values in reasonable G-force range (-20 ~ +20G)?
    /// 3. If yes, Float32; otherwise Int16
    /// ```
    ///
    /// ### Limitations:
    /// - Int16 values might coincidentally look like Float32
    /// - Corrupted or abnormal data may cause misdetection
    ///
    /// ### Usage Example:
    /// ```swift
    /// let unknownData = readFromFile("accel.bin")
    ///
    /// if let format = AccelerationParser.detectFormat(unknownData) {
    ///     let parser = AccelerationParser(format: format)
    ///     let data = parser.parseAccelerationData(unknownData, baseDate: Date())
    /// } else {
    ///     print("Format detection failed")
    /// }
    /// ```
    static func detectFormat(_ data: Data) -> AccelDataFormat? {
        // Need at least 12 bytes (Float32 × 3 axes)
        guard data.count >= 12 else { return nil }

        // Check if values are reasonable when interpreted as Float32
        let isFloat = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Bool in
            let x = ptr.baseAddress!.assumingMemoryBound(to: Float.self).pointee
            let y = ptr.baseAddress!.advanced(by: 4).assumingMemoryBound(to: Float.self).pointee
            let z = ptr.baseAddress!.advanced(by: 8).assumingMemoryBound(to: Float.self).pointee

            // Check reasonable G-force range (-20 ~ +20G)
            // Normal driving: -2 ~ +2G
            // Impact: -10 ~ +10G
            // Extreme: -20 ~ +20G
            return abs(x) < 20 && abs(y) < 20 && abs(z) < 20
        }

        return isFloat ? .float32 : .int16
    }
}

// MARK: - Supporting Types

/// @enum AccelDataFormat
/// @brief Acceleration data format
/// @details
/// Different dashcam manufacturers use different binary formats.
///
/// ### Float32 vs Int16 Comparison:
///
/// #### Float32 (4 bytes):
/// ```
/// Advantages:
/// ✅ High precision (7 decimal places)
/// ✅ Easy processing (no scaling needed)
/// ✅ Wide range (±3.4 × 10³⁸)
///
/// Disadvantages:
/// ❌ 2x memory usage
///
/// Use case: Premium dashcams, precision measurements
/// ```
///
/// #### Int16 (2 bytes):
/// ```
/// Advantages:
/// ✅ Memory savings (50%)
/// ✅ Sufficient precision (0.00012G in ±2G range)
///
/// Disadvantages:
/// ❌ Scale conversion needed (int → float)
/// ❌ Limited range (±2G or ±16G)
///
/// Use case: Standard dashcams, memory-constrained
/// ```
///
/// ### Memory Comparison (1-min recording, 10 Hz sampling):
/// ```
/// Float32: 12 bytes × 600 samples = 7.2KB
/// Int16:    6 bytes × 600 samples = 3.6KB (50% savings)
/// ```
enum AccelDataFormat {
    /// @brief 32-bit floating-point (4 bytes per axis)
    /// @details
    /// ### Memory Layout:
    /// ```
    /// [X: Float32][Y: Float32][Z: Float32]
    ///    4 bytes     4 bytes     4 bytes  = 12 bytes total
    /// ```
    ///
    /// ### Value Range:
    /// -3.4 × 10³⁸ ~ +3.4 × 10³⁸ (actually -20G ~ +20G used)
    ///
    /// ### Precision:
    /// About 7 digits (can represent 0.00001G units)
    case float32

    /// @brief 16-bit signed integer (2 bytes per axis)
    /// @details
    /// ### Memory Layout:
    /// ```
    /// [X: Int16][Y: Int16][Z: Int16]
    ///   2 bytes   2 bytes   2 bytes  = 6 bytes total
    /// ```
    ///
    /// ### Value Range:
    /// -32768 ~ +32767
    ///
    /// ### G-force Conversion (assuming ±2G range):
    /// ```
    /// scale = 32768 / 2G = 16384 (per G)
    ///
    /// intValue → G-force:
    /// g = intValue / 16384.0
    ///
    /// Examples:
    /// 16384 → 1.0G
    /// 32767 → 2.0G (maximum)
    /// 0 → 0.0G
    /// -16384 → -1.0G
    /// ```
    ///
    /// ### Precision:
    /// 0.00012G (2G / 16384)
    case int16

    /// @var bytesPerSample
    /// @brief Byte size per axis
    /// @return Float32: 4 bytes, Int16: 2 bytes
    var bytesPerSample: Int {
        switch self {
        case .float32:
            return 4  // Float = 4 bytes
        case .int16:
            return 2  // Int16 = 2 bytes
        }
    }
}

// MARK: - Parser Errors

/// @enum AccelerationParserError
/// @brief Parser error type
/// @details
/// Defines errors that can occur during acceleration data parsing.
enum AccelerationParserError: Error {
    /// @brief Invalid data format
    /// @details Expected format doesn't match actual data.
    case invalidFormat

    /// @brief Insufficient data
    /// @details Data is smaller than one sample size (6 or 12 bytes).
    case insufficientData

    /// @brief Invalid value
    /// @details G-force value is in physically impossible range (100G, etc.).
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

// ═══════════════════════════════════════════════════════════════════════════
// Integrated Guide: AccelerationParser Usage Flow
// ═══════════════════════════════════════════════════════════════════════════
//
// 1️⃣ Format Detection (optional)
// ────────────────────────────────────────────────
// let binaryData = readFromBlackboxFile()
//
// if let format = AccelerationParser.detectFormat(binaryData) {
//     print("Detected format: \(format)")
// }
//
// 2️⃣ Create Parser
// ────────────────────────────────────────────────
// let parser = AccelerationParser(
//     sampleRate: 10.0,      // 10 Hz
//     format: .float32       // Float32 format
// )
//
// 3️⃣ Parse Binary Data
// ────────────────────────────────────────────────
// let videoStartDate = Date()  // Video start time
// let accelData = parser.parseAccelerationData(binaryData, baseDate: videoStartDate)
//
// print("Parsed sample count: \(accelData.count)")
// // Output: Parsed sample count: 600 (1 min × 10Hz)
//
// 4️⃣ Or Parse CSV
// ────────────────────────────────────────────────
// let csvData = loadCSV("accel.csv")
// let accelData = parser.parseCSVData(csvData, baseDate: videoStartDate)
//
// 5️⃣ Use Data
// ────────────────────────────────────────────────
// for data in accelData {
//     print("\(data.timestamp): X=\(data.x), Y=\(data.y), Z=\(data.z)")
//     if data.isImpact {
//         print("⚠️ Impact detected!")
//     }
// }
//
// ═══════════════════════════════════════════════════════════════════════════
